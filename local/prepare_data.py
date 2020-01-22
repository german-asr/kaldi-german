import os

import click
import audiomate
from audiomate.corpus import io


@click.command()
@click.argument('corpus-path', type=click.Path(exists=True))
@click.argument('out-path', type=click.Path())
def run(corpus_path, out_path):
    print('Prepare Data')

    os.makedirs(out_path, exist_ok=True)

    print(' - Load Source Corpus')
    corpus = audiomate.Corpus.load(corpus_path)

    kaldi_writer = io.KaldiWriter(
        use_absolute_times=True
    )

    print(' - Save Train')
    train = audiomate.Corpus.from_corpus(corpus.subviews['train'])
    train_path = os.path.join(out_path, 'train')
    os.makedirs(train_path, exist_ok=True)
    kaldi_writer.save(train, train_path)

    print(' - Save Test')
    test = audiomate.Corpus.from_corpus(corpus.subviews['test'])
    test_path = os.path.join(out_path, 'test')
    os.makedirs(test_path, exist_ok=True)
    kaldi_writer.save(test, test_path)

    print(' - Save Dev')
    dev = audiomate.Corpus.from_corpus(corpus.subviews['dev'])
    dev_path = os.path.join(out_path, 'dev')
    os.makedirs(dev_path, exist_ok=True)
    kaldi_writer.save(dev, dev_path)

    print(' - Save Train Common Voice')
    # Used for small initial training sets
    # If we use the full one only very small utterances (from mailabs/swc will be selected)
    # Common-Voice provides a much better setting
    train_cv = audiomate.Corpus.from_corpus(corpus.subviews['train_common_voice'])
    train_cv_path = os.path.join(out_path, 'train_cv')
    os.makedirs(train_cv_path, exist_ok=True)
    kaldi_writer.save(train_cv, train_cv_path)


if __name__ == '__main__':
    run()
