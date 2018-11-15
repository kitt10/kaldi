#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

echo
echo "== $0: $(date): TRAIN DELTAS =="
steps/train_deltas.sh --cmd $cmd $deltas_numleaves $deltas_totgauss \
                        $train_data_dir $lang ${exp_dir}/${deltas_base}_ali \
                        ${exp_dir}/deltas

echo
echo "== $0: $(date): DONE DELTAS TRAINING. =="
