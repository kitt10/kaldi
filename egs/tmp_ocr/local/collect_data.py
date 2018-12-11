#!/usr/bin/env python3

# Author     2018  Martin Bulin

from argparse import ArgumentParser
from glob import glob
from os import makedirs
from os.path import isfile, exists, join as join_path
from codecs import open as cod_open
from scipy.misc import imread
from sys import stdout
from time import ctime
import numpy as np

def parse_args():
    parser = ArgumentParser(description='Creates data/train and data/test.')
    parser.add_argument('--corpus_dir', type=str,
                        help='path to the corpus')
    parser.add_argument('--train_data_dir', type=str, default='data/train',
                        help='directory for training data')
    parser.add_argument('--test_data_dir', type=str, default='data/test',
                        help='directory for testing data')
    parser.add_argument('--local_dir', type=str, default='data/local',
                        help='the data/local dir')
    parser.add_argument('--images_dir', type=str, default='data/local/images',
                        help='the place where to save scaled images')
    parser.add_argument('--data_log_dir', type=str, default='data/log',
                        help='the place to leave a log at')
    parser.add_argument('--max_samples', type=int, default=100000,
                        help='max number of samples per speaker to consider')
    parser.add_argument('--first_spknb_test', type=int, default=20,
                        help='spks with geq nb will be in the test set')
    parser.add_argument('--feat_dim', type=int, default=40,
                        help='height of the scaled images (feature dim)')
    parser.add_argument('--pad_pixels', type=int, default=10,
                        help='how many white pixels shall we pad the images?')
    parser.add_argument('--save_images', type=lambda x: (str(x).lower() == 'true'),
                        default=True,
                        help='save the scaled images into the eg\'s data dir?')
    parser.add_argument('--frame_subsampling_factor', type=int, default=4,
                        help='see steps/nnet3/chain/train.py')
    parser.add_argument('--spacing_factor', type=float, default=10,
                        help='spacing (in percentage) between allowed lengths')
    parser.add_argument('--coverage_factor', type=float, default=0.01,
                        help='percentage of widths not covered from each side')

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
    spacing_factor = 1.0 + args.spacing_factor / 100.0

    allowed_lengths_ = list()
    length = start_len
    with open(join_path(args.local_dir, 'allowed_lengths.txt'), 'w') as f:
        while length < end_len:
            if length % args.frame_subsampling_factor != 0:
                length = args.frame_subsampling_factor * \
                          (length // args.frame_subsampling_factor)

            f.write(str(int(length))+'\n')
            allowed_lengths_.append(int(length))
            length *= spacing_factor

    return allowed_lengths_

if __name__ == '__main__':
    args = parse_args()
    im_mimetype = '.jpg'

    spks_count = dict()
    text_train = list()
    utt2spk_train = list()
    images_train = list()
    images_orig_train = list()
    text_test = list()
    utt2spk_test = list()
    images_test = list()
    images_orig_test = list()
    im_widths = dict()

    for path_to_page_dir in sorted(glob(join_path(args.corpus_dir, 'page_*'))):
        spk_id = path_to_page_dir.split('/')[-1]
        spk_nb = int(spk_id.split('_')[1])
        print('-- Collecting data from '+spk_id)
        spks_count[spk_id] = 0
        if args.save_images:
            makedirs(join_path(args.images_dir, spk_id))

        with cod_open(join_path(path_to_page_dir, spk_id+'_ref.txt'), 'r', encoding='utf-8') as f:
            for line in f:
                splt = line.rstrip().split()
                im_id = splt[0]
                trs = ' '.join(splt[1:])
                im_filename = im_id+im_mimetype
                im_orig_path = join_path(path_to_page_dir, im_filename)
                
                if not isfile(im_orig_path):
                    print('W: File '+im_orig_path+' does not exist.')
                    continue

                if spks_count[spk_id] == args.max_samples:
                    print('W: Page '+spk_id+' exceeded the max number of samples.')
                    continue

                # TODO: preprocess trs?

                spks_count[spk_id] += 1
                im_path = join_path(args.images_dir, spk_id, im_filename)

                # we need to register im width (after scaling and padding)
                im = imread(im_orig_path, flatten=True)
                im_widths[im_id] = args.feat_dim*max(im.shape)//min(im.shape)+2*args.pad_pixels

                # register the sample
                if spk_nb < args.first_spknb_test:
                    text_train.append(im_id+' '+trs+'\n')       # train/text: <im_id> <transcription>
                    utt2spk_train.append(im_id+' '+spk_id+'\n') # train/utt2spk: <im_id> <spk_id>
                    images_train.append(im_id+' '+im_path+'\n') # train/images.scp: <im_id> <path_to_image>
                    images_orig_train.append(im_id+' '+im_orig_path+'\n') # <im_id> <path_to_orig_image>
                else:
                    text_test.append(im_id+' '+trs+'\n')        # test/text: <im_id> <transcription>
                    utt2spk_test.append(im_id+' '+spk_id+'\n')  # test/utt2spk: <im_id> <spk_id>
                    images_test.append(im_id+' '+im_path+'\n')  # test/images.scp: <im_id> <path_to_image>
                    images_orig_test.append(im_id+' '+im_orig_path+'\n') # <im_id> <path_to_orig_image>

    with cod_open(join_path(args.train_data_dir, 'text'), 'w+', encoding='utf-8') as f:
        for line in sorted(text_train):
            f.write(line)

    with open(join_path(args.train_data_dir, 'utt2spk'), 'w+') as f:
        for line in sorted(utt2spk_train):
            f.write(line)

    with open(join_path(args.train_data_dir, 'images.scp'), 'w+') as f:
        for line in sorted(images_train):
            f.write(line)

    with open(join_path(args.train_data_dir, 'images_orig.scp'), 'w+') as f:
        for line in sorted(images_orig_train):
            f.write(line)

    with cod_open(join_path(args.test_data_dir, 'text'), 'w+', encoding='utf-8') as f:
        for line in sorted(text_test):
            f.write(line)

    with open(join_path(args.test_data_dir, 'utt2spk'), 'w+') as f:
        for line in sorted(utt2spk_test):
            f.write(line)

    with open(join_path(args.test_data_dir, 'images.scp'), 'w+') as f:
        for line in sorted(images_test):
            f.write(line)

    with open(join_path(args.test_data_dir, 'images_orig.scp'), 'w+') as f:
        for line in sorted(images_orig_test):
            f.write(line)

    # Find allowed lengths
    start_len, end_len = find_range(im_widths, args.coverage_factor/100.)
    allowed_lengths = find_allowed_lengths(start_len, end_len, args)

    # Leave a log
    log_path = join_path(args.data_log_dir, 'collect_data.log')
    with open(log_path, 'w+') as f:
        f.write(ctime()+' :: COLLECTING USTR DATA LOG\n')
        f.write('\nARGS:\n')
        for arg, val in sorted(vars(args).items(), key=lambda x: x[0]):
            f.write(str(arg)+': '+str(val)+'\n')

        f.write('\n\nAllowed lenghts start/end: '+str(start_len)+'/'+str(end_len))
        f.write('\nNumber of allowed lengths: '+str(len(np.unique(allowed_lengths))))

        f.write('\n\nCollected '+str(sum(spks_count.values()))+' samples.\n')
        for spk_id, c in sorted(spks_count.items(), key=lambda x: (-x[1], x[0])):
            f.write(spk_id+': '+str(c)+'\n')
