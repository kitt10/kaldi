#!/bin/bash

# Extracts features for the "train" and "test" data subsets.
# -> data/train/
# --> feats.scp, cmvn.scp

# -> data/train/data/
# --> images.ark, cmvn_train.scp, cmvn_train.ark

# -> data/test/
# --> feats.scp, cmvn.scp

# -> data/test/data/
# --> images.ark, cmvn_test.scp, cmvn_test.ark

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

rm -rf ${train_data_dir}/data
rm -rf ${test_data_dir}/data
mkdir -p ${train_data_dir}/data
mkdir -p ${test_data_dir}/data

# Convert the images into kaldi matrices
for set_dir in $train_data_dir $test_data_dir; do
    local/foreplay/make_features.py --images_orig_file ${set_dir}/images_orig.scp \
                                    --images_file ${set_dir}/images.scp \
                                    --allowed_lengths_file ${local_dir}/allowed_lengths.txt \
                                    --feat_dim $feature_dim \
                                    --invert_colors $invert_colors \
                                    --pad_pixels $pad_pixels \
                                    --save_images $save_images \
                                    --fliplr true | \
    copy-feats --compress=true --compression-method=7 \
               ark:- ark,scp:${set_dir}/data/images.ark,${set_dir}/feats.scp || exit 1

    steps/compute_cmvn_stats.sh ${set_dir} || exit 1;
done
