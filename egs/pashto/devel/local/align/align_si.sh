#!/bin/bash

set -e

. ./config.sh

model=$1

echo
echo "== $0: $(date): SI ALIGNMENT FOR MODEL $1 =="
echo
steps/align_si.sh --nj $n_jobs --cmd $cmd $train_data_dir $lang \
                  ${exp_dir}/${model} ${exp_dir}/${model}_ali

echo
echo "== $0: $(date): DONE SI ALIGNMENT FOR MODEL $1. =="
echo
