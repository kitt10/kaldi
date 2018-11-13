#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

echo
echo "== $0: $(date): NN TRAINING BASED ON ${nn_base} =="
echo

if [ ! -f ${exp_dir}/${nn_base}/fsts.1.gz ]; then   # this check might be tuned
    nn_ali_subsampling_factor=1
fi

steps/nnet3/chain/train.py \
    --stage -10 \
    --cmd $cmd \
    --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $nn_xent_regularize \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.l2-regularize 0.00005 \
    --chain.apply-deriv-weights false \
    --chain.lm-opts="--num-extra-lm-states=500" \
    --chain.frame-subsampling-factor $subsampling_factor \
    --chain.alignment-subsampling-factor $nn_ali_subsampling_factor \
    --trainer.srand 0 \
    --trainer.max-param-change 2.0 \
    --trainer.num-epochs $nn_numepochs \
    --trainer.frames-per-iter 1500000 \
    --trainer.optimization.num-jobs-initial $nn_nj_initial \
    --trainer.optimization.num-jobs-final $nn_nj_final \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.optimization.shrink-value 1.0 \
    --trainer.num-chunk-per-minibatch $nn_numchunk_per_minibatch \
    --trainer.optimization.momentum 0.0 \
    --egs.chunk-width $nn_chunk_width \
    --egs.chunk-left-context 0 \
    --egs.chunk-right-context 0 \
    --egs.chunk-left-context-initial 0 \
    --egs.chunk-right-context-final 0 \
    --egs.opts="--frames-overlap-per-eg 0" \
    --cleanup.remove-egs true \
    --use-gpu $nn_use_gpu \
    --feat-dir $train_data_dir \
    --tree-dir $nn_treedir \
    --lat-dir $nn_latdir \
    --dir $nn_dir  || exit 1;

echo
echo "== $0: $(date): DONE NN TRAINING BASED ON ${nn_base}. =="
echo
