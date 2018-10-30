#!/usr/bin/env python3
# Copyright      2018  Martin Bulin
# Apache 2.0
# Extract phones from text.

from sys import stdin, stdout
from io import TextIOWrapper

if __name__ == '__main__':
    stream_in = TextIOWrapper(stdin.buffer, encoding='utf-8')
    stream_out = TextIOWrapper(stdout.buffer, encoding='utf-8')

    phones = set((' ',))
    for word in [line.strip().split() for line in stream_in]:
        for ph in word:
            phones.add(ph)

    for ph in phones:
        stream_out.write(ph+'\n')
