#!/bin/bash

mfccdir=mfcc
stage=1
train=true
decode=false

. ./cmd.sh
. ./path.sh
. parse_options.sh


if [ $stage -le 1 ]; then
  utils/prepare_lang.sh \
    data/local/dict_nosp \
    "<UNK>" \
    data/local/lang_tmp_nosp \
    data/lang_nosp
fi

if [ $stage -le 2 ]; then
    lm_path=data/local/lm/lm_6.arpa
    cp -r data/lang_nosp data/lang_nosp_test_ng6

    cat $lm_path | \
        utils/find_arpa_oovs.pl \
        data/lang_nosp/words.txt > data/local/oovs_lm.txt

    cat $lm_path | \
        grep -v '<s> <s>' | \
        grep -v '</s> <s>' | \
        grep -v '</s> </s>' | \
        arpa2fst - | \
        fstprint | \
        utils/remove_oovs.pl data/local/oovs_lm.txt | \
        utils/eps2disambig.pl | \
        utils/s2eps.pl | \
        fstcompile --isymbols=data/lang_nosp_test_ng6/words.txt \
            --osymbols=data/lang_nosp_test_ng6/words.txt  \
            --keep_isymbols=false --keep_osymbols=false | \
            fstrmepsilon |
            fstarcsort --sort_type=ilabel > data/lang_nosp_test_ng6/G.fst
fi

if [ $stage -le 3 ]; then
  for part in train dev test train_cv; do
    utils/utt2spk_to_spk2utt.pl data/$part/utt2spk > data/$part/spk2utt

    steps/make_mfcc.sh --cmd "$train_cmd" --nj 8 data/$part exp/make_mfcc/$part exp/mfcc/$part
    steps/compute_cmvn_stats.sh data/$part exp/make_mfcc/$part exp/mfcc/$part

    utils/fix_data_dir.sh data/$part
  done
fi

if [ $stage -le 4 ]; then
  # Make some small data subsets for early system-build stages.
  # For the monophone stages we select the shortest utterances, which should make it
  # easier to align the data from a flat start.

  utils/subset_data_dir.sh --shortest data/train_cv 2000 data/train_2kshort
  utils/subset_data_dir.sh data/train_cv 5000 data/train_5k
  utils/subset_data_dir.sh data/train 10000 data/train_10k
fi

if [ $stage -le 8 ]; then
    if $train; then
        # train a monophone system
        steps/train_mono.sh --boost-silence 1.25 --nj 8 --cmd "$train_cmd" \
                           data/train_2kshort data/lang_nosp exp/mono

        utils/mkgraph.sh data/lang_nosp_test_ng6 \
                         exp/mono exp/mono/graph_nosp_ng6
    fi

    if $decode; then
        for test in test dev; do
          steps/decode.sh --nj 8 --cmd "$decode_cmd" exp/mono/graph_nosp_ng6 \
                          data/$test exp/mono/decode_nosp_ng6_$test
        done
    fi
fi

if [ $stage -le 9 ]; then
    if $train; then
        steps/align_si.sh --boost-silence 1.25 --nj 8 --cmd "$train_cmd" \
                        data/train_5k data/lang_nosp exp/mono exp/mono_ali_5k

        # train a first delta + delta-delta triphone system on a subset of 5000 utterances
        steps/train_deltas.sh --boost-silence 1.25 --cmd "$train_cmd" \
                            2000 10000 data/train_5k data/lang_nosp exp/mono_ali_5k exp/tri1

        utils/mkgraph.sh data/lang_nosp_test_ng6 \
                     exp/tri1 exp/tri1/graph_nosp_ng6
    fi

    if $decode; then
        for test in test dev; do
          steps/decode.sh --nj 8 --cmd "$decode_cmd" exp/tri1/graph_nosp_ng6 \
                          data/$test exp/tri1/decode_nosp_ng6_$test
        done
    fi
fi

if [ $stage -le 10 ]; then
    if $train; then
        steps/align_si.sh --nj 8 --cmd "$train_cmd" \
                        data/train_10k data/lang_nosp exp/tri1 exp/tri1_ali_10k

        # train an LDA+MLLT system.
        steps/train_lda_mllt.sh --cmd "$train_cmd" \
                              --splice-opts "--left-context=3 --right-context=3" 2500 15000 \
                              data/train_10k data/lang_nosp exp/tri1_ali_10k exp/tri2b

        utils/mkgraph.sh data/lang_nosp_test_ng6 \
                         exp/tri2b exp/tri2b/graph_nosp_ng6
    fi

    if $decode; then
        for test in test dev; do
          steps/decode.sh --nj 8 --cmd "$decode_cmd" exp/tri2b/graph_nosp_ng6 \
                          data/$test exp/tri2b/decode_nosp_ng6_$test
        done
    fi
fi

if [ $stage -le 11 ]; then
    if $train; then
        # Align a 10k utts subset using the tri2b model
        steps/align_si.sh  --nj 8 --cmd "$train_cmd" --use-graphs true \
                         data/train_10k data/lang_nosp exp/tri2b exp/tri2b_ali_10k

        # Train tri3b, which is LDA+MLLT+SAT on 10k utts
        steps/train_sat.sh --cmd "$train_cmd" 2500 15000 \
                         data/train_10k data/lang_nosp exp/tri2b_ali_10k exp/tri3b

        utils/mkgraph.sh data/lang_nosp_test_ng6 \
                         exp/tri3b exp/tri3b/graph_nosp_ng6
    fi

    if $decode; then
        for test in test dev; do
          steps/decode_fmllr.sh --nj 8 --cmd "$decode_cmd" \
                                exp/tri3b/graph_nosp_ng6 data/$test \
                                exp/tri3b/decode_nosp_ng6_$test
        done
    fi
fi

if [ $stage -le 12 ]; then
    if $train; then
        # align the entire train subset using the tri3b model
        steps/align_fmllr.sh --nj 8 --cmd "$train_cmd" \
        data/train data/lang_nosp \
        exp/tri3b exp/tri3b_ali

        # train another LDA+MLLT+SAT system on the entire 100 hour subset
        steps/train_sat.sh  --cmd "$train_cmd" 4200 40000 \
                          data/train data/lang_nosp \
                          exp/tri3b_ali exp/tri4b

        utils/mkgraph.sh data/lang_nosp_test_ng6 \
                         exp/tri4b exp/tri4b/graph_nosp_ng6
    fi

    if $decode; then
        for test in test dev; do
          steps/decode_fmllr.sh --nj 8 --cmd "$decode_cmd" \
                                exp/tri4b/graph_nosp_ng6 data/$test \
                                exp/tri4b/decode_nosp_ng6_$test
        done
    fi
fi

if [ $stage -le 13 ]; then
    if $train; then
        # Now we compute the pronunciation and silence probabilities from training data,
        # and re-create the lang directory.
        steps/get_prons.sh --cmd "$train_cmd" \
                         data/train data/lang_nosp exp/tri4b
        utils/dict_dir_add_pronprobs.sh --max-normalize true \
                                      data/local/dict_nosp \
                                      exp/tri4b/pron_counts_nowb.txt exp/tri4b/sil_counts_nowb.txt \
                                      exp/tri4b/pron_bigram_counts_nowb.txt data/local/dict

        utils/prepare_lang.sh data/local/dict \
                            "<UNK>" data/local/lang_tmp data/lang

        lm_path=data/local/lm/lm_6.arpa
        cp -r data/lang data/lang_test_ng6

        cat $lm_path | \
            utils/find_arpa_oovs.pl \
            data/lang/words.txt > data/local/oovs_lm.txt

        cat $lm_path | \
            grep -v '<s> <s>' | \
            grep -v '</s> <s>' | \
            grep -v '</s> </s>' | \
            arpa2fst - | \
            fstprint | \
            utils/remove_oovs.pl data/local/oovs_lm.txt | \
            utils/eps2disambig.pl | \
            utils/s2eps.pl | \
            fstcompile --isymbols=data/lang_test_ng6/words.txt \
                --osymbols=data/lang_test_ng6/words.txt  \
                --keep_isymbols=false --keep_osymbols=false | \
                fstrmepsilon |
                fstarcsort --sort_type=ilabel > data/lang_test_ng6/G.fst

        utils/mkgraph.sh \
            data/lang_test_ng6 exp/tri4b exp/tri4b/graph_ng6
    fi

    if $decode; then
        for test in test dev; do
          steps/decode_fmllr.sh --nj 8 --cmd "$decode_cmd" \
                                exp/tri4b/graph_ng6 data/$test \
                                exp/tri4b/decode_ng6_$test
        done
    fi
fi

if [ $stage -le 20 ]; then
    # train and test nnet3 tdnn models on the entire data with data-cleaning.
    local/chain/run_tdnn.sh --stage 1 # set "--stage 11" if you have already run local/nnet3/run_tdnn.sh
fi

if [ $stage -le 21 ]; then
    for dir in exp/* exp/chain*/*; do
      # steps/info/gmm_dir_info.pl $dir
        for x in $dir/decode* $dir/decode*; do
            [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh;
        done
    done | sort -n -r -k2 > RESULTS
fi
