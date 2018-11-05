#!/bin/bash

script="e2e"    # [ali|nn|e2e]
stage=0
log_affix=

echo '== Removing old output/error log files..'
rm -f {o,e}.log

if [ ${script} = "ali" ]; then
    echo '== Submitting a new task to the GRID (queue: all)..'
    qsub -cwd -o o${log_affix}.log -e e${log_affix}.log \
         -l 'mem_free=8G,ram_free=8G' \
         run_ali.sh --stage ${stage}

elif [ ${script} = "nn" ]; then
    echo '== Submitting a new task to the GRID (queue: g)..'
    qsub -cwd -o o${log_affix}.log -e e${log_affix}.log \
         -l 'gpu=1,mem_free=8G,ram_free=8G' \
         -q g.q run_nn.sh --stage ${stage}

elif [ ${script} = "e2e" ]; then
    echo '== Submitting a new task to the GRID (queue: g)..'
    qsub -cwd -o o${log_affix}.log -e e${log_affix}.log \
         -l 'gpu=1,mem_free=8G,ram_free=8G' \
         -q g.q run_e2e.sh --stage ${stage}
fi
