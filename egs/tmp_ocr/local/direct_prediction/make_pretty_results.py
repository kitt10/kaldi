#!/usr/bin/env python3

from argparse import ArgumentParser
from glob import glob
from os.path import isfile, isdir, join as join_path
from PIL import Image, ImageDraw, ImageFont

def parse_args():
    parser = ArgumentParser(description='Prepare pretty presentable results.')
    parser.add_argument('--results_dir', type=str, default='predict/results',
                        help='path to the results dir')
    parser.add_argument('--raw_data_dir', type=str, default='predict/data',
                        help='path to the raw data')
    parser.add_argument('--work_dir_loc', type=str, default='predict/work_loc',
                        help='path to the localization working dir')

    return parser.parse_args()

if __name__ == '__main__':

    args = parse_args()

    pages = dict()
    with open(join_path(args.results_dir, 'predictions.txt'), 'r', encoding='utf-8') as f:
        for line in f:
            splt = line.rstrip().split()
            line_id = splt[0]
            prediction = ' '.join(splt[1:])

            page_id = line_id[:-4]
            if page_id in list(pages.keys()):
                pages[page_id].append((line_id, prediction))
            else:
                pages[page_id] = [(line_id, prediction)]

    areas = dict()
    for page_id in pages.keys():
        area_file_path = join_path(args.work_dir_loc, page_id+'_lines', page_id+'_id2area.txt')
        with open(area_file_path, 'r', encoding='utf-8') as f:
            for line in f:
                line_id, a = line.rstrip().split()
                areas[line_id] = [int(c) for c in a.split(',')]

        orig_im = Image.open(join_path(args.raw_data_dir, page_id+'.jpg'))
        w, h = orig_im.size
        res_im = Image.new('RGB', (2*w, h), color='white')
        res_im.paste(orig_im, (0, 0))
        pen = ImageDraw.Draw(res_im)

        with open(join_path(args.results_dir, page_id+'.out'), 'w', encoding='utf-8') as f:
            for line_id, prediction in pages[page_id]:
                f.write(prediction+'\n')
                font_h = int((areas[line_id][3]-areas[line_id][1])*.8)
                font = ImageFont.truetype('arial.ttf', font_h)
                pen.text((areas[line_id][0]+w, areas[line_id][1]), prediction, fill='black', font=font)

        res_im.save(join_path(args.results_dir, page_id+'_result.jpg'))
