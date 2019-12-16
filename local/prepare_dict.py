import os
import tempfile
import subprocess

import click
import pyphony
import audiomate

SILENCE_PHONES = [
    'SIL',
    'SPN'
]

OPTIONAL_SILENCE = [
    'SIL'
]


@click.command()
@click.argument('lexicon-path', type=click.Path(exists=True))
@click.argument('out-path', type=click.Path())
@click.option('--corpus-path', type=click.Path(exists=True))
@click.option('--sequitur-path', type=click.Path(exists=True))
def run(lexicon_path, out_path, corpus_path, sequitur_path):
    print('Prepare Dict')

    os.makedirs(out_path, exist_ok=True)

    print('Load Dict')
    abc = pyphony.Alphabet.marytts_de()
    lex = pyphony.Lexicon.load(
        lexicon_path,
        word_sep=' ',
        token_sep='',
        alphabet=abc
    )

    if corpus_path is not None:
        print('Find OOV')
        oov = find_oov(corpus_path, lex)

        path = os.path.join(out_path, 'added_oovs.txt')
        write_lines(sorted(oov),  path)

        if sequitur_path is not None:
            print('Translate {} oovs using sequitur'.format(len(oov)))
            add_translated_oov(lex, oov, sequitur_path)

        else:
            print('No sequitur model!')

    print('Save nonsilence_phones.txt')
    nonsilence_phones = lex.symbols()
    path = os.path.join(out_path, 'nonsilence_phones.txt')
    write_lines(nonsilence_phones, path)

    print('Save silence_phones.txt')
    path = os.path.join(out_path, 'silence_phones.txt')
    write_lines(SILENCE_PHONES, path)

    print('Save optional_silence.txt')
    path = os.path.join(out_path, 'optional_silence.txt')
    write_lines(OPTIONAL_SILENCE, path)

    print('Save extra_questions.txt')
    extra_questions = [
        ' '.join(SILENCE_PHONES),
        ' '.join(nonsilence_phones),
    ]
    path = os.path.join(out_path, 'extra_questions.txt')
    write_lines(extra_questions, path)

    print('Save lexicon.txt {}'.format(len(lex.entries)))
    lex.add('!SIL', ['SIL'])
    lex.add('<SPOKEN_NOISE>', ['SPN'])
    lex.add('<UNK>',  ['SPN'])

    path = os.path.join(out_path, 'lexicon.txt')
    lex.save(path, word_sep=' ', token_sep=' ')


def write_lines(phones, path):
    lines = list(phones)
    lines.append('') # new line at the end, otherwise kaldi is not happy

    with open(path, 'w') as f:
        f.write('\n'.join(lines))


def find_oov(corpus_path, lexicon):
    print(' - Load corpus')
    corpus = audiomate.Corpus.load(corpus_path, reader='kaldi')

    print(' - Get words from corpus')
    all_words = set(corpus.all_tokens())
    print(' - Get words from lexicon')
    lex_words = set(lexicon.entries.keys())

    print(' - Find oov (corpus-words - lexicon-words)')
    oov = all_words - lex_words

    return oov


def add_translated_oov(lex, oov, sequitur_path):
    with tempfile.NamedTemporaryFile() as f:
        f.write('\n'.join(list(oov)).encode('utf-8'))
        f.flush()

        x = subprocess.check_output([
            'g2p.py',
            '--model', sequitur_path,
            '--apply', f.name,
        ])

        for line in x.decode('utf-8').split('\n'):
            line = line.strip()

            if 'stack' not in line and line not in ['']:
                word, token_str = line.split('\t')
                tokens = token_str.split(' ')
                lex.add(word, tokens)


if __name__ == '__main__':
    run()
