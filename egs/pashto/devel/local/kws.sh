#!/bin/bash

set -e

. ./path.sh
cfg=$1

# shellcheck source=config.sh
. ./${cfg}

if [ $stage_from -le 0 ] && [ $stage_upto -ge 0 ]; then
    echo
    echo " == $0: $(date): KWS Preparation == "
    duration=$(feat-to-len scp:${test_data_dir}/feats.scp  ark,t:- | awk '{x+=$2} END{print x/100;}')
    echo "Duration [s]: ${duration}"
    local/kws/kws_generate_example.sh $test_data_dir data/us/kws 2 2
    local/kws/kws_data_prep.sh $lang $test_data_dir data/us/kws
fi

if [ $stage_from -le 1 ] && [ $stage_upto -ge 1 ]; then
    echo
    echo " == $0: $(date): Making index == "
    steps/make_index.sh --cmd $cmd --acwt 0.1 \
                        --frame_subsampling_factor $subsampling_factor \
                        data/us/kws $lang \
                        exp/exp_us/sat/d_test_us_us_2g \
                        exp/exp_us/sat/d_test_us_us_2g/kws
fi

if [ $stage_from -le 2 ] && [ $stage_upto -ge 2 ]; then
    echo
    echo " == $0: $(date): Searching index == "
    steps/search_index.sh --cmd $cmd \
                          --frame_subsampling_factor $subsampling_factor \
                          data/us/kws \
                          exp/exp_us/sat/d_test_us_us_2g/kws
fi

if [ $stage_from -le 3 ] && [ $stage_upto -ge 3 ]; then
    echo
    echo " == $0: $(date): Processing results == "
    for i in $(seq 1 $n_jobs); do 
        zcat exp/exp_us/sat/d_test_us_us_2g/kws/result.${i}.gz \
             > exp/exp_us/sat/d_test_us_us_2g/kws/result.${i}.txt 
    done
    cat exp/exp_us/sat/d_test_us_us_2g/kws/result.*.txt | \
      utils/write_kwslist.pl --flen=0.01 --duration=$duration \
                             --normalize=true --map-utter=data/us/kws/utter_map \
                             - exp/exp_us/sat/d_test_us_us_2g/kws/kwslist.xml
fi