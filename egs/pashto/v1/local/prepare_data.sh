#!/bin/bash

# Prepares the "train" and "test" data subsets.
# -> data/train/
# --> text, images.scp, utt2spk, spk2utt

# -> data/test/
# --> text, images.scp, utt2spk, spk2utt

# -> data/images

set -e

echo "== $0: Preparing the test and train subsets.."

rm -rf data
mkdir -p data/train
mkdir -p data/test
mkdir -p data/log

# Transform the raw data into the kaldi-compatible format
local/prepare_data.py --data_path $data_path \
                      --out_dir data \
                      --us_spks $us_spks \
                      --af_spks $af_spks \
                      --max_samples $max_samples \
                      --feat_dim $feature_dim \
                      --invert $invert_images \
                      --pad_value $pad_images \
                      --add_noise $add_noise \
                      --log_dir data/log || exit 1

# Create allowed_lengths.txt based on im_widths.txt
local/get_allowed_lengths.py --local_dir $local_dir \
                             --frame_subsampling_factor $subsampling_factor \
                             --spacing_factor $spacing_factor \
                             --coverage_factor $coverage_factor

# Convert utt2spk into spk2utt for train and test
utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
