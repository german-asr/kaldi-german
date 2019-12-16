DATA_PATH="~/repos/german-asr-data/data/full_waverized"
LEX_PATH="~/repos/german-asr-lexicon/data/mary_wiki_nogs/lexicon.txt"
SEQUITUR_PATH="~/repos/german-asr-lexicon/data/mary_wiki_nogs/sequitur/models/model_8"
LM_PATH="~/repos/german-asr-lm/data/models/kenlm/full/lm_6.arpa data/local/lm/lm_6.arpa"


# Import data
if [ ! -d data/train ]; then
    python local/prepare_data.py \
        $DATA_PATH \
        data
fi

# Import/Prepare lexicon
if [ ! -d data/local/dict_nosp ]; then
    python local/prepare_dict.py \
        $LEX_PATH \
        data/local/dict_nosp \
        --corpus-path data/train \
        --sequitur-path $SEQUITUR_PATH
fi

# Import/Prepare LM
if [ ! -d data/local/lm ]; then
    mkdir -p data/local/lm
    cp $LM_PATH
fi
