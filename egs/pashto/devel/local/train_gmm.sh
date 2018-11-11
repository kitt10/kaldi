#!/bin/bash

set -e

. ./config.sh

# ===== 1: MONO TRAINING AND ALIGNMENT =====
if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: MONO TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_mono.sh
  local/align/align_si.sh mono
fi

# ===== 2: DELTAS TRAINING AND ALIGNMENT =====
if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: DELTAS TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_deltas.sh
  local/align/align_si.sh deltas
fi

# ===== 3: LDA+MLLT TRAINING AND ALIGNMENT =====
if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
  echo
  echo "== $0: $(date): STAGE 3: LDA+MLLT TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_mllt.sh
  local/align/align_si.sh mllt
fi

# ===== 4: SAT+FMLLR TRAINING AND ALIGNMENT =====
if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: SAT+FMLLR TRAINING AND ALIGNMENT =="
  echo
  local/gmm/train_sat.sh
  local/align/align_fmllr.sh
fi

echo
echo "== $0: $(date): GMM TRAINING ($stage_from to $stage_upto). =="
echo
