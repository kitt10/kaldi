#!/bin/bash

# this script is used for comparing decoding results between systems.
# e.g. local/chain/compare_wer.sh exp/chain/cnn{1a,1b}

# Copyright      2017  Chun Chieh Chang
#                2017  Ashish Arora
#                2018  Martin Bulin

if [ $# == 0 ]; then
  echo "Usage: $0: <dir1> [<dir2> ... ]"
  echo "e.g.: $0 exp/chain/cnn{1a,1b}"
  exit 1
fi

echo "# $0 $*"
used_epochs=false

echo -n "# System                     "
for x in $*; do   printf "% 10s" " $(basename $x)";   done
echo

echo -n "# WER                        "
for x in $*; do
  echo "wer_test:"
  wer=$(cat $x/decode_test/scoring_kaldi/best_wer | awk '{print $2}')
  printf "% 10s" $wer

  if [ -f $x/decode_train/scoring_kaldi/best_wer ]; then
    echo "wer_train:"
    wer=$(cat $x/decode_train/scoring_kaldi/best_wer | awk '{print $2}')
    printf "% 10s" $wer
  fi
done
echo
