#!/bin/bash

# Copyright 2012  Johns Hopkins University (Author: Guoguo Chen)
# Apache 2.0.


if [ $# -ne 4 ]; then
   echo "Usage: local/generate_example_kws.sh <data-dir> <kws-data-dir> <n_keywords> <min_count>"
   exit 1;
fi

datadir=$1;
kwsdatadir=$2;
n_keywords=$3
min_count=$4
text=$datadir/text;

mkdir -p $kwsdatadir;

# Generate keywords; we generate $n_keywords unigram keywords 
# with at least $min_count counts,

echo "n_keywords: ${n_keywords}, min_count: ${min_count}"

cat $text | perl -e '
  %unigram = ();
  while(<>) {
    chomp;
    @col=split(" ", $_);
    shift @col;
    for($i = 0; $i < @col; $i++) {
      # unigram case
      if (!defined($unigram{$col[$i]})) {
        $unigram{$col[$i]} = 0;
      }
      $unigram{$col[$i]}++;
    }
  }

  $max_count = 100;
  $current = 0;
  $min_c = '${min_count}';
  $total = '${n_keywords}';
  while ($current < $total && $min_c <= $max_count) {
    foreach $x (keys %unigram) {
      if ($unigram{$x} == $min_c) {
        print "$x\n";
        $unigram{$x} = 0;
        $current++;
      }
      if ($current == $total) {
        last;
      }
    }
    $min_c++;
  }
  ' > $kwsdatadir/raw_keywords.txt

echo "Keywords generation succeeded"
