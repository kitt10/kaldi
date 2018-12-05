#
# == Kaldi processing configuration: Pashto data ==============================
#

# -- KALDI SYSTEM -------------------------------------------------------------
export cmd="run.pl"           # [run.pl|queue.pl]
export LC_ALL=C                 # proper data sorting
# -----------------------------------------------------------------------------

# -- RUN ----------------------------------------------------------------------
export n_jobs=2                # no of parallel jobs
#export script="prepare_data"
#export script="create_lm"
#export script="train_gmm"
#export script="train_nn"
#export script="decode"
export script="kws"
export stage_from=6             # first stage being run
export stage_upto=100           # last stage being run
# -----------------------------------------------------------------------------

# -- DIRS --------------------------------------------------------------------
export data_name=t_20_all
export data_dir=data/${data_name}
export test_data_dir=${data_dir}/test
export train_data_dir=${data_dir}/train
export local_dir=${data_dir}/local
export data_log_dir=${data_dir}/log
export dict_dir=${local_dir}/dict
export images_dir=${local_dir}/images
export bpe_dir=${local_dir}/bpe
export lang_dir=lang
export exp_dir=exp/exp_${data_name}   # exp/exp_<train_data_name>
# -----------------------------------------------------------------------------

# -- DATA ---------------------------------------------------------------------
export raw_data_path="/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/\
database/WordImages"

export feature_dim=40           # height of images
export save_images=false        # save scaled images into the eg's dir?
export us_spks=12               # number of US speakers [0-12]
export af_spks=24               # number of AF speakers [0-370]
export max_samples=10000        # maximal number of samples from one speaker
export first_spknb_test=300     # spks with geq nb will be in the test set
export test_only_set=false      # save only test samples, skip training samples
export invert_colors=true       # black text on white background? [true|false]
export pad_pixels=4             # number of pixels padded to each image side
export subsampling_factor=4
export al_spacing_factor=10     # see get_allowed_lengths.py
export al_coverage_factor=0.01  # see get_allowed_lengths.py
export oov_word="<UNK>"         # dict symbol for the out-of-vocabulary word
export use_bpe=false            # Byte Pair Encoding [true|false]
# -----------------------------------------------------------------------------

# -- LANGUAGE MODEL -----------------------------------------------------------
export lang_name=${data_name}_2g
export lang=${lang_dir}/${lang_name} # lm directory
export lang_order=2             # n-gram model order
export lang_num_sil_states=4
export lang_num_nonsil_states=8
# -----------------------------------------------------------------------------

# -- GMM ----------------------------------------------------------------------
export mono_totgauss=1024
export mono_numiters=40
export deltas_base=mono
export deltas_numleaves=512
export deltas_totgauss=16384
export mllt_base=deltas
export mllt_sliceopts="--left-context=3 --right-context=3"
export mllt_numleaves=2048
export mllt_totgauss=65536
export sat_base=mllt
export sat_numleaves=4200
export sat_totgauss=40000
export ubm_base=sat
export ubm_numgauss=600
export sgmm_base=ubm
export sgmm_numpdfs=5200
export sgmm_totsubstates=12000
# -----------------------------------------------------------------------------

# -- NN -----------------------------------------------------------------------
export nn_base=sat              # [mono|deltas|mllt|sat|nn_sat|<blank>|...]
export nn_id=nn_${nn_base}      # [nn_${nn_base}|nne2e]
export nn_dir=${exp_dir}/${nn_id}
export nn_treedir=${exp_dir}/work/${nn_id}_tree
export nn_latdir=${exp_dir}/work/${nn_id}_lat
export nn_lang_train=${lang}_nn
export nn_numleaves=300
export nn_xent_regularize=0.1
export nn_tdnn_dim=450
export nn_ali_subsampling_factor=$subsampling_factor
export nn_chunk_width=340,300,200,100
export nn_numchunk_per_minibatch=150=64,32/300=32,16/600=16,8/1200=8,4
export nn_numepochs=4
export nn_nj_initial=3
export nn_nj_final=10
export nn_train_stage=-10
export nn_use_gpu=true
# -----------------------------------------------------------------------------

# -- DECODING -----------------------------------------------------------------
export decode_model=sat                 # [mono|deltas|mllt|sat|nn_sat|nne2e]
export decode_data_name=${data_name}    # or another? [tiny|full|t_20_500|...]
export decode_lang_name=${data_name}_2g # lm used for decoding
export decode_test=true                 # decode test data?
export decode_train=false               # decode train data?
export decode_lang=${lang_dir}/${decode_lang_name}
export decode_data=data/${decode_data_name}
# -----------------------------------------------------------------------------

# -- KWS ----------------------------------------------------------------------
export kws_dataset=test
export kws_ref_model_name=nne2e
export kws_model_name=sat
export kws_data=${data_dir}/${kws_dataset}
export kws_ref_model=${exp_dir}/${kws_ref_model_name}
export kws_system=${exp_dir}/${kws_model_name}/d_${kws_dataset}_${data_name}_${lang_name}
export kws_keywords=local/kws/example/keywords.txt
# -----------------------------------------------------------------------------
