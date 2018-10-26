#!/bin/bash

stage=0

# remove old log output/error files
echo '== Removing old output/error log files..'
rm -f {o,e}_ali.log

# submit a new task to the grid
echo '== Submiting a new task to the GRID (queue: all)..'
qsub -cwd -o o_ali.log -e e_ali.log -l 'mem_free=8G,ram_free=8G' run_ali.sh --stage $stage

