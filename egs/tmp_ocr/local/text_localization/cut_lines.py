#!/usr/bin/env python3

from argparse import ArgumentParser
from glob import glob
from shutil import rmtree
from os import unlink, makedirs
from os.path import isfile, isdir, join as join_path
from PIL import Image
from matplotlib import pyplot as plt
from pyautogui import typewrite, hotkey
from clipboard import copy as copy_to_cb
from time import sleep

def parse_args():
    parser = ArgumentParser(description='Cut the lines from the raw images.')
    parser.add_argument('--corpus_dir', type=str, default='corpus',
                        help='path to the corpus')
    parser.add_argument('--interactive', type=lambda x: (str(x).lower() == 'true'),
                        default=False,
                        help='Annotation mode on/off?')
    parser.add_argument('--direct_prediction', type=lambda x: (str(x).lower() == 'true'),
                        default=False,
                        help='Direct prediction on/off?')

    return parser.parse_args()

def rlinput(prompt, prefill=''):
    print(prompt)
    copy_to_cb(prefill)
    sleep(0.5)
    hotkey('ctrl', 'shift', 'v')
    return input()

if __name__ == '__main__':
    args = parse_args()

    skip_pages = []

    if args.direct_prediction:
        raw_data_dir = 'predict/data'
        work_dir = 'predict/work_loc'

        for path_to_im in sorted(glob(join_path(raw_data_dir, '*.jpg'))):
            im_filename = path_to_im.split('/')[-1]
            im_id = im_filename.rstrip('.jpg')
            out_dir_path = join_path(work_dir, im_id+'_lines')
            if isdir(out_dir_path):
                rmtree(out_dir_path)

            makedirs(out_dir_path)

            im = Image.open(path_to_im)
            f_id2path = open(join_path(out_dir_path, im_id+'_id2path.txt'), 'w')
            f_id2area = open(join_path(out_dir_path, im_id+'_id2area.txt'), 'w')
            with open(join_path(work_dir, im_id+'_lines.txt'), 'r') as f:
                for li_m1, line in enumerate(f):
                    area = [int(c) for c in line.rstrip().split(',')]
                    box_im = im.crop(area)
                    box_id = im_id+'_'+str(li_m1+1).zfill(3)
                    box_path = join_path(out_dir_path, box_id+'.jpg')
                    box_im.save(box_path)
                    f_id2path.write(box_id+' '+box_path+'\n')
                    f_id2area.write(box_id+' '+line)
            
            f_id2path.close()
            f_id2area.close()
    else:
        for path_to_dir in sorted(glob(join_path(args.corpus_dir, 'page_*'))):
            page_id = path_to_dir.split('/')[-1]
            page_nb = int(page_id.split('_')[1])
            if page_nb in skip_pages:
                continue
            
            print('\n\n-- Processing '+page_id)
            # Remove old boxes if any
            for old_im in glob(join_path(path_to_dir, '*.jpg')):
                unlink(old_im)

            if args.interactive:
                trs = list()
                f_ref = open(join_path(path_to_dir, page_id+'_ref.txt'), 'w', encoding='utf-8')
                with open(join_path(path_to_dir, 'work', page_id+'.txt'), 'r', encoding='utf-8') as f:
                    for line in f:
                        if line.strip():
                            print(line)
                            trs.append(line.rstrip())

            im = Image.open(join_path(path_to_dir, 'work', page_id+'.jpg'))
            with open(join_path(path_to_dir, 'work', page_id+'_lines.txt'), 'r') as f:
                li = 1
                gi = -1
                for line in f:
                    area = [int(c) for c in line.rstrip().split(',')]
                    box_im = im.crop(area)
                    box_id = page_id+'_'+str(li).zfill(3)

                    if args.interactive:
                        plt.imshow(box_im)
                        plt.show(block=False)
                        
                        ti = li+gi
                        try:
                            prefill = trs[ti]
                        except IndexError:
                            prefill = ''

                        ans = rlinput('Line '+str(li)+' [s/p/n/<own>/ ]', prefill=prefill)
                        if ans == 's':
                            continue

                        while ans == 'p' or ans == 'n':
                            if ans == 'p':
                                ti -= 1
                                gi -= 1
                            elif ans == 'n':
                                ti += 1
                                gi += 1
                            try:
                                ans = rlinput('Line '+str(li)+' [p/n/ ]', prefill=trs[ti])
                            except IndexError:
                                gi -= 1
                                print('Nope. That was the last one.')
                                ans = rlinput('Line '+str(li)+' [s/p/n/ ]')
                                if ans == 's':
                                    continue

                        f_ref.write(box_id+' '+ans+'\n')

                    li += 1
                    box_path = join_path(path_to_dir, box_id+'.jpg')
                    box_im.save(box_path)

            if args.interactive:
                f_ref.close()
