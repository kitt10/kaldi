#!/bin/bash

set -e      # exit if a pipeline returns a non-zero status
stage=0

. ./path.sh
. ./cmd.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

# Data preparation
if [ $stage -le 0 ]; then 
  local/prepare_data.sh
fi

mkdir -p data/{train,test}/data
if [ $stage -le 1 ]; then
  echo "$0: Preparing feature files for the test and training data..."
  for f in train test; do
    local/make_features.py --feat-dim $FEAT_DIM --pad true data/$f | \
      copy-feats --compress=true --compression-method=7 \
      ark:- ark,scp:data/$f/data/images.ark,data/$f/feats.scp || exit 1

    steps/compute_cmvn_stats.sh data/$f || exit 1;
  done
fi

if [ $stage -le 2 ]; then
  echo "$0: Preparing dictionary..."
  local/prepare_dict.sh
  echo "$0: Preparing lang..."
  utils/prepare_lang.sh --num-sil-states 4 --num-nonsil-states 8 data/local/dict $OOV_WORD data/lang/temp data/lang
fi

if [ $stage -le 3 ]; then
  echo "$0: Estimating a language model for decoding..."
  local/train_lm.sh
  utils/format_lm.sh data/lang data/local/local_lm/data/arpa/3gram_unpruned.arpa.gz \
                     data/local/dict/lexicon.txt data/lang_test

  echo "$0: Preparing the unk model for open-vocab decoding..."
  utils/lang/make_unk_lm.sh --ngram-order 4 --num-extra-ngrams 7500 \
                            data/local/dict exp/unk_lang_model
  utils/prepare_lang.sh --num-sil-states 4 --num-nonsil-states 8 \
                        --unk-fst exp/unk_lang_model/unk_fst.txt \
                        data/local/dict $OOV_WORD data/lang_unk/temp data/lang_unk
  cp data/lang_test/G.fst data/lang_unk/G.fst
fi

if [ $stage -le 4 ]; then
  steps/train_mono.sh --nj $NJ --cmd $cmd data/train data/lang exp/mono
fi

if [ $stage -le 5 ]; then
  steps/align_si.sh --nj $NJ --cmd $cmd \
    data/train data/lang exp/mono exp/mono_ali
  steps/train_deltas.sh --cmd $cmd 500 20000 \
    data/train data/lang exp/mono_ali exp/tri
fi

if [ $stage -le 6 ]; then
  steps/align_si.sh --nj $NJ --cmd $cmd \
    data/train data/lang exp/tri exp/tri_ali
  steps/train_lda_mllt.sh --cmd $cmd --splice-opts "--left-context=3 --right-context=3" 500 20000 \
    data/train data/lang exp/tri_ali exp/tri2
fi

if [ $stage -le 7 ]; then
  utils/mkgraph.sh --mono data/lang_test exp/mono exp/mono/graph
  steps/decode.sh --nj $NJ --cmd $cmd \
    exp/mono/graph data/test exp/mono/decode_test
fi

if [ $stage -le 8 ]; then
  utils/mkgraph.sh data/lang_test exp/tri exp/tri/graph
  steps/decode.sh --nj $NJ --cmd $cmd \
    exp/tri/graph data/test exp/tri/decode_test
fi

if [ $stage -le 9 ]; then
  utils/mkgraph.sh data/lang_test exp/tri2 exp/tri2/graph
  steps/decode.sh --nj $NJ --cmd $cmd \
    exp/tri2/graph data/test exp/tri2/decode_test
fi

if [ $stage -le 10 ]; then
  steps/align_si.sh --nj $NJ --cmd $cmd --use-graphs true \
    data/train data/lang exp/tri2 exp/tri2_ali
fi

if [ $stage -le 11 ]; then
  local/chain/run_cnn_1a.sh
  #local/chain/run_cnn_1a.sh --stage 3
fi
