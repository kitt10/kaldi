#!/bin/bash

. ./path.sh

mkdir -p data/lang data/lang/work
lang_tmp=data/lang/work/tmp_lang
rm -rf $lang_tmp

utils/prepare_lang.sh --num-sil-states 4 \
                      --num-nonsil-states 8 \
                      data/local/dict "<UNK>" $lang_tmp data/lang

ngram-count -order 2 \
            -write-vocab ${lang_tmp}/vocab-full.txt -wbdiscount \
            -text data/local/corpus.txt \
            -lm ${lang_tmp}/lm.arpa

arpa2fst --disambig-symbol=#0 \
         --read-symbol-table=data/lang/words.txt \
         ${lang_tmp}/lm.arpa \
         data/lang/G.fst
