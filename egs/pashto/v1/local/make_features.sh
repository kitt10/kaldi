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

rm -rf data/{train,test}/data
mkdir -p data/{train,test}/data

echo "== $0: Preparing feature files for the test and training data.."
for f in train test; do
    local/make_features.py --im_dir data/$f --fliplr true \
                           --allowed_len_file $local_dir/allowed_lengths.txt | \
    copy-feats --compress=true --compression-method=7 \
               ark:- ark,scp:data/$f/data/images.ark,data/$f/feats.scp || exit 1

    steps/compute_cmvn_stats.sh data/$f || exit 1;
done
