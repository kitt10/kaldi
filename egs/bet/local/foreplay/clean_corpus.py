#!/usr/bin/env python3
# Copyright      2018  Martin Bulin
# Apache 2.0
# Reads valid phones. Removes lines from the stream containing invalid phones.

from argparse import ArgumentParser
from codecs import open as cod_open
from sys import stdout
from io import TextIOWrapper
from os.path import join as join_path


def parse_args():
    parser = ArgumentParser(description='Checks for valid phones in corpus.')
    parser.add_argument('--local_dir', type=str, default='data/local')
    parser.add_argument('--bpe_dir', type=str, default='data/local/bpe')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    with cod_open(join_path(args.bpe_dir, 'phones.txt'), 'r', encoding='utf-8') as f:
        phones_ok = set(line.strip() for line in f)

    out_file = cod_open(join_path(args.bpe_dir, 'corpus_clean.txt'), 'w', encoding='utf-8')
    with cod_open(join_path(args.local_dir, 'corpus.txt'), 'r', encoding='utf-8') as f:
        for line in f.readlines():
            text = line.strip()
            if False not in [ph in phones_ok for ph in text]:
                out_file.write(text+'\n')

    out_file.close()
