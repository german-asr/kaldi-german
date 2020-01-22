DATA_PATH=$1
LEX_PATH=$2
SEQUITUR_PATH=$3
LM_PATH=$4


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
    cp $LM_PATH data/local/lm/lm_6.arpa
fi
