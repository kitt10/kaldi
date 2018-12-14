#!/usr/bin/env python3

from argparse import ArgumentParser
from glob import glob
from shutil import rmtree
from os import makedirs
from os.path import isfile, isdir, join as join_path
from PIL import Image

def parse_args():
    parser = ArgumentParser(description='Cut the lines from the raw images.')
    parser.add_argument('--raw_data_dir', type=str, default='predict/data',
                        help='path to the the raw data')
    parser.add_argument('--work_dir', type=str, default='predict/work_loc',
                        help='path to the working directory')
    parser.add_argument('--im_mimetype', type=str, default='.bmp',
                        help='the mimetype of the processed images')

    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    for path_to_im in sorted(glob(join_path(args.raw_data_dir, '*'+args.im_mimetype))):
        im_filename = path_to_im.split('/')[-1]
        im_id = im_filename.rstrip(args.im_mimetype)
        out_dir_path = join_path(args.work_dir, im_id+'_lines')
        if isdir(out_dir_path):
            rmtree(out_dir_path)

        makedirs(out_dir_path)

        im = Image.open(path_to_im)
        f_id2path = open(join_path(out_dir_path, im_id+'_id2path.txt'), 'w')
        f_id2area = open(join_path(out_dir_path, im_id+'_id2area.txt'), 'w')
        with open(join_path(args.work_dir, im_id+'_lines.txt'), 'r') as f:
            for li_m1, line in enumerate(f):
                area = [int(c) for c in line.rstrip().split(',')]
                box_im = im.crop(area)
                box_id = im_id+'_'+str(li_m1+1).zfill(3)
                box_path = join_path(out_dir_path, box_id+args.im_mimetype)
                box_im.save(box_path)
                f_id2path.write(box_id+' '+box_path+'\n')
                f_id2area.write(box_id+' '+line)
        
        f_id2path.close()
        f_id2area.close()
