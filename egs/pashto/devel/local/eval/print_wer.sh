#!/bin/bash

cfg=$1
set_id=$2

# shellcheck source=config.sh
. ./${cfg}


echo
echo "Done. Date: $(date). Results:"
echo "--------------------------------"
echo -n "# Train data              "
printf "% 10s" " ${data_name}"
echo
echo -n "# Model              "
printf "% 10s" " ${decode_model}"
echo
echo -n "# Decoded data              "
printf "% 10s" " ${decode_data_name}"
echo
echo -n "# LM              "
printf "% 10s" " ${decode_lang_name}"

if [ -d ${exp_dir}/${decode_model}/d_test_${decode_data_name}_${decode_lang_name} ] \
  && [ $set_id = "test" ]; then
    echo
    echo -n "# WER TEST            "
    wer=$(cat ${exp_dir}/${decode_model}/d_test_${decode_data_name}_${decode_lang_name}/scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi

if [ -d ${exp_dir}/${decode_model}/d_train_${decode_data_name}_${decode_lang_name} ] \
  && [ $set_id = "train" ]; then
    echo
    echo -n "# WER TRAIN           "
    wer=$(cat ${exp_dir}/${decode_model}/d_train_${decode_data_name}_${decode_lang_name}/scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
fi
echo
echo
