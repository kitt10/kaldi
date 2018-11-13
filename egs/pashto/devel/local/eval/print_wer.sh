#!/bin/bash

# this script prints the performance of a system using the given LM

# Copyright      2017  Chun Chieh Chang
#                2017  Ashish Arora
#                2018  Martin Bulin

cfg=$1

# shellcheck source=config.sh
. ./${cfg}


echo
echo "Done. Date: $(date). Results:"
echo "--------------------------------"
echo -n "# Model              "
printf "% 10s" " ${decode_model}"

if [ -d ${exp_dir}/${decode_model}/decode_test_${decode_lang_name} ] \
  && [ $2 = "test" ]; then
    echo
    echo -n "# WER TEST            "
    wer=$(cat ${exp_dir}/${decode_model}/decode_test_${decode_lang_name}/\
     scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi

if [ -d ${exp_dir}/${decode_model}/decode_train_${decode_lang_name} ] \
  && [ $2 = "train" ]; then
    echo
    echo -n "# WER TRAIN           "
    wer=$(cat ${exp_dir}/${decode_model}/decode_train_${decode_lang_name}/\
     scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi
echo
echo
