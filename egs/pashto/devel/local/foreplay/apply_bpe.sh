#!/bin/bash

set -e

. ./config.sh

mkdir -p $bpe_dir

# getting phones and bpe train text
cut -d' ' -f2 ${train_data_dir}/text | grep -o . | sort -u > ${bpe_dir}/phones.txt
cut -d' ' -f2 ${train_data_dir}/text > ${bpe_dir}/bpe_train_text.txt

# getting bpe corpus
local/foreplay/clean_corpus.py --local_dir $local_dir --bpe_dir $bpe_dir

# getting bpe.txt
cat ${bpe_dir}/phones.txt ${bpe_dir}/bpe_train_text.txt | \
  utils/lang/bpe/prepend_words.py | \
    utils/lang/bpe/learn_bpe.py -s 700 > ${bpe_dir}/bpe.txt || exit 1;

# applying bpe on train and test text
for set_dir in $train_data_dir $test_data_dir; do
  cut -d' ' -f1 ${set_dir}/text > ${bpe_dir}/tmp_ids
  cut -d' ' -f2 ${set_dir}/text | utils/lang/bpe/prepend_words.py | \
    utils/lang/bpe/apply_bpe.py -c ${bpe_dir}/bpe.txt | \
    sed 's/@@//g' > ${bpe_dir}/tmp_text

  paste -d' ' ${bpe_dir}/tmp_ids ${bpe_dir}/tmp_text > ${bpe_dir}/text_bpe
  rm -f ${bpe_dir}/tmp_ids ${bpe_dir}/tmp_text
done

# applying bpe on corpus
cat ${bpe_dir}/clean_corpus.txt | utils/lang/bpe/prepend_words.py | \
  utils/lang/bpe/apply_bpe.py -c ${bpe_dir}/bpe.txt | \
  sed 's/@@//g' > ${local_dir}/corpus_bpe.txt
