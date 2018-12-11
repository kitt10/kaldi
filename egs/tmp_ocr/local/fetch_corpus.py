#!/usr/bin/env python3

from argparse import ArgumentParser
from glob import glob
from os import makedirs
from os.path import isfile, join as join_path
from shutil import copyfile

def parse_args():
    parser = ArgumentParser(description='Fetch the corpus and rename the files.')
    parser.add_argument('--database_dir', type=str, default='/home/kitt/data/ocr_ustr',
                        help='path to the original directory')
    parser.add_argument('--corpus_dir', type=str, default='corpus',
                        help='path for the corpus')                        
    
    return parser.parse_args()

if __name__ == '__main__':

    args = parse_args()

    orig_image_paths = list()
    for path_and_filename in glob(join_path(args.database_dir, 'img', '*.jpg')):
        orig_image_paths.append(path_and_filename)

    nn = dict()
    n_pages = 0
    for orig_image_path in sorted(orig_image_paths):
        file_id = orig_image_path.split('/')[-1].rstrip('.jpg')
        orig_ref_path = join_path(args.database_dir, 'ref', file_id+'_out.txt')

        if isfile(orig_ref_path):
            n_pages += 1
            nn[file_id] = 'page_'+str(n_pages).zfill(3)
            work_dir = join_path(args.corpus_dir, nn[file_id], 'work')
            makedirs(work_dir)
            copyfile(orig_image_path, join_path(work_dir, nn[file_id]+'.jpg'))
            copyfile(orig_ref_path, join_path(work_dir, nn[file_id]+'.txt'))
        else:
            print('W: Transcription for '+file_id+' not found. Skipping.')

    print('-- Fetched '+str(n_pages)+' pages.')
    with open(join_path(args.corpus_dir, 'filenames.map'), 'w') as f:
        for file_id, new_name in sorted(nn.items(), key=lambda x:x[1]):
            f.write(new_name+' '+file_id+'\n')
