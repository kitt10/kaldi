#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

mkdir -p $exp_dir ${exp_dir}/work

# ===== 1: NN CHECK ENVIRONMENT =====
if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: NN ENVIRONMENT CHECK =="
  echo
  local/nn/nn_check.sh $cfg
fi

# ===== 2: NN TRAINING PREPARATION =====
if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: NN TRAINING PREPARATION =="
  echo
  local/nn/nn_prepare.sh $cfg
fi

# ===== 3: NN DESIGN TOPOLOGY =====
if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
  echo
  echo "== $0: $(date): STAGE 3: NN DESIGN TOPOLOGY =="
  echo
  local/nn/nn_design.sh $cfg
fi

# ===== 4: NN TRAIN MODEL =====
if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: NN TRAIN MODEL =="
  echo
  if [ -z $nn_base ]; then
    local/nn/nn_train_e2e.sh $cfg
  else
    local/nn/nn_train_chain.sh $cfg
  fi
fi

# ===== 5: NN ALIGN =====
if [ $stage_from -le 5 ] && [ $stage_upto -ge 5 ]; then
  echo
  echo "== $0: $(date): STAGE 5: NN ALIGN =="
  echo
  local/align/align_nn.sh $cfg
fi

echo
echo "== $0: $(date): DONE NN TRAINING ($stage_from to $stage_upto). =="
echo
