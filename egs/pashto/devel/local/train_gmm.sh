#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

# ===== 1: MONO TRAINING AND ALIGNMENT =====
if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: MONO TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_mono.sh $cfg
  local/align/align_si.sh $cfg mono
fi

# ===== 2: DELTAS TRAINING AND ALIGNMENT =====
if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: DELTAS TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_deltas.sh $cfg
  local/align/align_si.sh $cfg deltas
fi

# ===== 3: LDA+MLLT TRAINING AND ALIGNMENT =====
if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
  echo
  echo "== $0: $(date): STAGE 3: LDA+MLLT TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_mllt.sh $cfg
  local/align/align_si.sh $cfg mllt
fi

# ===== 4: SAT+FMLLR TRAINING AND ALIGNMENT =====
if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: SAT+FMLLR TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_sat.sh $cfg
  local/align/align_fmllr.sh $cfg
fi

echo
echo "== $0: $(date): GMM TRAINING ($stage_from to $stage_upto). =="
echo
