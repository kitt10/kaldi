#!/bin/bash

set -e -o pipefail

# -- Begin configuration section ----------------------------------------------
stage=0
nj=30
nj_test=10
feature_dim=40
nn_dir=exp/cnn
nn_treedir=exp/work/cnn_tree
nn_latdir=exp/work/cnn_lat
lang_train=data/lang_cnn_train
lang_decode=data/lang
xent_regularize=0.1
tdnn_dim=450
chunk_width=340,300,200,100
numchunk_per_minibatch=150=32,16/300=16,8/600=8,4/1200=4,2
#numchunk_per_minibatch=150=16,8/300=8,4/600=4,2/1200=2,1  # try if training fails
nj_initial=3
nj_final=8
# -- End configuration section ------------------------------------------------

. ./utils/parse_options.sh

. ./path.sh || die "File path.sh expected to exist"
. ./cmd.sh || die "File cmd.sh expected to exist"

set -e -o pipefail
set -o nounset      # Treat unset variables as an error

if [ $stage -le 0 ]; then
    if ! cuda-compiled; then
        cat <<EOF && exit 1
        !!E: This script is intended to be used with GPUs but you have not compiled 
        Kaldi with CUDA. If you want to use GPUs (and have them), go to src/, and 
        configure and make on a machine where "nvcc" is installed.
EOF
    fi

    for f in data/train/feats.scp exp/tri3/ali.1.gz exp/tri3/final.mdl; do
        [ ! -f $f ] && echo "$0: !!E: Expected file $f to exist." && exit 1
    done
fi

if [ $stage -le 1 ]; then
    echo
    echo "== $0: $(date): STAGE 16/1: Creating a training lang =="
    rm -rf $nn_dir $nn_treedir $nn_latdir

    if [ -d $lang_train ] && [ ${lang_train}/L.fst -nt data/lang/L.fst ]; then
        echo "-- $0: $(date): LM $lang_train (chain-type topology) already exists.\
             not overwriting it; continuing..."
    else
        cp -r data/lang $lang_train
        silphonelist=$(cat ${lang_train}/phones/silence.csl) || exit 1;
        nonsilphonelist=$(cat ${lang_train}/phones/nonsilence.csl) || exit 1;
        steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist > ${lang_train}/topo
    fi

    echo "== $0: $(date): STAGE 16/1: Aligning FMLLR lattices =="
    steps/align_fmllr_lats.sh --nj $nj --cmd $cmd data/train \
                            data/lang exp/tri3 $nn_latdir

    rm ${nn_latdir}/fsts.*.gz

    echo "== $0: $(date): STAGE 16/1: Building a tree =="
    steps/nnet3/chain/build_tree.sh \
        --frame-subsampling-factor 4 \
        --alignment-subsampling-factor 4 \
        --context-opts "--context-width=2 --central-position=1" \
        --cmd $cmd 300 data/train \
        $lang_train exp/tri3 $nn_treedir
fi

if [ $stage -le 2 ]; then
    echo
    echo "== $0: $(date): STAGE 16/2: NN topology design =="
    num_targets=$(tree-info ${nn_treedir}/tree | grep num-pdfs | awk '{print $2}')
    cnn_opts="l2-regularize=0.075"
    tdnn_opts="l2-regularize=0.075"
    output_opts="l2-regularize=0.1"
    common1="${cnn_opts} required-time-offsets= height-offsets=-2,-1,0,1,2 num-filters-out=36"
    common2="${cnn_opts} required-time-offsets= height-offsets=-2,-1,0,1,2 num-filters-out=70"
    common3="${cnn_opts} required-time-offsets= height-offsets=-1,0,1 num-filters-out=70"

    mkdir -p ${nn_dir}/configs

    learning_rate_factor=$(echo "print 0.5/${xent_regularize}" | python)
    cat <<EOF > ${nn_dir}/configs/network.xconfig
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


    steps/nnet3/xconfig_to_configs.py \
        --xconfig-file ${nn_dir}/configs/network.xconfig \
        --config-dir ${nn_dir}/configs/
fi

if [ $stage -le 3 ]; then
    echo
    echo "== $0: $(date): STAGE 16/3: NN training =="
    steps/nnet3/chain/train.py \
        --stage -10 \
        --cmd $cmd \
        --feat.cmvn-opts "--norm-means=false --norm-vars=false" \
        --chain.xent-regularize $xent_regularize \
        --chain.leaky-hmm-coefficient 0.1 \
        --chain.l2-regularize 0.00005 \
        --chain.apply-deriv-weights false \
        --chain.lm-opts="--num-extra-lm-states=500" \
        --chain.frame-subsampling-factor 4 \
        --chain.alignment-subsampling-factor 4 \
        --trainer.srand 0 \
        --trainer.max-param-change 2.0 \
        --trainer.num-epochs 4 \
        --trainer.frames-per-iter 1500000 \
        --trainer.optimization.num-jobs-initial $nj_initial \
        --trainer.optimization.num-jobs-final $nj_final \
        --trainer.optimization.initial-effective-lrate 0.001 \
        --trainer.optimization.final-effective-lrate 0.0001 \
        --trainer.optimization.shrink-value 1.0 \
        --trainer.num-chunk-per-minibatch $numchunk_per_minibatch \
        --trainer.optimization.momentum 0.0 \
        --egs.chunk-width $chunk_width \
        --egs.chunk-left-context 0 \
        --egs.chunk-right-context 0 \
        --egs.chunk-left-context-initial 0 \
        --egs.chunk-right-context-final 0 \
        --egs.opts="--frames-overlap-per-eg 0" \
        --cleanup.remove-egs true \
        --use-gpu true \
        --feat-dir data/train \
        --tree-dir $nn_treedir \
        --lat-dir $nn_latdir \
        --dir $nn_dir  || exit 1;
fi

if [ $stage -le 4 ]; then
    utils/mkgraph.sh --self-loop-scale 1.0 \
      $lang_decode ${nn_dir} ${nn_dir}/graph || exit 1;

    rm -rf ${nn_dir}/decode_test

    frames_per_chunk=$(echo $chunk_width | cut -d, -f1)
    steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
      --extra-left-context 0 \
      --extra-right-context 0 \
      --extra-left-context-initial 0 \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj $nj_test --cmd $cmd \
      ${nn_dir}/graph \
      data/test ${nn_dir}/decode_test || exit 1;

    echo
    echo "Done. Date: $(date). Results:"
    echo "--------------------------------"
    echo -n "# Model              "
    printf "% 10s" " ${nn_dir}"
    echo
    echo -n "# WER TEST            "
    wer=$(cat ${nn_dir}/decode_test/scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi
