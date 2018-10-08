#!/usr/bin/env python3

# creates data files "text", "utt2spk", and "images.scp" for the train and test subsets in data/train and data/test.

# text - matches the transcriptions with the image id
# utt2spk - matches the image id's with the speaker/writer names
# images.scp - matches the image is's with the actual image file

from argparse import ArgumentParser
from os import listdir, path
from glob import glob
from shutil import copyfile
from codecs import open as cod_open
from random import randint

def parse_args():
    parser = ArgumentParser(description='Creates data/train and data/test.')
    parser.add_argument('--data_path_tr', type=str, help='path to the PASHTO data transcriptions')
    parser.add_argument('--data_path_im', type=str, help='path to the PASHTO data images')
    parser.add_argument('--out_dir', type=str, default='data', help='where to create the train and test data directories')
    parser.add_argument('--spks', type=str, help='list of speakers (string with comma sep)')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()
    im_mimetype = '.bmp'

    f_text_train = cod_open(args.out_dir+'/train/text', 'w+', encoding='utf-8')
    f_utt2spk_train = open(args.out_dir+'/train/utt2spk', 'w+')
    f_images_train = open(args.out_dir+'/train/images.scp', 'w+')
    f_text_test = cod_open(args.out_dir+'/test/text', 'w+', encoding='utf-8')
    f_utt2spk_test = open(args.out_dir+'/test/utt2spk', 'w+')
    f_images_test = open(args.out_dir+'/test/images.scp', 'w+')

    spks_count = dict([(spk, 0) for spk in args.spks.split()])
    for w_id in listdir(args.data_path_im):
        trs = dict()
        with cod_open(args.data_path_tr+'/'+w_id+'.txt', 'r', encoding='utf-8') as f:
            for line in f.readlines():
                trs[line[line.find('(')+1:line.find(')')]] = line[4:line.find(' </s>')]
                            
        for im_path_orig in glob(path.join(args.data_path_im+w_id, '*'+im_mimetype)):
            im_filename = im_path_orig.split('/')[-1]
            spk_id = im_filename.split('_')[1]
            spks_count[spk_id] += 1
            im_id = spk_id+'_'+str(spks_count[spk_id]).zfill(5)+'_'+w_id.zfill(5)
            im_path = args.out_dir+'/local/images/'+spk_id+'/'+im_id+im_mimetype
            
            # copy the image
            copyfile(im_path_orig, im_path)

            # register the sample (randomly split train 95% and test 5%)
            coin = randint(0, 20)
            if coin >= 1:
                f_text_train.write(im_id+' '+trs[im_filename.rstrip(im_mimetype)]+'\n') # train/text: <im_id> <transcription>
                f_utt2spk_train.write(im_id+' '+spk_id+'\n')                            # train/utt2spk: <im_id> <spk_id>
                f_images_train.write(im_id+' '+im_path+'\n')                            # train/images.scp: <im_id> <path_to_image>
            else:
                f_text_test.write(im_id+' '+trs[im_filename.rstrip(im_mimetype)]+'\n')  # test/text: <im_id> <transcription>
                f_utt2spk_test.write(im_id+' '+spk_id+'\n')                             # test/utt2spk: <im_id> <spk_id>
                f_images_test.write(im_id+' '+im_path+'\n')                             # test/images.scp: <im_id> <path_to_image>

    f_text_train.close()
    f_utt2spk_train.close()
    f_images_train.close()
    f_text_test.close()
    f_utt2spk_test.close()
    f_images_test.close()