# German Speech Recognition using Kaldi
Scripts to train Kaldi model for German speech recognition.

## Data / LM / Lexicon
First, we have to get the data, a language model and the lexicon.
 * To get the data follow the steps in [https://github.com/ynop/megs](https://github.com/ynop/megs).
 * Download the LM from [https://github.com/ynop/german-asr-lm](https://github.com/ynop/german-asr-lm).
 * Download the lexicon from [https://github.com/ynop/german-asr-lexicon](https://github.com/ynop/german-asr-lexicon).

## Preparation
Before training, preparation of data, lexicon and lm has to be done by executing the script ``prepare.sh``.
In order to do that some python dependencies have to be installed with ``pip install -r requirements``.

```
./prepare.sh \
    [german-asr-data]/data/full_waverized \
    [lexicon] \
    [sequitur-model] \
    [lm]
```

## Training
After preparation, the actual training is done.
At this step kaldi is used.
To run it the easiest was is to used the docker image from [https://hub.docker.com/r/kaldiasr/kaldi](https://hub.docker.com/r/kaldiasr/kaldi).
All commands are in ``run.sh``.
This script is derived from the LibriSpeech recipe at ``egs/librispeech``.

## Results

### Word error rate (%)

| Model | Training-Data | dev_cv | test_cv | dev_tuda | test_tuda |
| ----- | ------------- | ------ | ------- | -------- | --------- |
| tdnn-chain | train | 15.26 | 18.53 | 11.94 | 12.66 |
