#!/bin/bash

script="nn_e2e"    # [ali|nn_ali|nn_e2e]
stage=0

if [ ${script} = "ali" ]; then
    echo '== Removing old output/error log files..'
    rm -f {o,e}_ali.log

    echo '== Submitting a new task to the GRID (queue: all)..'
    qsub -cwd -o o_ali.log -e e_ali.log \
         -l 'mem_free=8G,ram_free=8G' \
         run_ali.sh --stage ${stage}

elif [ ${script} = "nn_ali" ]; then
    echo '== Removing old output/error log files..'
    rm -f {o,e}_nn_ali.log

    echo '== Submitting a new task to the GRID (queue: g)..'
    qsub -cwd -o o_nn_ali.log -e e_nn_ali.log \
         -l 'gpu=1,mem_free=8G,ram_free=8G' \
         -q g.q run_nn_ali.sh --stage ${stage}

elif [ ${script} = "nn_e2e" ]; then
    echo '== Removing old output/error log files..'
    rm -f {o,e}_nn_e2e.log

    echo '== Submitting a new task to the GRID (queue: g)..'
    qsub -cwd -o o_nn_e2e.log -e e_nn_e2e.log \
         -l 'gpu=1,mem_free=8G,ram_free=8G' \
         -q g.q run_nn_e2e.sh --stage ${stage}
fi
