#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

echo
echo "== $0: $(date): NN TRAINING E2E =="

steps/nnet3/chain/e2e/train_e2e.py \
    --stage $nn_train_stage \
    --cmd $cmd \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.apply-deriv-weights true \
    --egs.stage -10 \
    --egs.opts "--num_egs_diagnostic 100 --num_utts_subset 400" \
    --chain.frame-subsampling-factor $subsampling_factor \
    --chain.alignment-subsampling-factor $subsampling_factor \
    --trainer.add-option="--optimization.memory-compression-level=2" \
    --trainer.num-chunk-per-minibatch $nn_numchunk_per_minibatch \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs $nn_numepochs \
    --trainer.optimization.momentum 0 \
    --trainer.optimization.num-jobs-initial $nn_nj_initial \
    --trainer.optimization.num-jobs-final $nn_nj_final \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.optimization.shrink-value 1.0 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs true \
    --feat-dir $train_data_dir \
    --tree-dir $nn_treedir \
    --dir $nn_dir  || exit 1;

echo
echo "== $0: $(date): DONE NN TRAINING E2E. =="
