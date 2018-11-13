#!/bin/bash

set -e

cfg=$1

# shellcheck source=config.sh
. ./${cfg}
. ./path.sh

mkdir -p ${lang_dir}
mkdir -p ${lang_dir}/work 
lang_tmp=${lang_dir}/work/tmp_${lang_name}
rm -rf ${lang}
rm -rf $lang_tmp

if $use_bpe; then
  corpus_file=${local_dir}/corpus_bpe.txt
  lang_sil_prob=0.0
  lang_posdep_phones=false
else
  corpus_file=${local_dir}/corpus.txt
  lang_sil_prob=0.5
  lang_posdep_phones=true
fi

utils/prepare_lang.sh --num-sil-states $lang_num_sil_states \
                      --num-nonsil-states $lang_num_nonsil_states \
                      --sil-prob $lang_sil_prob \
                      --position-dependent-phones $lang_posdep_phones \
                      $dict_dir $oov_word $lang_tmp $lang

if $use_bpe; then
  utils/lang/bpe/add_final_optional_silence.sh --final-sil-prob 0.5 $lang
fi

echo
echo "== $0: $(date): LM CREATION (lm.arpa and G.fst) =="
echo

ngram-count -order $lang_order \
            -write-vocab ${lang_tmp}/vocab-full.txt -wbdiscount \
            -text $corpus_file \
            -lm ${lang_tmp}/lm.arpa

arpa2fst --disambig-symbol=#0 \
         --read-symbol-table=${lang}/words.txt \
         ${lang_tmp}/lm.arpa \
         ${lang}/G.fst

echo
echo "== $0: $(date): DONE LM CREATION. =="
echo
