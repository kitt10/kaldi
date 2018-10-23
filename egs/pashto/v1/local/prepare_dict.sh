#!/bin/bash

# Prepares the dictionary.
# -> data/lang/local/
# --> corpus.txt

# -> data/lang/local/dict/
# --> lexicon.txt, nonsilence_phones.txt, silence_phones.txt
# --> optional_silence.txt, extra_questions.txt

set -e

echo "== $0: Preparing the dictionary.."

rm -rf $dict_dir
mkdir -p $dict_dir
local/prepare_dict.py --trs_files data/train/text data/test/text \
                      --local_dir $local_dir \
                      --dict_dir $dict_dir \
                      --oov_word $oov_word