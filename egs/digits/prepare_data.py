#!/usr/bin/env python
# -*- coding: utf-8 -*-

from wave import open as open_wav
import numpy as np
import os, shutil


def write_file(a_path, a_list):
    with open(a_path, 'w') as f:
        for i_line, line in enumerate(sorted(a_list)):
            if i_line == 0:
                f.write(line)
            else:
                f.write('\n'+line)

    print a_path, 'WRITTEN!'


if __name__ == '__main__':

    digits = {'0': 'zero', '1': 'one', '2': 'two', '3': 'three', '4': 'four', '5': 'five', '6': 'six', '7': 'seven',
              '8': 'eight', '9': 'nine'}

    spks = ('jackson', 'nicolas', 'theo')
    spks_gender = {'jackson': 'm', 'nicolas': 'm', 'theo': 'm'}
    n_obs = 50
    source = dict([(spk, dict([(d, [d+'_'+spk+'_'+str(i) for i in range(n_obs)]) for d in digits.keys()])) for spk in spks])

    spks_test = ('theo',)
    spks_train = tuple(set(spks)-set(spks_test))
    words_per_utt = 3
    utts_per_spk = 100
    utt_zfill = 4
    raw_audio_path = '/media/kitt/snorlax/data/wav_digits/'
    res_audio_path = '/home/kitt/kaldi/egs/digits/digits_audio/'
    data_path = '/home/kitt/kaldi/egs/digits/data/'

    # Remove old data
    dirs_to_delete = [res_audio_path+'train/'+spk for spk in spks_train]+\
                     [res_audio_path+'test/'+spk for spk in spks_test]+\
                     [data_path+'train/', data_path+'test/']

    for folder in dirs_to_delete:
        for the_file in os.listdir(folder):
            file_path = os.path.join(folder, the_file)
            try:
                if os.path.isfile(file_path):
                    os.unlink(file_path)

            except Exception as e:
                print(e)

        print folder, 'EMPTY!'

    # Randomly combine data
    wav_scp = {'train': list(), 'test': list()}
    text = {'train': list(), 'test': list()}
    utt2spk = {'train': list(), 'test': list()}
    corpus = set()
    for spk in spks:
        spk_set = 'test' if spk in spks_test else 'train'
        for kth_utt in range(utts_per_spk):
            filename = ''
            trs = ''
            utt = list()
            for ith_word in range(words_per_utt):
                digit = np.random.choice([d for d in digits.keys() if source[spk][d]])
                filename += digit+'_'
                trs += digits[digit]+' '

                sample_name = np.random.choice(source[spk][digit])
                sample_path = raw_audio_path+sample_name+'.wav'
                f = open_wav(sample_path, 'rb')
                utt.append([f.getparams(), f.readframes(f.getnframes())])
                f.close()

            filename += str(kth_utt).zfill(utt_zfill)
            utt_id = spk+'_'+filename
            trs = trs[:-1]
            file_path = res_audio_path+spk_set+'/'+spk+'/'+filename+'.wav'
            f = open_wav(file_path, 'wb')
            f.setparams(utt[0][0])
            for utt_i in range(len(utt)):
                f.writeframes(utt[utt_i][1])
            f.close()

            wav_scp[spk_set].append(utt_id+' '+file_path)
            text[spk_set].append(utt_id+' '+trs)
            utt2spk[spk_set].append(utt_id+' '+spk)
            corpus.add(trs)

        write_file(data_path+spk_set+'/wav.scp', wav_scp[spk_set])
        write_file(data_path+spk_set+'/text', text[spk_set])
        write_file(data_path+spk_set+'/utt2spk', utt2spk[spk_set])
        write_file(data_path+'local/corpus.txt', list(corpus))

    write_file(data_path+'train/spk2gender', [spk+' '+spks_gender[spk] for spk in spks_train])
    write_file(data_path+'test/spk2gender', [spk+' '+spks_gender[spk] for spk in spks_test])