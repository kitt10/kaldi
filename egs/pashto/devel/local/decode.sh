#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

# ===== 1: MAKING DECODING GRAPH =====
if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: MAKING DECODING GRAPH =="
  echo "-- model: $decode_model --"
  echo "-- LM: $decode_lang --"
  echo

  if [ -f ${exp_dir}/${decode_model}/fsts.1.gz ]; then      # this check might be tuned
    echo "-- Making graph for a gaussian model --"
    utils/mkgraph.sh \
      $decode_lang ${exp_dir}/${decode_model} \
      ${exp_dir}/${decode_model}/graph || exit 1;
  else
    echo "-- Making graph for a chain model --"
    utils/mkgraph.sh --self-loop-scale 1.0 \
      $decode_lang ${exp_dir}/${decode_model} \
      ${exp_dir}/${decode_model}/graph || exit 1;
  fi
fi

# ===== 2: DECODING TEST DATA =====
if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ] && $decode_test; then
  echo
  echo "== $0: $(date): STAGE 2: DECODING TEST DATA =="
  echo "-- data: $test_data_dir --"
  echo "-- model: $decode_model --"
  echo "-- LM: $decode_lang --"
  echo
  if [ -f ${exp_dir}/${decode_model}/fsts.1.gz ]; then      # this check might be tuned
    echo "-- Decoding a gaussian model --"
    if [ $decode_model = "sat" ]; then
      steps/decode_fmllr.sh --nj $n_jobs --cmd $cmd ${exp_dir}/${decode_model}/graph \
        $test_data_dir ${exp_dir}/${decode_model}/decode_test_${decode_lang_name}
    elif [ $decode_model = "sgmm" ]; then
      steps/decode_sgmm2.sh --nj $n_jobs --cmd $cmd \
        --transform-dir ${exp_dir}/sat/decode_test_${decode_lang_name} \
        ${exp_dir}/${decode_model}/graph $test_data_dir \
        ${exp_dir}/${decode_model}/decode_test_${decode_lang_name}
    else
      steps/decode.sh --nj $n_jobs --cmd $cmd ${exp_dir}/${decode_model}/graph \
        $test_data_dir ${exp_dir}/${decode_model}/decode_test_${decode_lang_name}
    fi
  else
    echo "-- Decoding a chain model --"
    rm -rf ${exp_dir}/${decode_model}/decode_test_${decode_lang_name}

    frames_per_chunk=$(echo $nn_chunk_width | cut -d, -f1)
    steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
      --extra-left-context 0 \
      --extra-right-context 0 \
      --extra-left-context-initial 0 \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj $n_jobs --cmd $cmd \
      ${exp_dir}/${decode_model}/graph \
      $test_data_dir ${exp_dir}/${decode_model}/decode_test_${decode_lang_name} || exit 1;
  fi

  local/eval/print_wer.sh  $cfg test
fi

# ===== 3: DECODING TRAIN DATA =====
if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ] && $decode_train; then
  echo
  echo "== $0: $(date): STAGE 3: DECODING TRAIN DATA =="
  echo "-- data: $train_data_dir --"
  echo "-- model: $decode_model --"
  echo "-- LM: $decode_lang --"
  echo
  if [ -f ${exp_dir}/${decode_model}/fsts.1.gz ]; then      # this check might be tuned
    # gaussian model
    if [ $decode_model = "sat" ]; then
      steps/decode_fmllr.sh --nj $n_jobs --cmd $cmd ${exp_dir}/${decode_model}/graph \
        $train_data_dir ${exp_dir}/${decode_model}/decode_train_${decode_lang_name}
    elif [ $decode_model = "sgmm" ]; then
      steps/decode_sgmm2.sh --nj $n_jobs --cmd $cmd \
        --transform-dir ${exp_dir}/sat/decode_train_${decode_lang_name} \
        ${exp_dir}/${decode_model}/graph $train_data_dir \
        ${exp_dir}/${decode_model}/decode_train_${decode_lang_name}
    else
      steps/decode.sh --nj $n_jobs --cmd $cmd ${exp_dir}/${decode_model}/graph \
        $train_data_dir ${exp_dir}/${decode_model}/decode_train_${decode_lang_name}
    fi
  else
    # chain model
    rm -rf ${exp_dir}/${decode_model}/decode_test_${decode_lang_name}

    frames_per_chunk=$(echo $nn_chunk_width | cut -d, -f1)
    steps/nnet3/decode.sh --acwt 1.0 --post-decode-acwt 10.0 \
      --extra-left-context 0 \
      --extra-right-context 0 \
      --extra-left-context-initial 0 \
      --extra-right-context-final 0 \
      --frames-per-chunk $frames_per_chunk \
      --nj $n_jobs --cmd $cmd \
      ${exp_dir}/${decode_model}/graph \
      $train_data_dir ${exp_dir}/${decode_model}/decode_train_${decode_lang_name} || exit 1;
  fi

  local/eval/print_wer.sh $cfg train
fi

echo
echo "== $0: $(date): DONE DECODING. =="
echo
