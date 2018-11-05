#!/bin/bash

script="nn_e2e"    # [ali|nn_ali|nn_e2e]
stage=0
log_affix=

echo '== Removing old output/error log files..'
rm -f {o,e}.log

if [ ${script} = "ali" ]; then
    echo '== Submitting a new task to the GRID (queue: all)..'
    qsub -cwd -o o${log_affix}.log -e e${log_affix}.log \
         -l 'mem_free=8G,ram_free=8G' \
         run_ali.sh --stage ${stage}

elif [ ${script} = "nn_ali" ]; then
    echo '== Submitting a new task to the GRID (queue: g)..'
    qsub -cwd -o o${log_affix}.log -e e${log_affix}.log \
         -l 'gpu=1,mem_free=8G,ram_free=8G' \
         -q g.q run_nn_ali.sh --stage ${stage}

elif [ ${script} = "nn_e2e" ]; then
    echo '== Submitting a new task to the GRID (queue: g)..'
    qsub -cwd -o o${log_affix}.log -e e${log_affix}.log \
         -l 'gpu=1,mem_free=8G,ram_free=8G' \
         -q g.q run_nn_e2e.sh --stage ${stage}
fi
