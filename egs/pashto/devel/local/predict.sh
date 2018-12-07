#!/bin/bash

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

set -e -o pipefail
set -o nounset

if [ $stage_from -le 0 ] && [ $stage_upto -ge 0 ]; then
  echo
  echo "== $0: $(date): STAGE 0: CHECKING PREREQUISITIES =="
  
  for file in final.mdl HCLG.fst words.txt allowed_lengths.txt; do
    if [ ! -f $predict_model_dir/$file ]; then
      echo "ERR: $predict_model_dir/$file expected to exist" && exit 1;
    fi
  done;
  
  for app in nnet3-latgen-faster apply-cmvn lattice-scale; do
    command -v $app >/dev/null 2>&1 || { echo >&2 "ERR: $app not found, is kaldi compiled?"; exit 1; }
  done;
fi

if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: AUXILIARY FILES AND FEATURE EXTRACTION =="
  local/eval/create_online_files.sh $cfg || exit 1;

  local/foreplay/make_features.py --images_orig_file ${predict_data_dir}/work/images_orig.scp \
                                  --images_file ${predict_data_dir}/work/images.scp \
                                  --allowed_lengths_file ${predict_model_dir}/allowed_lengths.txt \
                                  --feat_dim $feature_dim \
                                  --invert_colors $invert_colors \
                                  --pad_pixels $pad_pixels \
                                  --save_images false \
                                  --fliplr true | \
    copy-feats --compress=true --compression-method=7 \
                ark:- ark,scp:${predict_data_dir}/work/images.ark,${predict_data_dir}/work/feats.scp || exit 1

  steps/compute_cmvn_stats.sh ${predict_data_dir}/work || exit 1;
fi

if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 2: PREDICTION =="

  nnet3-latgen-faster --frame-subsampling-factor=$subsampling_factor --frames-per-chunk=50 --extra-left-context=0 \
  --extra-right-context=0 --extra-left-context-initial=-1 --extra-right-context-final=-1 \
  --minimize=false --max-active=7000 --min-active=200 --beam=15.0 --lattice-beam=8.0 \
  --acoustic-scale=1.0 --allow-partial=true \
  --word-symbol-table=${predict_model_dir}/words.txt ${predict_model_dir}/final.mdl ${predict_model_dir}/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:${predict_data_dir}/work/utt2spk scp:${predict_data_dir}/work/cmvn.scp scp:${predict_data_dir}/work/feats.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:-  >${predict_data_dir}/work/lat.1"
  
  lattice-best-path ark:${predict_data_dir}/work/lat.1 ark,t: | \
    int2sym.pl -f 2- ${predict_model_dir}/words.txt > ${predict_results_dir}/predictions.txt
fi
