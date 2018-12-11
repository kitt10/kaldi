#!/bin/bash

# Author     2018  Martin Bulin

# -- Begin configuration section ----------------------------------------------
stage=0
raw_data_dir=predict/data
model_dir=predict/model
results_dir=predict/results
work_dir_loc=predict/work_loc
work_dir_ocr=predict/work_ocr
# -- End configuration section ------------------------------------------------

. ./utils/parse_options.sh || die
. ./path.sh || die

set -e -o pipefail

if [ $stage -le 0 ]; then
  echo
  echo "== $0: $(date): STAGE 0: CHECKING PREREQUISITIES =="
  
  for file in final.mdl HCLG.fst words.txt allowed_lengths.txt; do
    if [ ! -f ${model_dir}/${file} ]; then
      echo "ERR: ${model_dir}/${file} expected to exist" && exit 1;
    fi
  done;
  
  for app in nnet3-latgen-faster apply-cmvn lattice-scale; do
    command -v $app >/dev/null 2>&1 || { echo >&2 "ERR: $app not found, is kaldi compiled?"; exit 1; }
  done;
fi

if [ $stage -le 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: TEXT LOCALIZATION: EAST =="

  rm -rf $work_dir_loc
  mkdir -p $work_dir_loc

  local/text_localization/east/find_bound_boxes.py --corpus_dir=$raw_data_dir \
                                                  --gpu_list=0 \
                                                  --checkpoint_path=local/text_localization/east/trained_model \
                                                  --output_dir=$work_dir_loc
fi

if [ $stage -le 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: TEXT LOCALIZATION: CUTTING LINES =="

  local/text_localization/cut_lines.py --direct_prediction=true
fi

if [ $stage -le 3 ]; then

  mkdir -p $work_dir_ocr ${work_dir_ocr}/images
  echo
  echo "== $0: $(date): STAGE 3: AUXILIARY FILES AND FEATURE EXTRACTION =="
  local/direct_prediction/make_auxiliary_files.sh $work_dir_loc \
                                                  $work_dir_ocr || exit 1;
  
  local/make_features.py --images_orig_file ${work_dir_ocr}/images_orig.scp \
                         --images_file ${work_dir_ocr}/images.scp \
                         --allowed_lengths_file ${model_dir}/allowed_lengths.txt \
                         --feat_dim 40 \
                         --invert_colors false \
                         --pad_pixels 10 \
                         --save_images true \
                         --fliplr false | \
    copy-feats --compress=true --compression-method=7 \
                ark:- ark,scp:${work_dir_ocr}/images.ark,${work_dir_ocr}/feats.scp || exit 1

  steps/compute_cmvn_stats.sh $work_dir_ocr || exit 1;
  
fi

if [ $stage -le 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: PREDICTION =="

  nnet3-latgen-faster --frame-subsampling-factor=4 --frames-per-chunk=50 --extra-left-context=0 \
  --extra-right-context=0 --extra-left-context-initial=-1 --extra-right-context-final=-1 \
  --minimize=false --max-active=7000 --min-active=200 --beam=15.0 --lattice-beam=8.0 \
  --acoustic-scale=1.0 --allow-partial=true \
  --word-symbol-table=${model_dir}/words.txt ${model_dir}/final.mdl ${model_dir}/HCLG.fst \
  "ark,s,cs:apply-cmvn --norm-means=false --norm-vars=false --utt2spk=ark:${work_dir_ocr}/utt2spk scp:${work_dir_ocr}/cmvn.scp scp:${work_dir_ocr}/feats.scp ark:- |" \
  "ark:|lattice-scale --acoustic-scale=10.0 ark:- ark:-  >${work_dir_ocr}/lat.1"
  
  lattice-best-path ark:${work_dir_ocr}/lat.1 ark,t: | \
    int2sym.pl -f 2- ${model_dir}/words.txt > ${results_dir}/predictions.txt
fi

if [ $stage -le 5 ]; then
  echo
  echo "== $0: $(date): STAGE 5: RESULTS PROCESSING =="

  local/direct_prediction/make_pretty_results.py --results_dir $results_dir \
                                                 --raw_data_dir $raw_data_dir \
                                                 --work_dir_loc $work_dir_loc
fi
