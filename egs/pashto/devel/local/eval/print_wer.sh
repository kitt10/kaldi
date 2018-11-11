#!/bin/bash

# this script prints the performance of a system using the given LM

# Copyright      2017  Chun Chieh Chang
#                2017  Ashish Arora
#                2018  Martin Bulin

. ./config.sh

lm_affix=$(basename $decode_lang)

echo
echo "Done. Date: $(date). Results:"
echo "--------------------------------"
echo -n "# Model              "
printf "% 10s" " ${decode_model}"

if [ -d ${exp_dir}/${decode_model}/decode_test_${lm_affix} ] \
  && [ $1 = "test" ]; then
    echo
    echo -n "# WER TEST            "
    wer=$(cat ${exp_dir}/${decode_model}/decode_test_${lm_affix}/scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi

if [ -d ${exp_dir}/${decode_model}/decode_train_${lm_affix} ] \
  && [ $1 = "train" ]; then
    echo
    echo -n "# WER TRAIN           "
    wer=$(cat ${exp_dir}/${decode_model}/decode_train_${lm_affix}/scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi
echo
echo
