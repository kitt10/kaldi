#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

if [ -z "$2" ]; then
  d_dir=$train_data_dir
  model_dir=${exp_dir}/${nn_id}
  out_dir=${exp_dir}/${nn_id}_ali
else
  d_dir=$2
  model_dir=$3
  out_dir=$4
fi

echo
echo "== $0: $(date): NN ALIGNMENT FOR MODEL $nn_id =="
steps/nnet3/align.sh --nj $n_jobs --cmd $cmd \
                     --use-gpu false \
                     --scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0' \
                     $d_dir $lang $model_dir $out_dir

echo
echo "== $0: $(date): DONE NN ALIGNMENT FOR MODEL $nn_id. =="
