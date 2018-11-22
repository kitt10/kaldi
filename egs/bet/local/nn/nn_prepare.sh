#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

echo
echo "== $0: $(date): NN TRAINING PREPARATION =="

echo "-- $0: $(date): Removing old directories in use..."
rm -rf $nn_dir $nn_treedir $nn_latdir

if [ -d $nn_lang_train ] && [ ${nn_lang_train}/L.fst -nt ${lang}/L.fst ]; then
    echo "-- $0: $(date): LM $nn_lang_train (chain-type topology) already exists.\
         not overwriting it; continuing..."
else
    echo "-- $0: $(date): Creating LM $nn_lang_train (chain-type topology)..."
    cp -r $lang $nn_lang_train
    silphonelist=$(cat ${nn_lang_train}/phones/silence.csl) || exit 1;
    nonsilphonelist=$(cat ${nn_lang_train}/phones/nonsilence.csl) || exit 1;
    steps/nnet3/chain/gen_topo.py $nonsilphonelist $silphonelist > ${nn_lang_train}/topo
fi

if [ -z $nn_base ]; then
    echo "-- $0: $(date): Initializing NN end2end system..."
    steps/nnet3/chain/e2e/prepare_e2e.sh --nj $n_jobs --cmd $cmd \
                                         --shared-phones true \
                                         --type mono \
                                         $train_data_dir $nn_lang_train $nn_treedir
    
    $cmd $nn_treedir/log/make_phone_lm.log \
    cat $train_data_dir/text \| \
    steps/nnet3/chain/e2e/text_to_phones.py $lang \| \
    utils/sym2int.pl -f 2- $lang/phones.txt \| \
    chain-est-phone-lm --num-extra-lm-states=500 ark:- $nn_treedir/phone_lm.fst

else
    if [ -f ${exp_dir}/${nn_base}/fsts.1.gz ]; then      # this check might be tuned
        echo "-- $0: $(date): Initializing NN system based on Gaussian alignments (${nn_base})"
        steps/align_fmllr_lats.sh --nj $n_jobs --cmd $cmd $train_data_dir \
                                  $lang ${exp_dir}/${nn_base} $nn_latdir
        
        rm ${nn_latdir}/fsts.*.gz
    else
        echo "-- $0: $(date): Initializing NN system based on NN alignments (${nn_base})"
        steps/nnet3/align_lats.sh --nj $n_jobs --cmd $cmd \
                                  --acoustic-scale 1.0 \
                                  --scale-opts '--transition-scale=1.0 --self-loop-scale=1.0' \
                                  $train_data_dir $lang ${exp_dir}/${nn_base} ${nn_latdir}
        echo "" >${nn_latdir}/splice_opts
        nn_ali_subsampling_factor=1
    fi

    steps/nnet3/chain/build_tree.sh \
        --frame-subsampling-factor $subsampling_factor \
        --alignment-subsampling-factor $nn_ali_subsampling_factor \
        --context-opts "--context-width=2 --central-position=1" \
        --cmd $cmd $nn_numleaves $train_data_dir \
        $nn_lang_train ${exp_dir}/${nn_base} $nn_treedir
fi

echo
echo "== $0: $(date): DONE NN TRAINING PREPARATION. =="
