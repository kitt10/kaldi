#!/bin/bash

# Author     2018  Martin Bulin

# Extraction of the isolated words from the database.

set -e

. ./path.sh

corpus_dir=$1

# Check if corpus is extracted already
corpus_ready=true
for set_name in US_Final Afghanistan; do
    if [ ! -d ${corpus_dir}/${set_name}/extractedWords/transcriptions ] || \
       [ ! -d ${corpus_dir}/${set_name}/extractedWords/words ]; then
        corpus_ready=false
    fi
done

if $corpus_ready; then
    echo
    echo "== $0: $(date): Corpus is already extracted. Checking data. =="
    for set_id in us af; do
        local/corpus_extraction/check_fix_words.py --corpus_dir $corpus_dir \
                                                    --set_id $set_id \
                                                    --fix false || exit 1;
    done
else
    echo
    echo "== $0: $(date): Extracting corpus (this might take a while). =="
    for set_id in us af; do
        local/corpus_extraction/extract_words.py --corpus_dir $corpus_dir \
                                                 --set_id $set_id || exit 1;

        local/corpus_extraction/check_fix_words.py --corpus_dir $corpus_dir \
                                                   --set_id $set_id \
                                                   --fix true || exit 1;
    done
fi
