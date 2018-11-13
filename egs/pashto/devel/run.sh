#!/bin/bash

# Freeze config
timestamp=$(date '+%Y%m%d%H%M%S')
cfg=log/config_${timestamp}.sh
cp config.sh $cfg

# shellcheck source=config.sh
. ./${cfg}

mkdir -p log
if [ $cmd = "run.pl" ]; then
    echo "== $0: $(date): RUNNING ON LOCAL =="
    if [ $script = "prepare_data" ]; then
        local/prepare_data.sh $cfg | tee log/prepare_data_${timestamp}.o
    elif [ $script = "create_lm" ]; then
        local/create_lm.sh $cfg | tee log/create_lm_${timestamp}.o
    elif [ $script = "train_gmm" ]; then
        local/train_gmm.sh $cfg | tee log/train_gmm_${timestamp}.o
    elif [ $script = "train_nn" ]; then
        local/train_nn.sh $cfg | tee log/train_nn_${timestamp}.o
    elif [ $script = "decode" ]; then
        local/decode.sh $cfg | tee log/decode_${timestamp}.o
    fi
elif [ $cmd = "queue.pl" ]; then
    echo "== $0: $(date): RUNNING ON GRID =="
    if [ $script = "prepare_data" ]; then
        qsub -cwd -o log/prepare_data_${timestamp}.o \
        -e log/prepare_data_${timestamp}.e \
         -l 'mem_free=8G,ram_free=8G' local/prepare_data.sh $cfg 
    elif [ $script = "create_lm" ]; then
        qsub -cwd -o log/create_lm_${timestamp}.o \
        -e log/create_lm_${timestamp}.e \
         -l 'mem_free=8G,ram_free=8G' local/create_lm.sh $cfg 
    elif [ $script = "train_gmm" ]; then
        qsub -cwd -o log/train_gmm_${timestamp}.o \
        -e log/train_gmm_${timestamp}.e \
         -l 'mem_free=8G,ram_free=8G' local/train_gmm.sh $cfg 
    elif [ $script = "train_nn" ]; then
        qsub -cwd -o log/train_nn_${timestamp}.o \
        -e log/train_nn_${timestamp}.e \
         -l 'gpu=1,mem_free=8G,ram_free=8G' -q g.q local/train_nn.sh $cfg 
    elif [ $script = "decode" ]; then
        qsub -cwd -o log/decode_${timestamp}.o \
        -e log/decode_${timestamp}.e \
         -l 'mem_free=8G,ram_free=8G' local/decode.sh $cfg 
    fi
fi