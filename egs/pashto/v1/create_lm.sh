#!/bin/bash

# Creates the language model into $lang_dir (see config.cfg)
# tmp files in $local_dir/tmp_*

. ./cmd.sh
. ./path.sh
. ./config.sh

lang_dir_tmp=$local_dir/tmp_$(basename $lang_dir)
rm -rf $lang_dir_tmp

if $use_bpe; then
  corpus_file=$local_dir/tmp_bpe/corpus_bpe.txt
  lang_sil_prob=0.0
  lang_posdep_phones=false
else
  corpus_file=$local_dir/corpus.txt
  lang_sil_prob=0.5
  lang_posdep_phones=true
fi

echo "== $0: Preparing files for the language model in $lang_dir"
utils/prepare_lang.sh --num-sil-states $lang_num_sil_states \
                        --num-nonsil-states $lang_num_nonsil_states \
                        --sil-prob $lang_sil_prob \
                        --position-dependent-phones $lang_posdep_phones \
                        $dict_dir $oov_word $lang_dir_tmp $lang_dir

if $use_bpe; then
  echo "Adding final optional silence"
  utils/lang/bpe/add_final_optional_silence.sh --final-sil-prob 0.5 $lang_dir
fi

echo
echo "===== LM CREATION (lm.arpa and G.fst) ====="
echo
echo "== $0: MAKING lm.arpa"

ngram-count -order $lm_order \
          -write-vocab $lang_dir_tmp/vocab-full.txt -wbdiscount \
          -text $corpus_file \
          -lm $lang_dir_tmp/lm.arpa

echo "== $0: MAKING G.fst"

arpa2fst --disambig-symbol=#0 \
       --read-symbol-table=$lang_dir/words.txt \
       $lang_dir_tmp/lm.arpa \
       $lang_dir/G.fst