#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): FMLLR ALIGNMENT =="
steps/align_fmllr.sh --nj $n_jobs --cmd $cmd $train_data_dir \
                       $lang ${exp_dir}/sat ${exp_dir}/sat_ali

echo
echo "== $0: $(date): DONE FMLLR ALIGNMENT. =="
