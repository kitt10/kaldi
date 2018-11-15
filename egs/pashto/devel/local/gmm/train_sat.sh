#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): TRAIN SAT+FMLLR =="
steps/train_sat.sh --cmd $cmd $sat_numleaves $sat_totgauss \
                    $train_data_dir $lang ${exp_dir}/${sat_base}_ali\
                    ${exp_dir}/sat

echo
echo "== $0: $(date): DONE SAT+FMLLR TRAINING. =="
