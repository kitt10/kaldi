#!/bin/bash

set -e

. ./config.sh

echo
echo "== $0: $(date): FMLLR ALIGNMENT =="
echo
steps/align_fmllr.sh --nj $n_jobs --cmd $cmd $train_data_dir \
                       $lang ${exp_dir}/sat ${exp_dir}/sat_ali

echo
echo "== $0: $(date): DONE FMLLR ALIGNMENT. =="
echo
