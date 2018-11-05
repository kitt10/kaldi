#!/bin/bash

# this script prints the performance of a system using the given LM

# Copyright      2017  Chun Chieh Chang
#                2017  Ashish Arora
#                2018  Martin Bulin

if [ $# < 2 ]; then
  echo "Usage: $0: <dir1> <lm_affix>"
  echo "e.g.: $0 exp/nn_e2e lang_n2"
  exit 1
fi

echo
echo "Done. Date: $(date). Results:"
echo "--------------------------------"
echo -n "# System              "
printf "% 10s" " $(basename $1)"
echo

echo -n "# WER TEST            "
wer=$(cat $1/decode_test_$2/scoring_kaldi/best_wer | awk '{print $2}')
printf "% 10s" $wer

if [ -d $1/decode_train_$2 ]; then
  echo
  echo -n "# WER TRAIN           "
  wer=$(cat $1/decode_train_$2/scoring_kaldi/best_wer | awk '{print $2}')
  printf "% 10s" $wer
fi
echo
echo
