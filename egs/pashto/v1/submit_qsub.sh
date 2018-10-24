#!/bin/bash

stage=0

# remove old log output/error files
echo '== Removing old output/error log files..'
rm -f {o,e}.log

# submit a new task to the grid
echo '== Submiting a new task to the GRID..'
qsub -cwd -o o.log -e e.log -l 'mem_free=8G,ram_free=8G' run.sh --stage $stage