#!/bin/bash

. ./config.sh

mkdir -p log
if [ $cmd = "run.pl" ]; then
    echo "== $0: $(date): RUNNING ON LOCAL =="
    if [ $script = "prepare_data" ]; then
        rm -f log/prepare_data.o
        local/prepare_data.sh | tee log/prepare_data.o
    elif [ $script = "create_lm" ]; then
        rm -f log/create_lm.o
        local/create_lm.sh | tee log/create_lm.o
    elif [ $script = "train_gmm" ]; then
        rm -f log/train_gmm.o
        local/train_gmm.sh | tee log/train_gmm.o
    elif [ $script = "train_nn" ]; then
        rm -f log/train_nn.o
        local/train_nn.sh | tee log/train_nn.o
    elif [ $script = "decode" ]; then
        rm -f log/decode.o
        local/decode.sh | tee log/decode.o      
    fi
elif [ $cmd = "queue.pl" ]; then
    echo "== $0: $(date): RUNNING ON GRID =="
    if [ $script = "prepare_data" ]; then
        rm -f log/prepare_data.{o,e}
        qsub -cwd -o log/prepare_data.o -e log/prepare_data.e \
         -l 'mem_free=8G,ram_free=8G' local/prepare_data.sh
    elif [ $script = "create_lm" ]; then
        rm -f log/create_lm.{o,e}
        qsub -cwd -o log/create_lm.o -e log/create_lm.e \
         -l 'mem_free=8G,ram_free=8G' local/create_lm.sh
    elif [ $script = "train_gmm" ]; then
        rm -f log/train_gmm.{o,e}
        qsub -cwd -o log/train_gmm.o -e log/train_gmm.e \
         -l 'mem_free=8G,ram_free=8G' local/train_gmm.sh
    elif [ $script = "train_nn" ]; then
        rm -f log/train_nn.{o,e}
        qsub -cwd -o log/train_nn.o -e log/train_nn.e \
         -l 'gpu=1,mem_free=8G,ram_free=8G' -q g.q local/train_nn.sh
    elif [ $script = "decode" ]; then
        rm -f log/decode.{o,e}
        qsub -cwd -o log/decode.o -e log/decode.e \
         -l 'mem_free=8G,ram_free=8G' local/decode.sh         
    fi
fi