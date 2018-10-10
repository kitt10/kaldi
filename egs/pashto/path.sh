# Defining Kaldi root directory
export KALDI_ROOT=`pwd`/../..

# Setting paths to useful tools
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh

# Data source
export DATA_PATH_TR="/media/kitt/snorlax/data/ocr_pashto/WordImages/US_Final/extractedWords/transcriptions/"
export DATA_PATH_IM="/media/kitt/snorlax/data/ocr_pashto/WordImages/US_Final/extractedWords/words/"

# Speakers to be used
export SPKS="us1 us2 us3 us4 us5 us6 us7 us8 us9 us10 us11 us12"

# Variable needed for proper data sorting
export LC_ALL=C

# Features dimension (images height)
export FEAT_DIM=190

# Unknown (oov) word
export OOV_WORD="<unk>"

# train_lm.sh
export NUM_DEV_SENTENCES=500