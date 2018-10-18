#!/bin/bash

# Prepares the "train" and "test" data subsets.

set -e

echo "$0: Preparing the test and train subsets..."

rm -rf data
mkdir -p data/train
mkdir -p data/test
for spk in ${spks[@]}; do mkdir -p data/local/images/$spk; done

# Transform the raw data into the kaldi-compatible format
local/process_data.py --data_path_tr $data_path_tr \
--data_path_im $data_path_im --out_dir data --spks "$spks" || exit 1

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
