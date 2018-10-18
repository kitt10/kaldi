#!/usr/bin/env python3

# creates dict files:

# lexicon.txt
# lexiconp.txt
# nonsilence_phones.txt
# silence_phones.txt
# optional_silence.txt
# extra_questions.txt ??

from argparse import ArgumentParser
from codecs import open as cod_open

def parse_args():
    parser = ArgumentParser(description='Creates data/local/dict.')
    parser.add_argument('--trs_files', nargs='+', type=str, help='path to all text files with transcriptions')
    parser.add_argument('--out_dir', type=str, default='data/local/dict/', help='where to create the dict directory')
    parser.add_argument('--oov_word', type=str, default='<unk>', help='unknown (oov) word')
    return parser.parse_args()

if __name__ == '__main__':
    args = parse_args()

    all_words = list()
    for trs_filename in args.trs_files:
        with cod_open(trs_filename, 'r', encoding='utf-8') as f:
            for line in f.readlines():
                all_words.append(line.split()[1])

    all_words_unique = list(set(all_words))

    # lexicon.txt and lexiconp.txt
    f_lexicon = cod_open(args.out_dir+'lexicon.txt', 'w+', encoding='utf-8')
    f_lexiconp = cod_open(args.out_dir+'lexiconp.txt', 'w+', encoding='utf-8')
    
    for word in sorted(all_words_unique):
        word_aer = ' '.join(word)
        f_lexicon.write(word+' '+word_aer+'\n')
        f_lexiconp.write(word+' 1.0 '+word_aer+'\n')

    f_lexicon.write(args.oov_word+' spn\n')
    f_lexicon.write('<sil> sil\n')
    f_lexiconp.write(args.oov_word+' 1.0 spn\n')
    f_lexiconp.write('<sil> 1.0 sil\n')

    f_lexicon.close()
    f_lexiconp.close()

    # nonsilence_phones.txt, silence_phones.txt and nonsilence_phones.txt
    unique_chars = list(set([ch for word in all_words_unique for ch in word]))
    
    with cod_open(args.out_dir+'nonsilence_phones.txt', 'w', encoding='utf-8') as f:
        for ch in sorted(unique_chars):
            f.write(ch+'\n')
    
    with cod_open(args.out_dir+'silence_phones.txt', 'w', encoding='utf-8') as f:
        f.write('<sil>\n')
        f.write('<spn>\n')

    with cod_open(args.out_dir+'optional_silence.txt', 'w', encoding='utf-8') as f:
        f.write('<sil>\n')
