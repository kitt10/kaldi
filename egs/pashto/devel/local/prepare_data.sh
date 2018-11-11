#!/bin/bash

set -e

. ./config.sh

# ===== 1: DATA COLLECTING =====
if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: COLLECTING DATA =="
  echo
  local/foreplay/collect_data.sh
fi

# ===== 2: FEATURE EXTRACTION =====
if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: FEATURE EXTRACTION =="
  echo
  local/foreplay/make_features.sh
fi

# ===== 3: DICTIONARY PREPARATION =====
if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
  echo
  echo "== $0: $(date): STAGE 3: DICTIONARY PREPARATION =="
  echo
  local/foreplay/make_dict.sh
fi

# ===== 4: DATA DIR FIX AND VALIDATION =====
if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: DATA DIR FIX AND VALIDATION =="
  echo
  local/foreplay/fix_data_dir.sh $train_data_dir
  local/foreplay/fix_data_dir.sh $test_data_dir
  local/foreplay/validate_data_dir.sh $train_data_dir
  local/foreplay/validate_data_dir.sh $test_data_dir
fi

echo
echo "== $0: $(date): DONE DATA PREPARATIION ($stage_from to $stage_upto). =="
echo
