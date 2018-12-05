#!/bin/bash

set -e

cfg=$1
model=$2

# shellcheck source=config.sh
. ./${cfg}

if [ -z "$3" ]; then
  d_dir=$train_data_dir
  model_dir=${exp_dir}/${model}
  out_dir=${exp_dir}/${model}_ali
else
  d_dir=$3
  model_dir=$4
  out_dir=$5
fi

echo
echo "== $0: $(date): SI ALIGNMENT FOR MODEL $model =="
steps/align_si.sh --nj $n_jobs --cmd $cmd $d_dir $lang \
                  $model_dir $out_dir

echo
echo "== $0: $(date): DONE SI ALIGNMENT FOR MODEL $model. =="
