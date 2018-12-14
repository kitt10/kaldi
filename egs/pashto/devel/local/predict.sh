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
  
  if [ ! -d $east_model_dir ]; then
    echo "ERR: Can't find the EAST pretrained model $east_model_dir" && exit 1;
  fi

  for file in final.mdl HCLG.fst words.txt allowed_lengths.txt; do
    if [ ! -f ${predict_model_dir}/${file} ]; then
      echo "ERR: ${predict_model_dir}/${file} expected to exist" && exit 1;
    fi
  done;
  
  for app in nnet3-latgen-faster apply-cmvn lattice-scale; do
    command -v $app >/dev/null 2>&1 || { echo >&2 "ERR: $app not found, is kaldi compiled?"; exit 1; }
  done;
fi

if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: TEXT LOCALIZATION: EAST =="

  rm -rf $predict_work_dir_loc
  mkdir -p $predict_work_dir_loc

  local/text_localization/east/find_bound_boxes.py --corpus_dir=$predict_data_dir \
                                                  --gpu_list=0 \
                                                  --checkpoint_path=local/text_localization/east/trained_model \
                                                  --output_dir=$predict_work_dir_loc
fi

if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: TEXT LOCALIZATION: CUTTING LINES =="

  local/text_localization/cut_lines.py --raw_data_dir=$predict_data_dir \
                                       --work_dir=$predict_work_dir_loc \
                                       --im_mimetype=".bmp"
fi

if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then

  mkdir -p $predict_work_dir_ocr ${predict_work_dir_ocr}/images
  echo
  echo "== $0: $(date): STAGE 3: AUXILIARY FILES AND FEATURE EXTRACTION =="
  local/direct_prediction/make_auxiliary_files.sh $predict_work_dir_loc \
                                                  $predict_work_dir_ocr || exit 1;
  
  local/foreplay/make_features.py --images_orig_file ${predict_work_dir_ocr}/images_orig.scp \
                                  --images_file ${predict_work_dir_ocr}/images.scp \
                                  --allowed_lengths_file ${predict_model_dir}/allowed_lengths.txt \
                                  --feat_dim 40 \
                                  --invert_colors false \
                                  --pad_pixels 10 \
                                  --save_images true \
                                  --fliplr false | \
    copy-feats --compress=true --compression-method=7 \
                ark:- ark,scp:${predict_work_dir_ocr}/images.ark,${predict_work_dir_ocr}/feats.scp || exit 1

  steps/compute_cmvn_stats.sh $predict_work_dir_ocr || exit 1;
  
fi

if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: PREDICTION =="

  nnet3-latgen-faster --frame-subsampling-factor=4 --frames-per-chunk=50 --extra-left-context=0 \
  --extra-right-context=0 --extra-left-context-initial=-1 --extra-right-context-final=-1 \
  --minimize=false --max-active=7000 --min-active=200 --beam=15.0 --lattice-beam=8.0 \
  --acoustic-scale=1.0 --allow-partial=true \
  --word-symbol-table=${predict_model_dir}/words.txt ${predict_model_dir}/final.mdl ${predict_model_dir}/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:${predict_work_dir_ocr}/utt2spk scp:${predict_work_dir_ocr}/cmvn.scp scp:${predict_work_dir_ocr}/feats.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:-  >${predict_work_dir_ocr}/lat.1"
  
  lattice-best-path ark:${predict_work_dir_ocr}/lat.1 ark,t: | \
    int2sym.pl -f 2- ${predict_model_dir}/words.txt > ${predict_results_dir}/predictions.txt
fi

if [ $stage_from -le 5 ] && [ $stage_upto -ge 5 ]; then
  echo
  echo "== $0: $(date): STAGE 5: RESULTS PROCESSING =="

  local/direct_prediction/make_pretty_results.py --results_dir $predict_results_dir \
                                                 --raw_data_dir $predict_data_dir \
                                                 --work_dir_loc $predict_work_dir_loc
fi
