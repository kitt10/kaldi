#!/usr/bin/env python3

# Copyright     2017  Hossein Hadian
#               2018  Martin Bulin
# Apache 2.0


"""
    This script finds a set of allowed lengths for a given OCR/HWR data dir.
    The allowed lengths are spaced by a factor (like 10%) and are written
    in an output file named "allowed_lengths.txt" in the output data dir. This
    file is later used by make_features.py to pad each image sufficiently so that
    they all have an allowed length. This is intended for end2end chain training.

    data/local/allowed_lengths.txt
"""

from argparse import ArgumentParser
from os.path import join as join_path


def parse_args():
    parser = ArgumentParser(description='Finds a set of allowed lengths from all widths.')
    parser.add_argument('--local_dir', type=str, help='path to source data dir')
    parser.add_argument('--frame_subsampling_factor', type=int, default=4,
                        help='chain frame subsampling factor; see steps/nnet3/chain/train.py')
    parser.add_argument('--spacing_factor', type=float, default=10,
                        help='spacing (in percentage) between allowed lengths')
    parser.add_argument('--coverage_factor', type=float, default=0.01,
                        help='percentage of durations not covered from each side of duration histogram')

    return parser.parse_args()


def find_range(img2len, coverage_factor):
    """
     Given a list of utterances, find the start and end length to cover.
     If we try to cover all lengths which occur in the training set,
     the number of allowed lengths could become very large.
    """
    lens = sorted(img2len.values())
    sum_lens = sum(lens)

    s = 0
    for l in lens:
        s += l
        if s / sum_lens > coverage_factor:
            start_len = l
            break

    s = 0
    for l in lens[::-1]:
        s += l
        if s / sum_lens > coverage_factor:
            end_len = l
            break

    # 30 is a hard limit to avoid too many allowed lengths --not critical
    return max(30, start_len), end_len


def find_allowed_lengths(start_len, end_len, args):
    """
     Given the start and end duration, find a set of
     allowed durations spaced by args.spacing_factor%. Also write
     out the list of allowed durations and the corresponding
     allowed lengths (in frames) on disk.
    """

    length = start_len
    with open(join_path(args.local_dir, 'allowed_lengths.txt'), 'w') as f:
        while length < end_len:
            if length % args.frame_subsampling_factor != 0:
                length = args.frame_subsampling_factor * \
                          (length // args.frame_subsampling_factor)

            f.write(str(int(length))+'\n')
            length *= args.spacing_factor

if __name__ == '__main__':
    args = parse_args()
    args.spacing_factor = 1.0 + args.spacing_factor / 100.0

    im2len = dict()
    with open(join_path(args.local_dir, 'im_widths.txt'), 'r') as f:
        for line in f:
            im_id, im_width = line.strip().split()
            im2len[im_id] = int(im_width)

    start_len, end_len = find_range(im2len, args.coverage_factor/100.)
    find_allowed_lengths(start_len, end_len, args)
    print('Allowed lenghts found. Borders: [{}, {}]'.format(start_len, end_len))
