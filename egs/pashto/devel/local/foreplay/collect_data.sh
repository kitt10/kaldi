#!/bin/bash

# Collects the data and process it.
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

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

rm -rf ${data_dir}
mkdir -p ${train_data_dir}
mkdir -p ${test_data_dir}
mkdir -p ${local_dir}
mkdir -p ${data_log_dir}

# Transform the raw data into the kaldi-compatible format
local/foreplay/collect_data.py --raw_data_path $raw_data_path \
                               --train_data_dir $train_data_dir \
                               --test_data_dir $test_data_dir \
                               --local_dir $local_dir \
                               --images_dir $images_dir \
                               --data_log_dir $data_log_dir \
                               --us_spks $us_spks \
                               --af_spks $af_spks \
                               --max_samples $max_samples \
                               --first_spknb_test $first_spknb_test \
                               --feat_dim $feature_dim \
                               --pad_pixels $pad_pixels \
                               --save_images $save_images \
                               --frame_subsampling_factor $subsampling_factor \
                               --spacing_factor $al_spacing_factor \
                               --coverage_factor $al_coverage_factor || exit 1

# Convert utt2spk into spk2utt for train and test
utils/utt2spk_to_spk2utt.pl ${train_data_dir}/utt2spk > ${train_data_dir}/spk2utt
utils/utt2spk_to_spk2utt.pl ${test_data_dir}/utt2spk > ${test_data_dir}/spk2utt
