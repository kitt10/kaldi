#!/usr/bin/env python3

# Copyright      2017  Chun Chieh Chang
#                2018  Adjusted (Martin Bulin)

""" This script converts images to Kaldi-format feature matrices. The input to
    this script is the path to a data directory, e.g. "data/train". This script
    reads the images listed in images.scp and writes them to standard output
    (by default) as Kaldi-formatted matrices (in text form).
"""

from argparse import ArgumentParser
from os.path import join as join_path
from scipy.misc import imread
import numpy as np
import sys

from signal import signal, SIGPIPE, SIG_DFL
signal(SIGPIPE,SIG_DFL)

parser = ArgumentParser(description="""Converts images (in 'dir'/images.scp) to features and
                                    writes them to standard output in text format.""")
parser.add_argument('--im_dir', type=str, help='data directory (should contain images.scp)')
parser.add_argument('--out_ark', type=str, default='-', help='where to write the output feature file.')
args = parser.parse_args()


def write_kaldi_matrix(file_handle, matrix, key, right_to_left=False):
    file_handle.write(key + " [ ")
    num_rows = len(matrix)
    if num_rows == 0:
        raise Exception("Matrix is empty")
    num_cols = len(matrix[0])

    # read bottom->up (from right to left), e.g. Arabic text
    if right_to_left:
        rows = range(len(matrix)-1, -1, -1)
        stop_at = 0
    else:
        rows = range(len(matrix))
        stop_at = num_rows-1

    for row_index in rows:
        if num_cols != len(matrix[row_index]):
            raise Exception("All the rows of a matrix are expected to "
                            "have the same length")
        file_handle.write(" ".join(map(lambda x: str(x), matrix[row_index])))
        if row_index != stop_at:
            file_handle.write("\n")
    file_handle.write(" ]\n")

if __name__ == '__main__':
    if args.out_ark == '-':
        out_fh = sys.stdout    # pipe
    else:
        out_fh = open(args.out_ark, 'wb')

    with open(join_path(args.im_dir, 'images.scp')) as f:
        for line in f:
            line = line.strip()
            image_id, image_path = line.split()

            im_data = imread(image_path, flatten=True)
            data = np.transpose(im_data, (1, 0))
            data = np.divide(data, 255.0)
            write_kaldi_matrix(out_fh, data, image_id, right_to_left=True)
