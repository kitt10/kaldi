#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

echo
echo "== $0: $(date): NN ENVIRONMENT CHECK =="
echo

if $nn_use_gpu && ! cuda-compiled; then
  cat <<EOF && exit 1
!!E: This script is intended to be used with GPUs but you have not compiled 
Kaldi with CUDA. If you want to use GPUs (and have them), go to src/, and 
configure and make on a machine where "nvcc" is installed.
EOF
fi

for f in $train_data_dir/feats.scp ${exp_dir}/${nn_base}/ali.1.gz \
  ${exp_dir}/${nn_base}/final.mdl; do
    [ ! -f $f ] && echo "$0: !!E: Expected file $f to exist." && exit 1
done

echo
echo "== $0: $(date): DONE NN ENVIRONMENT CHECK. =="
echo
