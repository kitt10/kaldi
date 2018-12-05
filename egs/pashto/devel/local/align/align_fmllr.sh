#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

if [ -z "$2" ]; then
  d_dir=$train_data_dir
  out_dir=${exp_dir}/sat_ali
else
  d_dir=$2
  out_dir=$3
fi

echo
echo "== $0: $(date): FMLLR ALIGNMENT =="
steps/align_fmllr.sh --nj $n_jobs --cmd $cmd $d_dir \
                       $lang ${exp_dir}/sat $out_dir

echo
echo "== $0: $(date): DONE FMLLR ALIGNMENT. =="
