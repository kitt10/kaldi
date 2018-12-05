#!/bin/bash
# Copyright (c) 2018, Johns Hopkins University (Yenda Trmal <jtrmal@gmail.com>)
# License: Apache 2.0

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

# Begin configuration section.
flen=0.01
min_lmwt=8
max_lmwt=9              # was originally 14
output=${kws_data}/kws/
# End configuration section

. ./utils/parse_options.sh
. ./path.sh

set -e -o pipefail
set -o nounset                              # Treat unset variables as an error

if [ $stage_from -le 0 ] && [ $stage_upto -ge 0 ]; then
  echo
  echo "== $0: $(date): STAGE 0: CHECKING PREREQUISITIES =="
  
  for d in $kws_data $kws_ref_model $kws_system; do
    if [ ! -d $d ]; then
      echo "ERR: Expected directory $d to exist." && exit 1;
    fi
  done

  mkdir -p $output
fi

if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
  echo
  echo "== $0: $(date): STAGE 1: GENERATING AUXILIARY FILES =="
  echo "== utt.map, images.map, trials, frame_length, keywords.int =="

  utils/data/get_utt2dur.sh $kws_data

  duration=$(cat ${kws_data}/utt2dur | awk '{sum += $2} END{print sum}' )

  echo $duration > ${output}/trials
  echo $flen > ${output}/frame_length

  echo "-- Number of trials: $(cat ${output}/trials)"
  echo "-- Frame lengths: $(cat ${output}/frame_length)"

  cat ${kws_data}/utt2dur | awk 'BEGIN{i=1}; {print $1, i; i+=1;}' > ${output}/utt.map
  cat ${kws_data}/images.scp | awk 'BEGIN{i=1}; {print $1, i; i+=1;}' > ${output}/images.map

  cp ${lang}/words.txt ${output}/words.txt
  cp $kws_keywords ${output}/keywords.txt
  cat ${output}/keywords.txt | \
    local/kws/keywords_to_indices.pl --map-oov 0  ${output}/words.txt | \
    sort -u > ${output}/keywords.int
fi

if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
  echo
  echo "== $0: $(date): STAGE 2: GENERATING THE HITLIST (REFERENCE) =="

  if [ ! -d ${kws_ref_model}_ali_${kws_dataset} ]; then
    echo "-- Aligning searched data based on the reference model"
    if [ $kws_ref_model_name = "sat" ]; then
      local/align/align_fmllr.sh $cfg \
                                 $kws_data \
                                 ${kws_ref_model}_ali_${kws_dataset}
    elif [[ $kws_ref_model_name == "nn"* ]]; then
      local/align/align_nn.sh $cfg \
                              $kws_data \
                              $kws_ref_model \
                              ${kws_ref_model}_ali_${kws_dataset}
    else
      local/align_align_si.sh $cfg \
                              $kws_ref_model_name \
                              $kws_data \
                              $kws_ref_model \
                              ${kws_ref_model}_ali_${kws_dataset}
    fi
  else
    echo "-- Searched data already aligned in ${kws_ref_model}_ali_${kws_dataset}. OK."
  fi

  echo "-- Creating the hitlist"
  local/kws/create_hitlist.sh $kws_data $lang \
                              ${lang_dir}/work/tmp_${lang_name} \
                              ${kws_ref_model}_ali_${kws_dataset} $output
fi

if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
  echo
  echo "== $0: $(date): STAGE 3: GENERATING THE KEYWORDS FSTS =="

  local/kws/compile_keywords.sh $output $lang $output/tmp.2
  cp ${output}/tmp.2/keywords.fsts ${output}/keywords.fsts
fi

if [ $stage_from -le 4 ] && [ $stage_upto -ge 4 ]; then
  echo
  echo "== $0: $(date): STAGE 4: MAKING THE INDEX (INDICES $min_lmwt to $max_lmwt) =="

  for lmwt in $(seq $min_lmwt $max_lmwt) ; do
    steps/make_index.sh --cmd $cmd --lmwt $lmwt --acwt 1.0 \
      --frame-subsampling-factor $subsampling_factor \
      $output $lang $kws_system ${kws_system}/kws_indices_${lmwt}
  done
fi

if [ $stage_from -le 5 ] && [ $stage_upto -ge 5 ]; then
  echo
  echo "== $0: $(date): STAGE 5: SEARCHING, NORMALIZING, SCORING =="

  local/kws/search.sh --cmd $cmd --min-lmwt $min_lmwt --max-lmwt $max_lmwt \
    --indices-dir ${kws_system}/kws_indices --skip-indexing true \
    $lang $kws_data $kws_system
fi

echo "Done"
