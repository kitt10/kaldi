#!/usr/bin/env python3

import xml.etree.ElementTree
from glob import glob
from os import makedirs
from os.path import join as join_path, exists
from codecs import open as cod_open
from scipy.misc import imread, imsave
from sys import stdout

def get_word_list(old_trs_dir):
    word_list = dict()
    duplicates = list()
    for txt_file_path in sorted(glob(join_path(old_trs_dir, '*.txt'))):
        filename = txt_file_path.split('/')[-1]
        try:
            word_nb = int(filename.strip('.txt'))
        except ValueError:
            print('Ignoring '+filename)
            continue

        with cod_open(txt_file_path, 'r', encoding='utf-8') as f:
            line = f.readline()
            word = line[line.find('<s>')+3:line.find('</s>')].lstrip(' ').rstrip(' ')
            if word in word_list.keys():
                duplicates.append(word)
                word_list[word].append(word_nb)
                print('Word:', word, 'is here again, positions:'+str(word_list[word]))
            else:
                word_list[word] = [word_nb]

    return word_list

if __name__ == '__main__':

    old_trs_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/Afghanistan/extractedWords/transcriptions'
    trs_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/Afghanistan/extractedWords/transcriptions_new'
    words_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/Afghanistan/extractedWords/words_new'
    data_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/Afghanistan'

    word_list = get_word_list(old_trs_dir)

    # hack - do only these spks and append to done work
    missing_spks = ['55', '56', '57', '58', '59', '60', '61', '62', '63', '64', '65', '66', '67', '68', '69', '70', '71', '72', '73', \
		    '74', '75', '76', '77', '78', '79', '80', '81', '82', '83', '84', '85', '86', '87', '88', '89', '90', '91', '92', \
		    '93', '94', '95', '96', '97', '98', '99', '5', '6', '7', '8', '9']
    for spk_dir_path in sorted(glob(join_path(data_dir, '*'))):
        dirname = spk_dir_path.split('/')[-1]
        spk_id = dirname.split('_')[0]

        spk_nb = spk_id[2:]
        if spk_nb not in missing_spks:
            continue

        print('Processing speaker', spk_id)
        stdout.flush()

        for xml_file_path in sorted(glob(join_path(spk_dir_path, '*.xml'))):
            filename = xml_file_path.split('/')[-1]
            doc_nb = filename.split('_')[1][:3]         # TODO must be treated for af55
            if int(doc_nb) < 11:
                continue        # separated words starts on page 11

            tree_root = xml.etree.ElementTree.parse(xml_file_path).getroot()
            ns = tree_root.tag.split('}')[0]+'}'     # namespace stamp

            doc = tree_root.find(ns+'DL_DOCUMENT')
            page_src = doc.attrib['src']
            try:
                im_page = imread(join_path(spk_dir_path, page_src), flatten=True)
            except FileNotFoundError:
                try:
                    im_page = imread(join_path(spk_dir_path, page_src.replace('.jpg', '.bmp')), flatten=True)
                except FileNotFoundError:
                    print('File '+page_src+' not found (nor .bmp). Skipping.')
                    continue

            for page in doc.findall(ns+'DL_PAGE'):
                zones = page.findall(ns+'DL_ZONE')
                for zone in zones:
                    try:
                        trs = zone.attrib['contents']
                        r = int(zone.attrib['row'])
                        w = int(zone.attrib['width'])
                        c = int(zone.attrib['col'])
                        h = int(zone.attrib['height'])
                    except KeyError:
                        print('Skipping zone (missing info).')
                        continue

                    if trs in word_list.keys():
                        for word_nb in word_list[trs]:
                            trs_filename = str(word_nb)+'.txt'
                            trs_file_path = join_path(trs_dir, trs_filename)
                            stamp = spk_id+'_'+doc_nb+'-'+str(word_nb)

                            with cod_open(trs_file_path, 'a', encoding='utf-8') as f:
                                f.write('<s> '+trs+' </s> ('+stamp+')\n')

                            word_dir_path = join_path(words_dir, str(word_nb))
                            if not exists(word_dir_path):
                                makedirs(join_path(word_dir_path, 'badWord'))

                            im_filename = stamp+'.bmp'
                            im_file_path = join_path(word_dir_path, im_filename)
                            im_word = 255-im_page[r:r+h, c:c+w]  # crop and invert to white-on-black as originally was
                            imsave(im_file_path, im_word)
                    else:
                        print('Word '+trs+' is not in the word list.')

