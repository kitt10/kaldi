#!/bin/bash

set -e      # exit if a pipeline returns a non-zero status
stage=0

. ./cmd.sh
. ./path.sh
. ./config.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

# Training settings
mono_totgauss=1024
deltas_numleaves=512
deltas_totgauss=16384
mllt_numleaves=2048
mllt_totgauss=65536

# Decoding toggle
decode_mono_test=true
decode_mono_train=true
decode_tri_test=true
decode_tri_train=true
decode_tri2_test=true
decode_tri2_train=true
lm_affix=$(basename $lang_dir_decode)

# ===== 0: DATA PREPARATION =====
if [ $stage -le 0 ]; then
  echo
  echo "===== STAGE 0: DATA PREPARATION ====="
  echo
  local/prepare_data.sh
fi

# ===== 1: FEATURE EXTRACTION =====
if [ $stage -le 1 ]; then
  echo
  echo "===== STAGE 1: FEATURE EXTRACTION ====="
  echo
  local/make_features.sh
fi

# ===== 2: CORPUS AND DICTIONARY PREPARATION =====
if [ $stage -le 2 ]; then
  echo
  echo "===== STAGE 2: CORPUS AND DICTIONARY PREPARATION ====="
  echo

  echo "== $0: Removing old files..."
  rm -rf $lang_dir
  rm -rf $local_dir/tmp_$(basename $lang_dir)
  rm -rf $local_dir/dict
  rm -rf $local_dir/tmp_bpe
  rm -f $local_dir/bpe.txt
  rm -f $local_dir/corpus.txt

  echo "== $0: Preparing the corpus.."
  local/prepare_corpus.py --trs_files data/train/text data/test/text \
                          --local_dir $local_dir

  if $use_bpe; then
    local/apply_bpe.sh
    text_filename=text_bpe
  else
    text_filename=text
  fi

  echo "== $0: Preparing the dictionary.."

  rm -rf $dict_dir
  mkdir -p $dict_dir

  local/prepare_dict.py --trs_files data/train/$text_filename \
                                    data/test/$text_filename \
                        --dict_dir $dict_dir \
                        --oov_word $oov_word \
                        --use_bpe $use_bpe
fi

# ===== 3: LM FILES PREPARATION =====
if [ $stage -le 3 ]; then
  echo
  echo "===== STAGE 3: LM FILES PREPARATION AND LM CREATION ====="
  echo

  ./create_lm.sh
fi

# ===== 4: TRAIN MONO =====
if [ $stage -le 4 ]; then
  echo
  echo "===== STAGE 5: TRAIN MONO ====="
  echo
  steps/train_mono.sh --nj $n_jobs --cmd $cmd --totgauss $mono_totgauss \
                      --num_iters 40 data/train $lang_dir exp/mono  || exit 1
fi

# ===== 5: DECODE MONO =====
if [ $stage -le 5 ] && ($decode_mono_test || $decode_mono_train); then
  echo
  echo "===== STAGE 5: MONO DECODING ====="
  echo
  echo "== $0: Making mono graph.."
  utils/mkgraph.sh --mono $lang_dir_decode \
                   exp/mono exp/mono/graph || exit 1

  if $decode_mono_test; then
    echo "== $0: Decoding test mono data.."
    rm -rf exp/mono/decode_test_$lm_affix
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/mono/graph data/test exp/mono/decode_test_$lm_affix
  fi
  if $decode_mono_train; then
    echo "== $0: Decoding train mono data.."
    rm -rf exp/mono/decode_train_$lm_affix
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/mono/graph data/train exp/mono/decode_train_$lm_affix
  fi

  local/print_wer.sh exp/mono $lm_affix
fi

# ===== 6: ALIGN AND TRAIN DELTAS (TRI) =====
if [ $stage -le 6 ]; then
  echo
  echo "===== STAGE 6: ALIGNING AND DELTAS TRAINING ====="
  echo
  echo "== $0: Aligning based on mono into mono_ali.."
  steps/align_si.sh --nj $n_jobs --cmd $cmd \
                    data/train $lang_dir exp/mono exp/mono_ali

  echo "== $0: Training deltas based on mono_ali into tri.."
  steps/train_deltas.sh --cmd $cmd $deltas_numleaves $deltas_totgauss \
                        data/train data/lang exp/mono_ali exp/tri
fi

# ===== 7: DECODE TRI =====
if [ $stage -le 7 ] && ($decode_tri_test || $decode_tri_train); then
  echo
  echo "===== STAGE 7: TRI DECODING ====="
  echo
  echo "== $0: Making tri graph.."
  utils/mkgraph.sh $lang_dir_decode exp/tri exp/tri/graph

  if $decode_tri_test; then
    echo "== $0: Decoding test tri data.."
    rm -rf exp/tri/decode_test_$lm_affix
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri/graph data/test exp/tri/decode_test_$lm_affix
  fi
  if $decode_tri_train; then
    echo "== $0: Decoding train tri data.."
    rm -rf exp/tri/decode_train_$lm_affix
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri/graph data/train exp/tri/decode_train_$lm_affix
  fi

  echo "Done. Date: $(date). Results:"
  local/print_wer.sh exp/tri $lm_affix
fi

# ===== 8: ALIGN AND TRAIN MLLT (TRI2) =====
if [ $stage -le 8 ]; then
  echo
  echo "===== STAGE 8: ALIGNING AND LDA MLLT TRAINING ====="
  echo
  echo "== $0: Aligning based on tri into tri_ali.."
  steps/align_si.sh --nj $n_jobs --cmd $cmd \
                    data/train $lang_dir exp/tri exp/tri_ali

  echo "== $0: Training lda mllt based on tri_ali into tri2.."
  steps/train_lda_mllt.sh --cmd $cmd \
                          --splice-opts "--left-context=3 --right-context=3" \
                          $mllt_numleaves $mllt_totgauss \
                          data/train $lang_dir exp/tri_ali exp/tri2
fi

# ===== 9: DECODE TRI2 =====
if [ $stage -le 9 ] && ($decode_tri2_test || $decode_tri2_train); then
  echo
  echo "===== STAGE 9: TRI2 DECODING ====="
  echo
  echo "== $0: Making tri2 graph.."
  utils/mkgraph.sh $lang_dir_decode exp/tri2 exp/tri2/graph

  if $decode_tri2_test; then
    echo "== $0: Decoding test tri2 data.."
    rm -rf exp/tri2/decode_test_$lm_affix
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri2/graph data/test exp/tri2/decode_test_$lm_affix
  fi
  if $decode_tri2_train; then
    echo "== $0: Decoding train tri2 data.."
    rm -rf exp/tri2/decode_train_$lm_affix
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri2/graph data/train exp/tri2/decode_train_$lm_affix
  fi

  local/print_wer.sh exp/tri2 $lm_affix
fi

# ===== 10: ALIGN =====
if [ $stage -le 10 ]; then
  echo
  echo "===== STAGE 10: ALIGNING ====="
  echo
  echo "== $0: Aligning based on tri2 into tri2_ali.."
  steps/align_si.sh --nj $n_jobs --cmd $cmd --use-graphs true \
                    data/train $lang_dir exp/tri2 exp/tri2_ali
fi

echo
echo "===== DONE. ====="
echo
