#!/usr/bin/env python3

# creates data files "text", "utt2spk", and "images.scp" for the train and test subsets in data/train and data/test.

# text - matches the transcriptions with the image id
# utt2spk - matches the image id's with the speaker/writer names
# images.scp - matches the image is's with the actual image file

from argparse import ArgumentParser
from os import listdir
from os.path import join as join_path
from codecs import open as cod_open
from random import randint
from scipy.misc import imread, imresize, imsave
import numpy as np

def parse_args():
    parser = ArgumentParser(description='Creates data/train and data/test.')
    parser.add_argument('--data_path_tr', type=str, help='path to the PASHTO data transcriptions')
    parser.add_argument('--data_path_im', type=str, help='path to the PASHTO data images')
    parser.add_argument('--out_dir', type=str, default='data', 
                    help='where to create the train and test data directories')
    parser.add_argument('--spks', type=str, 
                    help='list of speaker IDs (string with space sep)')
    parser.add_argument('--n_samples', type=int, default=100000, 
                    help='number of samples per speaker to consider')
    parser.add_argument('--feat_dim', type=int, default=128,
                    help='size to scale the height of all images (i.e. the dimension of the resulting features)')
    parser.add_argument('--invert', type=boolean_string, default='False', 
                    help='invert colors for all images (wanna have black text on white bg?)')
    parser.add_argument('--pad', type=boolean_string, default='False', 
                    help='pad the left and right of the images with 10 white pixels.')
    parser.add_argument('--add_noise', type=boolean_string, default='False', 
                    help='subtract random_normal(2,1) from all pixels?')
    return parser.parse_args()

def boolean_string(s):
    if s not in ('False', 'True'):
        raise ValueError('Not a valid boolean string, use [True|False]')
    
    return s == 'True'

def scale_image(im):
    sy, sx = im.shape
    
    # Some images might be rotated
    if sy > sx:
        im = np.rot90(im, k=-1)
        sy, sx = im.shape

    scale_ratio = float(args.feat_dim)/sy
    return imresize(im, (int(args.feat_dim), int(scale_ratio*sx)))

if __name__ == '__main__':
    args = parse_args()
    im_mimetype = '.bmp'
    
    text_train = list()
    utt2spk_train = list()
    images_train = list()
    text_test = list()
    utt2spk_test = list()
    images_test = list()

    spks_count = dict([(spk, 0) for spk in args.spks.split()])
    for w_id in listdir(args.data_path_im):
        with cod_open(join_path(args.data_path_tr, w_id+'.txt'), 'r', encoding='utf-8') as f:
            for line in f.readlines():
                im_orig_id = line[line.find('(')+1:line.find(')')]
                trs = line[4:line.find(' </s>')]

                im_dir = im_orig_id[im_orig_id.find('-')+1:]
                im_orig_path = join_path(args.data_path_im, im_dir, im_orig_id+im_mimetype)
                im_orig_filename = im_orig_path.split('/')[-1]
                spk_id_tmp = im_orig_filename.split('_')[1]
                spk_id = spk_id_tmp[:2]+spk_id_tmp[2:].zfill(2)
                if spk_id not in spks_count.keys() or spks_count[spk_id] == args.n_samples:
                    continue
                
                spks_count[spk_id] += 1
                im_id = spk_id+'_'+str(spks_count[spk_id]).zfill(5)+'_'+w_id.zfill(5)
                im_path = join_path(args.out_dir, 'local', 'images', spk_id, im_id+im_mimetype)

                im = imread(im_orig_path, flatten=True)
                im = scale_image(im)

                if args.add_noise:
                    im = im - np.random.normal(2, 1, im.shape)

                if args.invert:
                    im = 255-im

                if args.pad:
                    padding = np.ones((args.feat_dim, 10)) * 255
                    im = np.hstack((padding, im, padding))

                imsave(im_path, im)
                
                # register the sample (randomly split train 95% and test 5%)
                coin = randint(0, 20)
                if coin >= 1:
                    text_train.append(im_id+' '+trs+'\n')                                   # train/text: <im_id> <transcription>
                    utt2spk_train.append(im_id+' '+spk_id+'\n')                             # train/utt2spk: <im_id> <spk_id>
                    images_train.append(im_id+' '+im_path+'\n')                             # train/images.scp: <im_id> <path_to_image>
                else:
                    text_test.append(im_id+' '+trs+'\n')                                    # test/text: <im_id> <transcription>
                    utt2spk_test.append(im_id+' '+spk_id+'\n')                              # test/utt2spk: <im_id> <spk_id>
                    images_test.append(im_id+' '+im_path+'\n')                              # test/images.scp: <im_id> <path_to_image>

    with cod_open(args.out_dir+'/train/text', 'w+', encoding='utf-8') as f:
        for line in sorted(text_train):
            f.write(line)

    with open(args.out_dir+'/train/utt2spk', 'w+') as f:
        for line in sorted(utt2spk_train):
            f.write(line)

    with open(args.out_dir+'/train/images.scp', 'w+') as f:
        for line in sorted(images_train):
            f.write(line)

    with cod_open(args.out_dir+'/test/text', 'w+', encoding='utf-8') as f:
        for line in sorted(text_test):
            f.write(line)

    with open(args.out_dir+'/test/utt2spk', 'w+') as f:
        for line in sorted(utt2spk_test):
            f.write(line)

    with open(args.out_dir+'/test/images.scp', 'w+') as f:
        for line in sorted(images_test):
            f.write(line)
