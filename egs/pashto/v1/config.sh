## Pashto data processing configuration

# Variable needed for proper data sorting
export LC_ALL=C

# Number of parallel jobs
export n_jobs=4

# Data source
export data_path="/export/corpora4/ARL_OCR/win/OSI_Pashto_Project_572GB/\
database/WordImages"

# Speakers to be used and max number of samples per speaker
export us_spks=12       # 0-12
export af_spks=24      # 0-370
export max_samples=10000  # per speaker (max value)

# Features dimension (image height)
export feature_dim=32

# Invert colors (black text on white bg)? [True|False]
export invert_images=true

# How many white pixels shall we pad the left and right of the images with?
export pad_images=4

# Subtract random.normal(2, 1) from all pixels?  [True|False]
export add_noise=false

# Allowed lengths of images
export subsampling_factor=4
export spacing_factor=10
export coverage_factor=0.01

# Directory with the dictionary and the unknown (out-of-vocabulary) word
export dict_dir=data/local/dict
export oov_word="<UNK>"

# The lang and local dirs and the order of the language model (n-gram quantity)
export lang_dir=data/lang
export local_dir=data/local
export lm_order=2

# Use BPE (byte pair encoding)
export use_bpe=false

# Decoding language model location
export lang_dir_decode=data/lang
