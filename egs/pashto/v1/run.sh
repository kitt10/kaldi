#!/bin/bash

# -- Begin configuration section ----------------------------------------------
stage=0
nj=2
# -- End configuration section ------------------------------------------------

. ./utils/parse_options.sh

. ./path.sh || die "File path.sh expected to exist"
. ./cmd.sh || die "File cmd.sh expected to exist"

set -e -o pipefail
set -o nounset      # Treat unset variables as an error

if [ $stage -le 0 ]; then
    local/collect_data.sh
fi

if [ $stage -le 1 ]; then
    local/make_features.sh
fi

if [ $stage -le 2 ]; then
    cut -d' ' -f2- data/train/text data/test/text > data/local/corpus.txt

    rm -rf data/lang data/local/dict 
    mkdir -p data/local/dict
    local/make_dict.py

    local/fix_data_dir.sh data/train
    local/validate_data_dir.sh data/train

    local/fix_data_dir.sh data/test
    local/validate_data_dir.sh data/test
fi

if [ $stage -le 3 ]; then
    local/create_lm.sh
fi

if [ $stage -le 4 ]; then
    steps/train_mono.sh --nj $nj --cmd $cmd --totgauss 1024 \
                        --num_iters 40 data/train data/lang \
                        exp/mono  || exit 1
fi

if [ $stage -le 5 ]; then
    utils/mkgraph.sh data/lang exp/mono exp/mono/graph
    steps/decode.sh --nj $nj --cmd $cmd exp/mono/graph data/test\
                             exp/mono/decode_test
fi

if [ $stage -le 6 ]; then
    steps/align_si.sh --nj $nj --cmd $cmd data/train data/lang \
                      exp/mono exp/mono_ali
fi                  

if [ $stage -le 7 ]; then
    steps/train_deltas.sh --nj $nj --cmd $cmd \
                          512 16384 data/train data/lang exp/mono_ali exp/tri
fi

if [ $stage -le 8 ]; then
    utils/mkgraph.sh data/lang exp/tri exp/tri/graph
    steps/decode.sh --nj $nj --cmd $cmd exp/tri/graph data/test\
                    exp/tri/decode_test
fi

if [ $stage -le 9 ]; then
    steps/align_si.sh --nj $nj --cmd $cmd data/train data/lang \
                      exp/tri exp/tri_ali
fi

if [ $stage -le 10 ]; then
    steps/train_lda_mllt.sh  --cmd $cmd \
                             --splice-opts "--left-context=3 --right-context=3" \
                             2048 65536 data/train data/lang  exp/tri_ali exp/tri2
fi

if [ $stage -le 11 ]; then
    utils/mkgraph.sh data/lang exp/tri2 exp/tri2/graph
    steps/decode.sh --nj $nj --cmd $cmd exp/tri2/graph data/test\
                    exp/tri2/decode_test
fi

if [ $stage -le 12 ]; then
    steps/align_si.sh --nj $nj --cmd $cmd data/train data/lang \
                      exp/tri2 exp/tri2_ali
fi

if [ $stage -le 13 ]; then
    steps/train_sat.sh --nj $nj --cmd $cmd 4200 40000 \
                       data/train data/lang exp/tri2_ali exp/tri3
fi

if [ $stage -le 14 ]; then
    utils/mkgraph.sh data/lang  exp/tri3 exp/tri3/graph
    steps/decode_fmllr.sh --nj $nj --cmd $cmd \
                          exp/tri3/graph data/test exp/tri3/decode_test
fi

if [ $stage -le 15 ]; then
    steps/align_fmllr.sh --nj $nj --cmd $cmd \
                         data/train data/lang exp/tri3 exp/tri3_ali
fi

if [ $stage -le 16 ]; then
    local/chain/run_cnn.sh --stage=0    
fi

echo
echo "RESULTS:"
find exp -name "best_wer" | xargs cat  | sort -k2,2g | tee RESULTS
echo
