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
for spk in ${spks[@]}; do mkdir -p data/local/images/$spk; done

# Transform the raw data into the kaldi-compatible format
local/prepare_data.py --data_path_tr $data_path_tr \
                      --data_path_im $data_path_im \
                      --out_dir data \
                      --spks "$spks" \
                      --n_samples $n_samples \
                      --feat_dim $feature_dim \
                      --invert $invert_images \
                      --pad $pad_images \
                      --add_noise $add_noise || exit 1

utils/utt2spk_to_spk2utt.pl data/train/utt2spk > data/train/spk2utt
utils/utt2spk_to_spk2utt.pl data/test/utt2spk > data/test/spk2utt
