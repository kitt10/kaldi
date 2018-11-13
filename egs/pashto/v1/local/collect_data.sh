#!/bin/bash

# Collects the data.
# -> data/train/
# --> text, images.scp, utt2spk, spk2utt

# -> data/test/
# --> text, images.scp, utt2spk, spk2utt

# -> data/local/
# --> allowed_lengths.txt
# --> images/

# -> data/log/
# --> collect_data.log

set -e

. ./path.sh

raw_data_path="/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/database/\
WordImages"

rm -rf data
mkdir -p data/train
mkdir -p data/test
mkdir -p data/local
mkdir -p data/log

# Transform the raw data into the kaldi-compatible format
local/collect_data.py --raw_data_path $raw_data_path \
                      --us_spks 12 \
                      --af_spks 0 \
                      --first_spknb_test 8 \
                      --feat_dim 40 \
                      --save_images true \
                      --frame_subsampling_factor 4 || exit 1

# Convert utt2spk into spk2utt for train and test
utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
