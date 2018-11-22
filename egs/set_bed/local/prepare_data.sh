#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

# ===== 1: DATA COLLECTING =====
if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: COLLECTING DATA =="
  local/foreplay/collect_data.sh $cfg
fi

# ===== 2: FEATURE EXTRACTION =====
if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: FEATURE EXTRACTION =="
  local/foreplay/make_features.sh $cfg
fi

# ===== 3: DICTIONARY PREPARATION =====
if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
  echo
  echo "== $0: $(date): STAGE 3: DICTIONARY PREPARATION =="
  local/foreplay/make_dict.sh $cfg
fi

# ===== 4: DATA DIR FIX AND VALIDATION =====
if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: DATA DIR FIX AND VALIDATION =="
  if [ $test_only_set = false ]; then
    local/foreplay/fix_data_dir.sh $train_data_dir
    local/foreplay/validate_data_dir.sh $train_data_dir
  fi
  local/foreplay/fix_data_dir.sh $test_data_dir
  local/foreplay/validate_data_dir.sh $test_data_dir
fi

echo
echo "== $0: $(date): DONE DATA PREPARATIION ($stage_from to $stage_upto). =="
