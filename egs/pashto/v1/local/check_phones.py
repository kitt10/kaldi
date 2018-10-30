#!/usr/bin/env python3
# Copyright      2018  Martin Bulin
# Apache 2.0
# Reads valid phones. Removes lines from the stream containing invalid phones.

from argparse import ArgumentParser
from codecs import open as cod_open
from sys import stdin, stdout
from io import TextIOWrapper
from os.path import join as join_path


def parse_args():
    parser = ArgumentParser(description='Checks for valid phones in text.')
    parser.add_argument('--local_dir', type=str, default='data/local')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    phones_file = join_path(args.local_dir, 'cleaned', 'phones.txt')
    with cod_open(phones_file, 'r', encoding='utf-8') as f:
        phones_ok = set(line.strip() for line in f)

    stream_in = TextIOWrapper(stdin.buffer, encoding='utf-8')
    stream_out = TextIOWrapper(stdout.buffer, encoding='utf-8')

    for line in stream_in:
        text = line.strip()
        if False not in [ph in phones_ok for ph in text]:
            stream_out.write(text+'\n')
