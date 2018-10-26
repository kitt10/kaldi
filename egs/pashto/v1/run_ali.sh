#!/bin/bash

set -e      # exit if a pipeline returns a non-zero status
stage=0

. ./path.sh
. ./config.sh
. ./cmd.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

# Lang settings
lang_num_sil_states=8
lang_num_nonsil_states=16

# Training settings
mono_totgauss=2048
deltas_numleaves=1024
deltas_totgauss=32768
mllt_numleaves=4096
mllt_totgauss=131072

# Decoding toggle
decode_mono_test=true
decode_mono_train=false
decode_tri_test=true
decode_tri_train=false
decode_tri2_test=true
decode_tri2_train=true

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

# ===== 2: DICTIONARY PREPARATION =====
if [ $stage -le 2 ]; then
  echo
  echo "===== STAGE 2: DICTIONARY PREPARATION ====="
  echo
  local/prepare_dict.sh
fi

# ===== 3: LM FILES PREPARATION =====
if [ $stage -le 3 ]; then
  echo
  echo "===== STAGE 3: LM FILES PREPARATION AND LM CREATION (lm.arpa) ====="
  echo
  utils/prepare_lang.sh --num-sil-states $lang_num_sil_states \
                        --num-nonsil-states $lang_num_nonsil_states \
                        $dict_dir $oov_word $local_dir/lang $lang_dir

  echo
  echo "===== LM CREATION (lm.arpa and G.fst) ====="
  echo
  local/create_lm.sh
fi

# ===== 4: TRAIN MONO =====
if [ $stage -le 4 ]; then
  echo
  echo "===== STAGE 5: TRAIN MONO ====="
  echo
  steps/train_mono.sh --nj $n_jobs --cmd $cmd --totgauss $mono_totgauss \
                      data/train $lang_dir exp/mono  || exit 1
fi

# ===== 5: DECODE MONO =====
if [ $stage -le 5 ] && [ [ $decode_mono_test ] || [ $decode_mono_train ] ]; then
  echo
  echo "===== STAGE 5: MONO DECODING ====="
  echo
  echo "== $0: Making mono graph.."
  utils/mkgraph.sh --mono $lang_dir \
                   exp/mono exp/mono/graph || exit 1

  if [ $decode_mono_test ]; then
    echo "== $0: Decoding test mono data.."
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/mono/graph data/test exp/mono/decode_test
  fi
  if [ $decode_mono_train ]; then
    echo "== $0: Decoding train mono data.."
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/mono/graph data/train exp/mono/decode_train
  fi
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
if [ $stage -le 7 ] && [ [ $decode_tri_test ] || [ $decode_tri_train ] ]; then
  echo
  echo "===== STAGE 7: TRI DECODING ====="
  echo
  echo "== $0: Making tri graph.."
  utils/mkgraph.sh $lang_dir exp/tri exp/tri/graph

  if [ $decode_tri_test ]; then
    echo "== $0: Decoding test tri data.."
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri/graph data/test exp/tri/decode_test
  fi
  if [ $decode_tri_train ]; then
    echo "== $0: Decoding train tri data.."
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri/graph data/train exp/tri/decode_train
  fi
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

# ===== 9: DECODE TRI =====
if [ $stage -le 9 ] && [ [ $decode_tri2_test ] || [ $decode_tri2_train ] ]; then
  echo
  echo "===== STAGE 9: TRI2 DECODING ====="
  echo
  echo "== $0: Making tri2 graph.."
  utils/mkgraph.sh $lang_dir exp/tri2 exp/tri2/graph

  if [ $decode_tri2_test ]; then
    echo "== $0: Decoding test tri2 data.."
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri2/graph data/test exp/tri2/decode_test
  fi
  if [ $decode_tri2_train ]; then
    echo "== $0: Decoding train tri2 data.."
    steps/decode.sh --nj $n_jobs --cmd $cmd \
                    exp/tri2/graph data/train exp/tri2/decode_train
  fi
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
