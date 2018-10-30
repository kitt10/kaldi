#!/bin/bash

stage=0

# remove old log output/error files
echo '== Removing old output/error log files..'
rm -f {o,e}_nn.log

# submit a new task to the grid
echo '== Submiting a new task to the GRID (queue: g)..'
qsub -cwd -o o_nn.log -e e_nn.log -l 'gpu=1,mem_free=8G,ram_free=8G' \
     -q g.q local/chain/run_cnn_1a.sh --stage $stage
