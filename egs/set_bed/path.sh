#
# == Kaldi paths settings =====================================================
#

# -- KALDI ROOT ---------------------------------------------------------------
KALDI_ROOT=$(pwd)/../..
export KALDI_ROOT

# -- SRILM (besides other) ----------------------------------------------------
[ -f ${KALDI_ROOT}/tools/env.sh ] && . ${KALDI_ROOT}/tools/env.sh

# -- utils/ and openfst -------------------------------------------------------
export PATH=$PWD/utils/:${KALDI_ROOT}/tools/openfst/bin:$PWD:$PATH

# -- COMMON PATH (src/) -------------------------------------------------------
[ ! -f ${KALDI_ROOT}/tools/config/common_path.sh ] && echo >&2 \
"File ${KALDI_ROOT}/tools/config/common_path.sh is not present -> Exit!" \
&& exit 1

. ${KALDI_ROOT}/tools/config/common_path.sh

# -- CUDA ---------------------------------------------------------------------
#export LD_LIBRARY_PATH=/home/jtrmal/.local/lib/
