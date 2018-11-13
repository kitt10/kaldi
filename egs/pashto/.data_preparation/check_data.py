#!/usr/bin/env python3

# Check if every transcription have an image
# Check for duplicate transcription lines in one file

from glob import glob
from codecs import open as cod_open
from os.path import join as join_path, exists
from sys import stdout

if __name__ == '__main__':
    set_name = 'Afghanistan'    # [Afghanistan | US_Final]

    trs_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/'+set_name+'/extractedWords/transcriptions'
    words_dir = '/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/WordImages/'+set_name+'/extractedWords/words'

    for file_i, txt_file_path in enumerate(sorted(glob(join_path(trs_dir, '*.txt')))):
        filename = txt_file_path.split('/')[-1]
        word_nb = filename.strip('.txt')

        with cod_open(txt_file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()

        with cod_open(txt_file_path, 'w', encoding='utf-8') as f:
            written_lines = list()
            for line in lines:
                im_name = line[line.find('(')+1:line.find(')')]+'.bmp'
                if exists(join_path(words_dir, word_nb, im_name)):
                    if line not in written_lines:
                        f.write(line)
                        written_lines.append(line)
                    else:
                        print('DUP in '+filename+': '+line)
                else:
                    print('MISSING IMAGE: '+im_name)

        if (file_i+1) % 20 == 0:
            print('Checked '+str(file_i+1)+' files.')
        stdout.flush()