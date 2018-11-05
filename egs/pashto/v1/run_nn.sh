#!/bin/bash

set -e -o pipefail

stage=0

. ./cmd.sh
. ./path.sh
. ./config.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

# TRAINING settings
base=tri2    # dir name in exp/
train_data_dir=data/train

# DECODE settings
test_data_dir=data/test
decode_train=false

# Chain and training options
train_stage=-10
get_egs_stage=-10
xent_regularize=0.1
tdnn_dim=450
chunk_width=340,300,200,100
srand=0
remove_egs=true
minibatch_size=150=64,32/300=32,16/600=16,8/1200=8,4
cmvn_opts="--norm-means=false --norm-vars=false"
chunk_left_context=0
chunk_right_context=0
num_leaves=300
alignment_subsampling_factor=$subsampling_factor   # but changed to 1 if base is e2e

base_dir=exp/${base}_ali
lat_dir=exp/work/nn_${base}_lats
dir=exp/nn_${base}
tree_dir=exp/work/nn_${base}_tree
lang_dir_train=data/lang_nn_${base}

if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

for f in $train_data_dir/feats.scp \
    $base_dir/ali.1.gz $base_dir/final.mdl; do
  [ ! -f $f ] && echo "$0: expected file $f to exist" && exit 1
done

if [ $stage -le 1 ]; then
  image/fix_data_dir.sh $train_data_dir
  image/fix_data_dir.sh $test_data_dir

  utils/validate_data_dir.sh $train_data_dir
  utils/validate_data_dir.sh $test_data_dir

  echo "$0: Removing old files.."
  rm -rf $dir $tree_dir $lat_dir

  echo "$0: Creating lang directory $lang_dir_train with chain-type topology.."
  # Create a version of the lang/ directory that has one state per phone in the
  # topo file. [note, it really has two states.. the first one is only repeated
  # once, the second one has zero or more repeats.]
  if [ -d $lang_dir_train ]; then
    if [ $lang_dir_train/L.fst -nt data/lang/L.fst ]; then
      echo "$0: $lang_dir_train already exists, not overwriting it; continuing.."
    else
      echo "$0: $lang_dir_train already exists and seems to be older than data/lang..."
      echo " ... not sure what to do.  Exiting.."
      exit 1;
    fi
  else

  cp -r $lang_dir $lang_dir_train
  silphonelist=$(cat $lang_dir_train/phones/silence.csl) || exit 1;
  nonsilphonelist=$(cat $lang_dir_train/phones/nonsilence.csl) || exit 1;
  # Use our special topology (later might need some tuning)...
  steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist >$lang_dir_train/topo
  fi
fi

if [ $stage -le 2 ]; then
  # Get the alignments as lattices (gives the chain training more freedom).
  # use the same num-jobs as the alignments
  if [ ${base} = "e2e" ]; then
    steps/nnet3/align_lats.sh --nj $n_jobs --cmd "$cmd" \
                              --acoustic-scale 1.0 \
                              --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0' \
                              ${train_data_dir} $lang_dir $base_dir $lat_dir
    echo "" >$lat_dir/splice_opts
    alignment_subsampling_factor=1
  else
    steps/align_fmllr_lats.sh --nj $n_jobs --cmd "$cmd" ${train_data_dir} \
                              $lang_dir $base_dir $lat_dir
    rm $lat_dir/fsts.*.gz # save space
  fi
fi

if [ $stage -le 3 ]; then
  # Build a tree using our new topology.  We know we have alignments for the
  # speed-perturbed data (local/nnet3/run_ivector_common.sh made them), so use
  # those.  The num-leaves is always somewhat less than the num-leaves from
  # the GMM baseline.
  if [ -f $tree_dir/final.mdl ]; then
     echo "$0: $tree_dir/final.mdl already exists, refusing to overwrite it."
     exit 1;
  fi

  ## TODO: added alighnment-subsampling-factor for e2e
  ## need to check if it works also for tri2...

  steps/nnet3/chain/build_tree.sh \
    --frame-subsampling-factor $subsampling_factor \
    --alignment-subsampling-factor $alignment_subsampling_factor \
    --context-opts "--context-width=2 --central-position=1" \
    --cmd "$cmd" $num_leaves ${train_data_dir} \
    $lang_dir_train $base_dir $tree_dir
fi


if [ $stage -le 4 ]; then
  mkdir -p $dir
  echo "$0: Creating neural net configs using the xconfig parser..";

  num_targets=$(tree-info $tree_dir/tree | grep num-pdfs | awk '{print $2}')
  learning_rate_factor=$(echo "print 0.5/$xent_regularize" | python)
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
  relu-batchnorm-layer name=prefinal-chain dim=$tdnn_dim target-rms=0.5 $tdnn_opts
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5 $output_opts

  # adding the layers for xent branch
  # This block prints the configs for a separate output that will be
  # trained with a cross-entropy objective in the 'chain' mod?els... this
  # has the effect of regularizing the hidden parts of the model.  we use
  # 0.5 / args.xent_regularize as the learning rate factor- the factor of
  # 0.5 / args.xent_regularize is suitable as it means the xent
  # final-layer learns at a rate independent of the regularization
  # constant; and the 0.5 was tuned so as to make the relative progress
  # similar in the xent and regular final layers.
  relu-batchnorm-layer name=prefinal-xent input=tdnn3 dim=$tdnn_dim target-rms=0.5 $tdnn_opts
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5 $output_opts
EOF
  steps/nnet3/xconfig_to_configs.py --xconfig-file $dir/configs/network.xconfig --config-dir $dir/configs/
fi

if [ $stage -le 5 ]; then
  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl \
     /export/b0{3,4,5,6}/$USER/kaldi-data/egs/iam-$(date +'%m_%d_%H_%M')/s5/$dir/egs/storage $dir/egs/storage
  fi

  ## TODO alignment-subsampling-factor was $subsampling_factor
  ## need to check if it works also for non-e2e systems

  steps/nnet3/chain/train.py --stage=$train_stage \
    --cmd="$cmd" \
    --feat.cmvn-opts="--norm-means=false --norm-vars=false" \
    --chain.xent-regularize $xent_regularize \
    --chain.leaky-hmm-coefficient=0.1 \
    --chain.l2-regularize=0.00005 \
    --chain.apply-deriv-weights=false \
    --chain.lm-opts="--num-extra-lm-states=500" \
    --chain.frame-subsampling-factor=$subsampling_factor \
    --chain.alignment-subsampling-factor=$alignment_subsampling_factor \
    --trainer.srand=$srand \
    --trainer.max-param-change=2.0 \
        --trainer.num-epochs=4 \
    --trainer.frames-per-iter=1500000 \
    --trainer.optimization.num-jobs-initial=3 \
    --trainer.optimization.num-jobs-final=10 \
    --trainer.optimization.initial-effective-lrate=0.001 \
    --trainer.optimization.final-effective-lrate=0.0001 \
    --trainer.optimization.shrink-value=1.0 \
    --trainer.num-chunk-per-minibatch=128,64 \
    --trainer.optimization.momentum=0.0 \
    --egs.chunk-width=$chunk_width \
    --egs.chunk-left-context=$chunk_left_context \
    --egs.chunk-right-context=$chunk_right_context \
    --egs.chunk-left-context-initial=0 \
    --egs.chunk-right-context-final=0 \
    --egs.opts="--frames-overlap-per-eg 0" \
    --cleanup.remove-egs=$remove_egs \
    --use-gpu=true \
    --feat-dir=$train_data_dir \
    --tree-dir=$tree_dir \
    --lat-dir=$lat_dir \
    --dir=$dir  || exit 1;
fi

if [ $stage -le 6 ]; then
  # The reason we are using data/lang here, instead of $lang, is just to
  # emphasize that it's not actually important to give mkgraph.sh the
  # lang directory with the matched topology (since it gets the
  # topology file from the model).  So you could give it a different
  # lang directory, one that contained a wordlist and LM of your choice,
  # as long as phones.txt was compatible.

  utils/mkgraph.sh \
    --self-loop-scale 1.0 $lang_dir_decode \
    $dir $dir/graph || exit 1;
fi

if [ $stage -le 7 ]; then
  echo
  echo "== DECODING MODEL NN based on $base =="
  echo "$(date): Using LM $lang_dir_decode"

  lm_affix=$(basename $lang_dir_decode)
  rm -rf $dir/decode_test_$lm_affix

  frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
  steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
    --extra-left-context $chunk_left_context \
    --extra-right-context $chunk_right_context \
    --extra-left-context-initial 0 \
    --extra-right-context-final 0 \
    --frames-per-chunk $frames_per_chunk \
    --nj $n_jobs --cmd "$cmd" \
    $dir/graph $test_data_dir $dir/decode_test_$lm_affix || exit 1;

  if $decode_train; then
    rm -rf $dir/decode_train_$lm_affix
    steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
      --extra-left-context $chunk_left_context \
      --extra-right-context $chunk_right_context \
      --extra-left-context-initial 0 \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj $n_jobs --cmd "$cmd" \
      $dir/graph $train_data_dir $dir/decode_train_$lm_affix || exit 1;
  fi

  local/print_wer.sh $dir $lm_affix
fi

echo
echo "===== DONE. ====="
echo
