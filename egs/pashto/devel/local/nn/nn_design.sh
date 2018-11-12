#!/bin/bash

set -e

. ./path.sh
. ./config.sh

echo
echo "== $0: $(date): NN TOPOLOGY DESIGN =="
echo

num_targets=$(tree-info ${nn_treedir}/tree | grep num-pdfs | awk '{print $2}')
cnn_opts="l2-regularize=0.075"
tdnn_opts="l2-regularize=0.075"
output_opts="l2-regularize=0.1"
common1="${cnn_opts} required-time-offsets= height-offsets=-2,-1,0,1,2 num-filters-out=36"
common2="${cnn_opts} required-time-offsets= height-offsets=-2,-1,0,1,2 num-filters-out=70"
common3="${cnn_opts} required-time-offsets= height-offsets=-1,0,1 num-filters-out=70"

mkdir -p ${nn_dir}/configs

if [ -z $nn_base ]; then
  echo "-- $0: $(date): Designing topology for e2e system..."
  cat <<EOF > ${nn_dir}/configs/network.xconfig
  input dim=$feature_dim name=input
  conv-relu-batchnorm-layer name=cnn1 height-in=$feature_dim height-out=$feature_dim time-offsets=-3,-2,-1,0,1,2,3 $common1
  conv-relu-batchnorm-layer name=cnn2 height-in=$feature_dim height-out=$((feature_dim/2)) time-offsets=-2,-1,0,1,2 $common1 height-subsample-out=2
  conv-relu-batchnorm-layer name=cnn3 height-in=$((feature_dim/2)) height-out=$((feature_dim/2)) time-offsets=-4,-2,0,2,4 $common2
  conv-relu-batchnorm-layer name=cnn4 height-in=$((feature_dim/2)) height-out=$((feature_dim/2)) time-offsets=-4,-2,0,2,4 $common2
  conv-relu-batchnorm-layer name=cnn5 height-in=$((feature_dim/2)) height-out=$((feature_dim/4)) time-offsets=-4,-2,0,2,4 $common2 height-subsample-out=2
  conv-relu-batchnorm-layer name=cnn6 height-in=$((feature_dim/4)) height-out=$((feature_dim/4)) time-offsets=-4,0,4 $common3
  conv-relu-batchnorm-layer name=cnn7 height-in=$((feature_dim/4)) height-out=$((feature_dim/4)) time-offsets=-4,0,4 $common3
  relu-batchnorm-layer name=tdnn1 input=Append(-4,0,4) dim=$nn_tdnn_dim $tdnn_opts
  relu-batchnorm-layer name=tdnn2 input=Append(-4,0,4) dim=$nn_tdnn_dim $tdnn_opts
  relu-batchnorm-layer name=tdnn3 input=Append(-4,0,4) dim=$nn_tdnn_dim $tdnn_opts
  ## adding the layers for chain branch
  relu-batchnorm-layer name=prefinal-chain dim=$nn_tdnn_dim target-rms=0.5 $output_opts
  output-layer name=output include-log-softmax=false dim=$num_targets max-change=1.5 $output_opts
EOF

else
  echo "-- $0: $(date): Designing topology for a system based on ${nn_base} alignments..."  
  learning_rate_factor=$(echo "print 0.5/${nn_xent_regularize}" | python)
  cat <<EOF > ${nn_dir}/configs/network.xconfig
  input dim=$feature_dim name=input
  conv-relu-batchnorm-layer name=cnn1 height-in=$feature_dim height-out=$feature_dim time-offsets=-3,-2,-1,0,1,2,3 $common1
  conv-relu-batchnorm-layer name=cnn2 height-in=$feature_dim height-out=$((feature_dim/2)) time-offsets=-2,-1,0,1,2 $common1 height-subsample-out=2
  conv-relu-batchnorm-layer name=cnn3 height-in=$((feature_dim/2)) height-out=$((feature_dim/2)) time-offsets=-4,-2,0,2,4 $common2
  conv-relu-batchnorm-layer name=cnn4 height-in=$((feature_dim/2)) height-out=$((feature_dim/2)) time-offsets=-4,-2,0,2,4 $common2
  conv-relu-batchnorm-layer name=cnn5 height-in=$((feature_dim/2)) height-out=$((feature_dim/4)) time-offsets=-4,-2,0,2,4 $common2 height-subsample-out=2
  conv-relu-batchnorm-layer name=cnn6 height-in=$((feature_dim/4)) height-out=$((feature_dim/4)) time-offsets=-4,0,4 $common3
  conv-relu-batchnorm-layer name=cnn7 height-in=$((feature_dim/4)) height-out=$((feature_dim/4)) time-offsets=-4,0,4 $common3
  relu-batchnorm-layer name=tdnn1 input=Append(-4,0,4) dim=$nn_tdnn_dim $tdnn_opts
  relu-batchnorm-layer name=tdnn2 input=Append(-4,0,4) dim=$nn_tdnn_dim $tdnn_opts
  relu-batchnorm-layer name=tdnn3 input=Append(-4,0,4) dim=$nn_tdnn_dim $tdnn_opts

  ## adding the layers for chain branch
  relu-batchnorm-layer name=prefinal-chain dim=$nn_tdnn_dim target-rms=0.5 $tdnn_opts
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
  relu-batchnorm-layer name=prefinal-xent input=tdnn3 dim=$nn_tdnn_dim target-rms=0.5 $tdnn_opts
  output-layer name=output-xent dim=$num_targets learning-rate-factor=$learning_rate_factor max-change=1.5 $output_opts
EOF
fi

steps/nnet3/xconfig_to_configs.py \
  --xconfig-file ${nn_dir}/configs/network.xconfig \
  --config-dir ${nn_dir}/configs/

echo
echo "== $0: $(date): DONE NN TOPOLOGY DESIGN. =="
echo
