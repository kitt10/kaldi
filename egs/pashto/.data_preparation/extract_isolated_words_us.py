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
        word_nb = int(filename.strip('.txt'))
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

    old_trs_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/US_Final/extractedWords/transcriptions'
    trs_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/US_Final/extractedWords/transcriptions_new'
    words_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/US_Final/extractedWords/words_new'
    data_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/US_Final'

    word_list = get_word_list(old_trs_dir)

    for spk_dir_path in sorted(glob(join_path(data_dir, '*'))):
        dirname = spk_dir_path.split('/')[-1]
        spk_id = dirname.split('_')[0]

        print('Processing speaker', spk_id)
        stdout.flush()
        
        for xml_file_path in sorted(glob(join_path(spk_dir_path, '*.xml'))):
            filename = xml_file_path.split('/')[-1]
            if 'final' not in filename:
                continue

            doc_nb = filename.split('_')[2][:3]
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
                    page_src = 'final_'+page_src            # us5: bug in the xml
                    im_page = imread(join_path(spk_dir_path, page_src), flatten=True)
                except FileNotFoundError:
                    print('File '+page_src+' not found. Skipping.')
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
                            stamp = 'final_'+spk_id+'_'+doc_nb+'-'+str(word_nb)

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

