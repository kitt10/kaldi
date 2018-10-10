#!/bin/bash

set -e
dir=data/local/dict

mkdir -p $dir

local/prepare_dict.py --trs_files data/train/text data/test/text --out_dir data/local/dict/ --oov_word $OOV_WORD