#!/bin/bash

set -e      # exit if a pipeline returns a non-zero status
stage=0

. ./path.sh
. ./cmd.sh
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.

# Variable needed for proper data sorting
export LC_ALL=C

# Number of parallel jobs
export n_jobs=32

# Data source
export data_path="/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/\
database/WordImages"

# Speakers to be used and max number of samples per speaker
export us_spks=12       # 0-12
export af_spks=370      # 0-370
export max_samples=10000  # per speaker (max value)

# Features dimension (image height)
export feature_dim=40

# Invert colors (black text on white bg)? [True|False]
export invert_images=True

# Pad the left and right of the images with 10 white pixels? [True|False]
export pad_images=True

# Subtract random.normal(2, 1) from all pixels?  [True|False]
export add_noise=False

# Directory with the dictionary and the unknown (out-of-vocabulary) word
export dict_dir=data/local/dict
export oov_word="<UNK>"

# The lang and local dirs and the order of the language model (n-gram quantity)
export lang_dir=data/lang
export local_dir=data/local
export lm_order=1

# ===== 0: DATA PREPARATION =====
if [ $stage -le 0 ]; then 
  echo
  echo "===== STAGE 0: DATA PREPARATION ====="
  echo
  local/prepare_data.sh
fi

# ===== 1: FEATURE EXTRACTION =====
if [ $stage -le 1 ]; then 
  echo
  echo "===== STAGE 1: FEATURE EXTRACTION ====="
  echo
  local/make_features.sh
fi

# ===== 2: DICTIONARY PREPARATION =====
if [ $stage -le 2 ]; then 
  echo
  echo "===== STAGE 2: DICTIONARY PREPARATION ====="
  echo
  local/prepare_dict.sh
fi

# ===== 3: LM FILES PREPARATION =====
if [ $stage -le 3 ]; then 
  echo
  echo "===== STAGE 3: LM FILES PREPARATION ====="
  echo
  utils/prepare_lang.sh --num-sil-states 4 --num-nonsil-states 8 \
			$dict_dir $oov_word data/local/lang $lang_dir
fi

# ===== 4: LM CREATION (lm.arpa) =====
if [ $stage -le 4 ]; then 
  echo
  echo "===== STAGE 4: LM CREATION (lm.arpa and G.fst) ====="
  echo
  local/create_lm.sh
fi

# ===== 5: TRAIN MONO =====
if [ $stage -le 5 ]; then 
  echo
  echo "===== STAGE 5: TRAIN MONO ====="
  echo
  steps/train_mono.sh --nj $n_jobs --cmd $cmd data/train $lang_dir exp/mono  || exit 1
fi

if [ $stage -le 6 ]; then
  echo
  echo "===== STAGE 6: MONO DECODING ====="
  echo
  echo "== $0: Making mono graph.."
  utils/mkgraph.sh --mono $lang_dir exp/mono exp/mono/graph || exit 1
  echo "== $0: Decoding test mono data.."
  steps/decode.sh --nj $n_jobs --cmd $cmd exp/mono/graph data/test exp/mono/decode_test
  echo "== $0: Decoding train mono data.."
  steps/decode.sh --nj $n_jobs --cmd $cmd exp/mono/graph data/train exp/mono/decode_train
fi

echo
echo "===== DONE. ====="
echo
