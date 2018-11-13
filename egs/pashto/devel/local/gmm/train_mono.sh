#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): TRAIN MONO =="
echo
steps/train_mono.sh --nj $n_jobs --cmd $cmd --totgauss $mono_totgauss \
                    --num_iters $mono_numiters $train_data_dir $lang \
                    ${exp_dir}/mono  || exit 1

echo
echo "== $0: $(date): DONE MONO TRAINING. =="
echo
