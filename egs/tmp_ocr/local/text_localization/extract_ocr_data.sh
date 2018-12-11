#!/bin/bash

# Author     2018  Martin Bulin

# Extraction of lines from the images using EAST
# https://github.com/argman/EAST.

set -e

. ./path.sh

corpus_dir=$1

echo
echo "== $0: $(date): Searching the bound boxes for lines using EAST. =="

if [ ! -f ${corpus_dir}/page_001/work/page_001_lines.txt ]; then
    local/text_localization/east/find_bound_boxes.py --corpus_dir=$corpus_dir \
                                                    --gpu_list=0 \
                                                    --checkpoint_path=local/text_localization/east/trained_model
else
    echo "-- page_001_lines.txt found, assuming this work has already been done. Continuing."    
fi

echo
echo "== $0: $(date): Cutting the lines into separate images. =="

if [ ! -f ${corpus_dir}/page_001/page_001_001.jpg ]; then
    local/text_localization/cut_lines.py --corpus_dir=$corpus_dir \
                                         --interactive=false
else
    echo "-- page_001_001.jpg found, assuming this work has already been done. Continuing."    
fi
