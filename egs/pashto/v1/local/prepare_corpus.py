#!/usr/bin/env python3

# Creates corpus:

# corpus.txt

from argparse import ArgumentParser
from codecs import open as cod_open


def parse_args():
    parser = ArgumentParser(description='Creates data/local/corpus.txt')
    parser.add_argument('--trs_files', nargs='+', type=str, help='path to all text files with transcriptions')
    parser.add_argument('--local_dir', type=str, default='data/local', help='where to put the corpus.txt')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    all_sentences = list()
    for trs_filename in args.trs_files:
        with cod_open(trs_filename, 'r', encoding='utf-8') as f:
            for line in f.readlines():
                all_sentences.append(line[line.find(' '):-1])

    f_corpus = cod_open(args.local_dir+'/corpus.txt', 'w+', encoding='utf-8')
    for sentence in sorted(all_sentences):
        f_corpus.write(sentence+'\n')

    f_corpus.close()
