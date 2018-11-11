#!/bin/bash

set -e

. ./config.sh

echo
echo "== $0: $(date): TRAIN LDA+MLLT =="
echo
steps/train_lda_mllt.sh --cmd $cmd --splice-opts "$mllt_sliceopts" \
                          $mllt_numleaves $mllt_totgauss $train_data_dir \
                          $lang ${exp_dir}/${mllt_base}_ali ${exp_dir}/mllt

echo
echo "== $0: $(date): DONE LDA+MLLT TRAINING. =="
echo
