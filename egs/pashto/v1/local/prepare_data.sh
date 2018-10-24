#!/bin/bash

# Prepares the "train" and "test" data subsets.
# -> data/train/
# --> text, images.scp, utt2spk, spk2utt

# -> data/test/
# --> text, images.scp, utt2spk, spk2utt

set -e

echo "== $0: Preparing the test and train subsets.."

rm -rf data
mkdir -p data/train
mkdir -p data/test

# Transform the raw data into the kaldi-compatible format
local/prepare_data.py --data_path $data_path \
                      --out_dir data \
                      --us_spks $us_spks \
                      --af_spks $af_spks \
                      --max_samples $max_samples \
                      --feat_dim $feature_dim \
                      --invert $invert_images \
                      --pad $pad_images \
                      --add_noise $add_noise \
                      --log_dir local/log || exit 1

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
