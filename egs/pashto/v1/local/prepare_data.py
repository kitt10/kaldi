#!/usr/bin/env python3

# creates data files "text", "utt2spk", and "images.scp" for the train and test subsets in data/train and data/test.

# text - matches the transcriptions with the image id
# utt2spk - matches the image id's with the speaker/writer names
# images.scp - matches the image is's with the actual image file

from argparse import ArgumentParser
from os import makedirs, listdir
from os.path import isfile, join as join_path, exists as dir_exists
from codecs import open as cod_open
from random import randint
from scipy.misc import imread, imresize, imsave
from time import ctime
import numpy as np

def parse_args():
    parser = ArgumentParser(description='Creates data/train and data/test.')
    parser.add_argument('--data_path', type=str, help='path to the PASHTO database (WordImages dir)')
    parser.add_argument('--out_dir', type=str, default='data', 
                    help='where to create the train and test data directories')
    parser.add_argument('--us_spks', type=int, help='number of US speakers (0-12)')
    parser.add_argument('--af_spks', type=int, help='number of Afgh. speakers (0-370)')
    parser.add_argument('--max_samples', type=int, default=100000, 
                    help='number of samples per speaker to consider (max value)')
    parser.add_argument('--feat_dim', type=int, default=40,
                    help='size to scale the height of all images (i.e. the dimension of the resulting features)')
    parser.add_argument('--invert', type=boolean_string, default='true', 
                    help='invert colors for all images (wanna have black text on white bg?)')
    parser.add_argument('--pad_value', type=int, default=16,
                    help='how many white pixels shall we pad the left and right of the images?')
    parser.add_argument('--add_noise', type=boolean_string, default='false', 
                    help='subtract random_normal(2,1) from all pixels?')
    parser.add_argument('--log_dir', type=str, default='local/log', help='dir to leave a log in')                    
    return parser.parse_args()

def boolean_string(s):
    if s not in ('false', 'true'):
        raise ValueError('Not a valid bash boolean string, use [true|false]')

    return s == 'true'

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

    # List the speakers and make the dirs
    spks_count = dict()
    images_target_path = join_path(args.out_dir, 'local', 'images')
    for us_i in range(1, args.us_spks+1):
        spk_id = 'us'+str(us_i).zfill(3)
        makedirs(join_path(images_target_path, spk_id))
        spks_count[spk_id] = 0

    for af_i in range(1, args.af_spks+1):
        spk_id = 'af'+str(af_i).zfill(3)
        makedirs(join_path(images_target_path, spk_id))
        spks_count[spk_id] = 0
    
    # Collect samples
    for set_name in ('US_Final', 'Afghanistan'):
        data_source_path = join_path(args.data_path, set_name, 'extractedWords')
        for w_id in listdir(join_path(data_source_path, 'words')):
            with cod_open(join_path(data_source_path, 'transcriptions', w_id+'.txt'), \
                            'r', encoding='utf-8') as f:
                for line in f.readlines():
                    im_orig_id = line[line.find('(')+1:line.find(')')]
                    trs = line[4:line.find(' </s>')]

                    im_dir = im_orig_id[im_orig_id.find('-')+1:]
                    im_orig_path = join_path(data_source_path, 'words', im_dir, im_orig_id+im_mimetype)
                    im_orig_filename = im_orig_path.split('/')[-1]
                    if not isfile(im_orig_path):
                        continue

                    if set_name == 'US_Final':
                        spk_id_tmp = im_orig_filename.split('_')[1]
                    elif set_name == 'Afghanistan':
                        spk_id_tmp = im_orig_filename.split('_')[0]
                    else:
                        print('ERR: Unknown dataset name:', set_name)
                        exit(1)
                    
                    spk_id = spk_id_tmp[:2]+spk_id_tmp[2:].zfill(3)
                    if spk_id not in spks_count.keys() or spks_count[spk_id] == args.max_samples:
                        continue

                    spks_count[spk_id] += 1
                    im_id = spk_id+'_'+str(spks_count[spk_id]).zfill(5)+'_'+w_id.zfill(5)
                    im_path = join_path(images_target_path, spk_id, im_id+im_mimetype)

                    im = imread(im_orig_path, flatten=True)
                    im = scale_image(im)

                    if args.add_noise:
                        im = im - np.random.normal(2, 1, im.shape)

                    if args.invert:
                        im = 255-im

                    if args.pad_value > 0:
                        padding = np.ones((args.feat_dim, args.pad_value)) * 255
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

    with cod_open(join_path(args.out_dir, 'train', 'text'), 'w+', encoding='utf-8') as f:
        for line in sorted(text_train):
            f.write(line)

    with open(join_path(args.out_dir, 'train', 'utt2spk'), 'w+') as f:
        for line in sorted(utt2spk_train):
            f.write(line)

    with open(join_path(args.out_dir, 'train', 'images.scp'), 'w+') as f:
        for line in sorted(images_train):
            f.write(line)

    with cod_open(join_path(args.out_dir, 'test', 'text'), 'w+', encoding='utf-8') as f:
        for line in sorted(text_test):
            f.write(line)

    with open(join_path(args.out_dir, 'test', 'utt2spk'), 'w+') as f:
        for line in sorted(utt2spk_test):
            f.write(line)

    with open(join_path(args.out_dir, 'test', 'images.scp'), 'w+') as f:
        for line in sorted(images_test):
            f.write(line)

    # Leave a log
    if not dir_exists(args.log_dir):
        makedirs(args.log_dir)

    with open(join_path(args.log_dir, 'prepare_data.log'), 'w+') as f:
        f.write(ctime()+' :: Pashto DATA PREPARATION\n')
        f.write('\nARGS:\n')
        for arg, val in sorted(vars(args).items(), key=lambda x: x[0]):
            f.write(str(arg)+': '+str(val)+'\n')

        f.write('\nCollected '+str(sum(spks_count.values()))+' samples.\n')
        for spk_id, c in sorted(spks_count.items(), key=lambda x: (-x[1], x[0])):
            f.write(spk_id+': '+str(c)+'\n')
