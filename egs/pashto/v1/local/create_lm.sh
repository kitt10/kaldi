#!/bin/bash

# Creates the language model.
# -> data/local/tmp/
# --> arpa.lm, vocab-full.txt

# -> data/lang/
# --> G.fst

set -e

echo "== $0: MAKING lm.arpa"

rm -rf $local_dir/tmp
mkdir -p $local_dir/tmp

ngram-count -order $lm_order \
            -write-vocab $local_dir/tmp/vocab-full.txt -wbdiscount \
            -text $local_dir/corpus.txt \
            -lm $local_dir/tmp/lm.arpa

echo "== $0: MAKING G.fst"

arpa2fst --disambig-symbol=#0 \
        --read-symbol-table=$lang_dir/words.txt \
        $local_dir/tmp/lm.arpa \
        $lang_dir/G.fst