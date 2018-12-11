#!/bin/bash

set -e

. ./path.sh

lm_order=$1

lang=data/lang
lang_work=data/local/lang_work
rm -rf $lang $lang_work

utils/prepare_lang.sh --num-sil-states 4 \
                      --num-nonsil-states 8 \
                      data/local/dict "<UNK>" $lang_work $lang

ngram-count -order $lm_order \
            -write-vocab ${lang_work}/vocab-full.txt -wbdiscount \
            -text data/local/corpus.txt \
            -lm ${lang_work}/lm.arpa

arpa2fst --disambig-symbol=#0 \
         --read-symbol-table=${lang}/words.txt \
         ${lang_work}/lm.arpa \
         ${lang}/G.fst
