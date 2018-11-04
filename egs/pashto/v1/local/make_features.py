#!/usr/bin/env python3

# Copyright      2017  Chun Chieh Chang
#                2018  Martin Bulin

""" This script converts images to Kaldi-format feature matrices. The input to
    this script is the path to a data directory, e.g. "data/train". This script
    reads the images listed in images.scp and writes them to standard output
    (by default) as Kaldi-formatted matrices (in text form).
"""

from argparse import ArgumentParser
from os.path import join as join_path, isfile
from scipy.misc import imread
from sys import stdout
import numpy as np

from signal import signal, SIGPIPE, SIG_DFL
signal(SIGPIPE,SIG_DFL)

parser = ArgumentParser(description='Converts images into features of the standard format.')
parser.add_argument('--im_dir', type=str, help='data directory (should contain images.scp)')
parser.add_argument('--fliplr', type=lambda x: (str(x).lower()=='true'), default=False,
                    help="flip the image left-right for right to left languages")
parser.add_argument('--allowed_len_file', type=str, default='',
                    help='if supplied, images will be padded to one of the allowed lengths')
parser.add_argument('--out_ark', type=str, default='',
                    help='where to write the output feature file; otherwise goes to pipe')
args = parser.parse_args()


def write_kaldi_matrix(file_handle, matrix, key, right_to_left=False):
    file_handle.write(key + " [ ")
    num_rows = len(matrix)
    if num_rows == 0:
        raise Exception('!! Matrix is empty')

    num_cols = len(matrix[0])
    # read bottom->up (from right to left) for r->l languages
    if right_to_left:
        rows = range(len(matrix)-1, -1, -1)
        stop_at = 0
    else:
        rows = range(len(matrix))
        stop_at = num_rows-1

    for row_index in rows:
        if num_cols != len(matrix[row_index]):
            raise Exception('!! All the rows of a matrix are expected to have the same length')
        file_handle.write(" ".join(map(lambda x: str(x), matrix[row_index])))
        if row_index != stop_at:
            file_handle.write("\n")

    file_handle.write(" ]\n")


def horizontal_pad(im, allowed_lengths=None):
    if allowed_lengths is None:
        left_padding = right_padding = 0
    else:
        im_len = im.shape[1]    # width
        allowed_len = 0
        for l in allowed_lengths:
            if l > im_len:
                allowed_len = l
                break

        if allowed_len == 0:
            return None     # image is too long

        padding = allowed_len - im_len
        left_padding = int(padding // 2)
        right_padding = padding - left_padding

    im_height = im.shape[0]
    left_padded_im = np.concatenate((255*np.ones((im_height, left_padding),
                                                 dtype=int), im), axis=1)
    return np.concatenate((left_padded_im, 255*np.ones((im_height, right_padding),
                                                       dtype=int)), axis=1)

if __name__ == '__main__':
    if args.out_ark:
        out_fh = open(args.out_ark, 'wb')
    else:
        out_fh = stdout  # -> pipe

    allowed_lengths = None
    if isfile(args.allowed_len_file):
        allowed_lengths = []
        with open(args.allowed_len_file, 'r') as f:
            for line in f:
                allowed_lengths.append(int(line.strip()))

    num_fail = 0
    num_ok = 0
    with open(join_path(args.im_dir, 'images.scp')) as f:
        for line in f:
            image_id, image_path = line.strip().split()
            im_data = imread(image_path, flatten=True)

            data = horizontal_pad(im_data, allowed_lengths)
            if data is None:
                num_fail += 1
                continue

            num_ok += 1
            data = np.transpose(data, (1, 0))
            data = np.divide(data, 255.)
            write_kaldi_matrix(out_fh, matrix=data, key=image_id,
                               right_to_left=args.fliplr)
