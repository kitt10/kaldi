#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): NN ALIGNMENT FOR MODEL $nn_id =="
echo
steps/nnet3/align.sh --nj $n_jobs --cmd $cmd \
                     --use-gpu false \
                     --scale-opts '--transition-scale=1.0 --acoustic-scale=1.0 --self-loop-scale=1.0' \
                     $train_data_dir $lang ${exp_dir}/${nn_id} ${exp_dir}/${nn_id}_ali

echo
echo "== $0: $(date): DONE NN ALIGNMENT FOR MODEL $nn_id. =="
echo
