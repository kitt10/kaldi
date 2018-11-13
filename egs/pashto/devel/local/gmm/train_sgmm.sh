#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): TRAIN UBM+SGMM =="
echo
steps/train_ubm.sh --cmd $cmd $ubm_numgauss $train_data_dir $lang \
                   ${exp_dir}/${ubm_base}_ali ${exp_dir}/ubm

steps/train_sgmm2.sh --cmd $cmd $sgmm_numpdfs $sgmm_totsubstates \
                     $train_data_dir $lang ${exp_dir}/${sgmm_base}_ali \
                     ${exp_dir}/${sgmm_base}/final.ubm ${exp_dir}/sgmm

echo
echo "== $0: $(date): DONE UBM+SGMM TRAINING. =="
echo
