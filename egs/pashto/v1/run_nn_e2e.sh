#!/bin/bash

set -e      # exit if a pipeline returns a non-zero status
stage=0

. ./cmd.sh
. ./path.sh
. ./config.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

train_stage=-10
get_egs_stage=-10

tdnn_dim=450
minibatch_size=150=64,32/300=32,16/600=16,8/1200=8,4
cmvn_opts="--norm-means=false --norm-vars=false"
train_data_dir=data/train
test_data_dir=data/test
lang_decode=data/lang
lang=data/lang_e2e
treedir=exp/chain/e2e_monotree  # it's actually just a trivial tree (no tree building)
dir=exp/nn_e2e

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

if [ $stage -le 0 ]; then
  rm -rf $lang
  cp -r data/lang $lang
  silphonelist=$(cat $lang/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang/phones/nonsilence.csl) || exit 1;
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang/topo
fi

if [ $stage -le 1 ]; then
  steps/nnet3/chain/e2e/prepare_e2e.sh --nj $n_jobs --cmd "$cmd" \
                                       --shared-phones true \
                                       --type mono \
                                       $train_data_dir $lang $treedir
  $cmd $treedir/log/make_phone_lm.log \
  cat $train_data_dir/text \| \
    steps/nnet3/chain/e2e/text_to_phones.py data/lang \| \
    utils/sym2int.pl -f 2- data/lang/phones.txt \| \
    chain-est-phone-lm --num-extra-lm-states=500 \
                       ark:- $treedir/phone_lm.fst
fi

if [ $stage -le 2 ]; then
  echo "$0: creating neural net configs using the xconfig parser";
  num_targets=$(tree-info $treedir/tree | grep num-pdfs | awk '{print $2}')
  cnn_opts="l2-regularize=0.075"
  tdnn_opts="l2-regularize=0.075"
  output_opts="l2-regularize=0.1"
  common1="$cnn_opts required-time-offsets= height-offsets=-2,-1,0,1,2 num-filters-out=36"
  common2="$cnn_opts required-time-offsets= height-offsets=-2,-1,0,1,2 num-filters-out=70"
  common3="$cnn_opts required-time-offsets= height-offsets=-1,0,1 num-filters-out=70"

  mkdir -p $dir/configs
  cat <<EOF > $dir/configs/network.xconfig
  input dim=$feature_dim name=input
  conv-relu-batchnorm-layer name=cnn1 height-in=$feature_dim height-out=$feature_dim time-offsets=-3,-2,-1,0,1,2,3 $common1
  conv-relu-batchnorm-layer name=cnn2 height-in=$feature_dim height-out=$((feature_dim/2)) time-offsets=-2,-1,0,1,2 $common1 height-subsample-out=2
  conv-relu-batchnorm-layer name=cnn3 height-in=$((feature_dim/2)) height-out=$((feature_dim/2)) time-offsets=-4,-2,0,2,4 $common2
  conv-relu-batchnorm-layer name=cnn4 height-in=$((feature_dim/2)) height-out=$((feature_dim/2)) time-offsets=-4,-2,0,2,4 $common2
  conv-relu-batchnorm-layer name=cnn5 height-in=$((feature_dim/2)) height-out=$((feature_dim/4)) time-offsets=-4,-2,0,2,4 $common2 height-subsample-out=2
  conv-relu-batchnorm-layer name=cnn6 height-in=$((feature_dim/4)) height-out=$((feature_dim/4)) time-offsets=-4,0,4 $common3
  conv-relu-batchnorm-layer name=cnn7 height-in=$((feature_dim/4)) height-out=$((feature_dim/4)) time-offsets=-4,0,4 $common3
  relu-batchnorm-layer name=tdnn1 input=Append(-4,0,4) dim=$tdnn_dim $tdnn_opts
  relu-batchnorm-layer name=tdnn2 input=Append(-4,0,4) dim=$tdnn_dim $tdnn_opts
  relu-batchnorm-layer name=tdnn3 input=Append(-4,0,4) dim=$tdnn_dim $tdnn_opts
  ## adding the layers for chain branch
  relu-batchnorm-layer name=prefinal-chain dim=$tdnn_dim target-rms=0.5 $output_opts
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5 $output_opts
EOF

  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs
fi

if [ $stage -le 3 ]; then
  steps/nnet3/chain/e2e/train_e2e.py --stage $train_stage \
    --cmd "$cmd" \
    --feat.cmvn-opts "$cmvn_opts" \
    --chain.leaky-hmm-coefficient 0.1 \
    --chain.apply-deriv-weights true \
    --egs.stage $get_egs_stage \
    --egs.opts "--num_egs_diagnostic 100 --num_utts_subset 400" \
    --chain.frame-subsampling-factor 4 \
    --chain.alignment-subsampling-factor 4 \
    --trainer.add-option="--optimization.memory-compression-level=2" \
    --trainer.num-chunk-per-minibatch $minibatch_size \
    --trainer.frames-per-iter 1500000 \
    --trainer.num-epochs 3 \
    --trainer.optimization.momentum 0 \
    --trainer.optimization.num-jobs-initial 5 \
    --trainer.optimization.num-jobs-final 8 \
    --trainer.optimization.initial-effective-lrate 0.001 \
    --trainer.optimization.final-effective-lrate 0.0001 \
    --trainer.optimization.shrink-value 1.0 \
    --trainer.max-param-change 2.0 \
    --cleanup.remove-egs true \
    --feat-dir $train_data_dir \
    --tree-dir $treedir \
    --dir $dir  || exit 1;
fi

if [ $stage -le 4 ]; then
  utils/mkgraph.sh \
    --self-loop-scale 1.0 $lang_decode \
    $dir $dir/graph || exit 1;

  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 30 --cmd "$cmd" --beam 12 \
    $dir/graph $test_data_dir $dir/decode_test || exit 1;

  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --nj 30 --cmd "$cmd" --beam 12 \
    $dir/graph $train_data_dir $dir/decode_train || exit 1;

  echo "Done. Date: $(date). Results:"
  local/compare_wer.sh $dir
fi

echo
echo "===== DONE. ====="
echo
