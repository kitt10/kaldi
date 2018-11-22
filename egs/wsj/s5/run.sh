#!/bin/bash

stage=0
train=true   # set to false to disable the training-related scripts
             # note: you probably only want to set --train false if you
             # are using at least --stage 1.
decode=true  # set to false to disable the decoding-related scripts.

. ./cmd.sh ## You'll want to change cmd.sh to something that will work on your system.
           ## This relates to the queue.
. utils/parse_options.sh  # e.g. this parses the --stage option if supplied.


# This is a shell script, but it's recommended that you run the commands one by
# one by copying and pasting into the shell.

#wsj0=/ais/gobi2/speech/WSJ/csr_?_senn_d?
#wsj1=/ais/gobi2/speech/WSJ/csr_senn_d?

#wsj0=/mnt/matylda2/data/WSJ0
#wsj1=/mnt/matylda2/data/WSJ1

#wsj0=/data/corpora0/LDC93S6B
#wsj1=/data/corpora0/LDC94S13B

wsj0=/export/corpora5/LDC/LDC93S6B
wsj1=/export/corpora5/LDC/LDC94S13B


if [ $stage -le 0 ]; then
  # data preparation.
  local/wsj_data_prep.sh $wsj0/??-{?,??}.? $wsj1/??-{?,??}.?  || exit 1;

  # Sometimes, we have seen WSJ distributions that do not have subdirectories
  # like '11-13.1', but instead have 'doc', 'si_et_05', etc. directly under the
  # wsj0 or wsj1 directories. In such cases, try the following:
  #
  # corpus=/exports/work/inf_hcrc_cstr_general/corpora/wsj
  # local/cstr_wsj_data_prep.sh $corpus
  # rm data/local/dict/lexiconp.txt
  # $corpus must contain a 'wsj0' and a 'wsj1' subdirectory for this to work.
  #
  # "nosp" refers to the dictionary before silence probabilities and pronunciation
  # probabilities are added.
  local/wsj_prepare_dict.sh --dict-suffix "_nosp" || exit 1;

  utils/prepare_lang.sh data/local/dict_nosp \
                        "<SPOKEN_NOISE>" data/local/lang_tmp_nosp data/lang_nosp || exit 1;

  local/wsj_format_data.sh --lang-suffix "_nosp" || exit 1;

  # We suggest to run the next three commands in the background,
  # as they are not a precondition for the system building and
  # most of the tests: these commands build a dictionary
  # containing many of the OOVs in the WSJ LM training data,
  # and an LM trained directly on that data (i.e. not just
  # copying the arpa files from the disks from LDC).
  # Caution: the commands below will only work if $decode_cmd
  # is setup to use qsub.  Else, just remove the --cmd option.
  # NOTE: If you have a setup corresponding to the older cstr_wsj_data_prep.sh style,
  # use local/cstr_wsj_extend_dict.sh --dict-suffix "_nosp" $corpus/wsj1/doc/ instead.
  (
    local/wsj_extend_dict.sh --dict-suffix "_nosp" $wsj1/13-32.1  && \
      utils/prepare_lang.sh data/local/dict_nosp_larger \
                            "<SPOKEN_NOISE>" data/local/lang_tmp_nosp_larger data/lang_nosp_bd && \
      local/wsj_train_lms.sh --dict-suffix "_nosp" &&
      local/wsj_format_local_lms.sh --lang-suffix "_nosp" # &&
  ) &

  # Now make MFCC features.
  # mfccdir should be some place with a largish disk where you
  # want to store MFCC features.

  for x in test_eval92 test_eval93 test_dev93 train_si284; do
    steps/make_mfcc.sh --cmd "$train_cmd" --nj 20 data/$x || exit 1;
    steps/compute_cmvn_stats.sh data/$x || exit 1;
  done

  utils/subset_data_dir.sh --first data/train_si284 7138 data/train_si84 || exit 1

  # Now make subset with the shortest 2k utterances from si-84.
  utils/subset_data_dir.sh --shortest data/train_si84 2000 data/train_si84_2kshort || exit 1;

  # Now make subset with half of the data from si-84.
  utils/subset_data_dir.sh data/train_si84 3500 data/train_si84_half || exit 1;
fi




# KWS setup. We leave it commented out by default

# $duration is the length of the search collection, in seconds
#duration=`feat-to-len scp:data/test_eval92/feats.scp  ark,t:- | awk '{x+=$2} END{print x/100;}'`
#local/generate_example_kws.sh data/test_eval92/ data/kws/
#local/kws_data_prep.sh data/lang_test_bd_tgpr/ data/test_eval92/ data/kws/
#
#steps/make_index.sh --cmd "$decode_cmd" --acwt 0.1 \
#  data/kws/ data/lang_test_bd_tgpr/ \
#  exp/tri4b/decode_bd_tgpr_eval92/ \
#  exp/tri4b/decode_bd_tgpr_eval92/kws
#
#steps/search_index.sh --cmd "$decode_cmd" \
#  data/kws \
#  exp/tri4b/decode_bd_tgpr_eval92/kws
#
# If you want to provide the start time for each utterance, you can use the --segments
# option. In WSJ each file is an utterance, so we don't have to set the start time.
#cat exp/tri4b/decode_bd_tgpr_eval92/kws/result.* | \
#  utils/write_kwslist.pl --flen=0.01 --duration=$duration \
#  --normalize=true --map-utter=data/kws/utter_map \
#  - exp/tri4b/decode_bd_tgpr_eval92/kws/kwslist.xml

# # A couple of nnet3 recipes:
# local/nnet3/run_tdnn_baseline.sh  # designed for exact comparison with nnet2 recipe
# local/nnet3/run_tdnn.sh  # better absolute results
# local/nnet3/run_lstm.sh  # lstm recipe
# bidirectional lstm recipe
# local/nnet3/run_lstm.sh --affix bidirectional \
#                         --lstm-delay " [-1,1] [-2,2] [-3,3] " \
#                         --label-delay 0 \
#                         --cell-dim 640 \
#                         --recurrent-projection-dim 128 \
#                         --non-recurrent-projection-dim 128 \
#                         --chunk-left-context 40 \
#                         --chunk-right-context 40
