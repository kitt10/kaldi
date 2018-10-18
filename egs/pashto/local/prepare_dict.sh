#!/bin/bash

set -e

mkdir -p data/local/dict
local/prepare_dict.py --trs_files data/train/text data/test/text --out_dir data/local/dict/ --oov_word $oov_word