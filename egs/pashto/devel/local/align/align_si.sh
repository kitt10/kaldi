#!/bin/bash

set -e

cfg=$1
model=$2

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): SI ALIGNMENT FOR MODEL $model =="
steps/align_si.sh --nj $n_jobs --cmd $cmd $train_data_dir $lang \
                  ${exp_dir}/${model} ${exp_dir}/${model}_ali

echo
echo "== $0: $(date): DONE SI ALIGNMENT FOR MODEL $model. =="
