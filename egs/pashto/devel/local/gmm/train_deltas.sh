#!/bin/bash

set -e

. ./config.sh

echo
echo "== $0: $(date): TRAIN DELTAS =="
echo
steps/train_deltas.sh --cmd $cmd $deltas_numleaves $deltas_totgauss \
                        $train_data_dir $lang ${exp_dir}/${deltas_base}_ali \
                        ${exp_dir}/deltas

echo
echo "== $0: $(date): DONE DELTAS TRAINING. =="
echo
