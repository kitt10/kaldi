#!/bin/bash

set -e

mkdir -p $local_dir/cleaned

echo "$(date) == $0: BPE preparation"
# getting non-silence phones.
cut -d' ' -f2- data/train/text | \
  local/extract_phones.py > $local_dir/cleaned/phones.txt

cut -d' ' -f2- data/train/text > $local_dir/cleaned/train.txt

echo "$(date) == $0: Processing corpus text..."
# we are removing the lines from the corpus which which have
# phones other than the phones in data/local/text/cleaned/phones.txt.
cat $local_dir/corpus.txt | \
  local/check_phones.py --local_dir $local_dir > $local_dir/cleaned/corpus.txt

echo "$(date) == $0: Learning BPE..."
# it is currently learned with only training text but we can also use all corpus text
# to learn BPE. phones are added so that one isolated occurance of every phone exists.
cat $local_dir/cleaned/phones.txt $local_dir/cleaned/train.txt | \
  utils/lang/bpe/prepend_words.py | utils/lang/bpe/learn_bpe.py -s 700 > data/local/bpe.txt || exit 1;

echo "$(date) == $0: Applying BPE on train, test text..."
for set in test train; do
  cut -d' ' -f1 data/$set/text > data/$set/ids
  cut -d' ' -f2- data/$set/text | utils/lang/bpe/prepend_words.py | \
    utils/lang/bpe/apply_bpe.py -c $local_dir/bpe.txt | \
    sed 's/@@//g' > data/$set/bpe_text

  paste -d' ' data/$set/ids data/$set/bpe_text > data/$set/text_bpe
  rm -f data/$set/bpe_text data/$set/ids
done

echo "$(date) == $0: Applying BPE on corpus text..."
cat $local_dir/cleaned/corpus.txt | utils/lang/bpe/prepend_words.py | \
  utils/lang/bpe/apply_bpe.py -c $local_dir/bpe.txt | \
  sed 's/@@//g' > $local_dir/cleaned/corpus_bpe.txt
