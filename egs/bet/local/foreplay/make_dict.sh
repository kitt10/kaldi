#!/bin/bash

# Creates the corpus file for SRILM. Creates the dictionary.
# -> data/local/
# --> corpus.txt, corpus_bpe.txt
# --> dict/
# ---> lexicon.txt, nonsilence_phones.txt, silence_phones.txt
# ---> optional_silence.txt, extra_questions.txt
# --> bpe/

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

rm -rf $dict_dir
rm -rf $bpe_dir
rm -f $local_dir/corpus_bpe.txt

# Make the corpus file (corpus.txt)
corpus_file=${local_dir}/corpus.txt
cut -d' ' -f2- ${train_data_dir}/text ${test_data_dir}/text > $corpus_file

if $use_bpe; then
    local/foreplay/apply_bpe.sh $cfg
    corpus_file=${local_dir}/corpus_bpe.txt
fi

mkdir -p $dict_dir
local/foreplay/make_dict.py --corpus_file $corpus_file \
                            --dict_dir $dict_dir \
                            --oov_word $oov_word \
                            --use_bpe $use_bpe
