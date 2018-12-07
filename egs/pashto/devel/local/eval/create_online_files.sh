#!/bin/bash

cfg=$1

# shellcheck source=config.sh
. ./${cfg}

work_dir=${predict_data_dir}/work
mkdir -p $work_dir ${work_dir}/images

images_scp=${work_dir}/images.scp
images_orig_scp=${work_dir}/images_orig.scp
utt2spk=${work_dir}/utt2spk
spk2utt=${work_dir}/spk2utt
text=${work_dir}/text

#nulling files
cat </dev/null >$images_scp
cat </dev/null >$images_orig_scp
cat </dev/null >$utt2spk
cat </dev/null >$spk2utt
cat </dev/null >$text
rm ${work_dir}/feats.scp 2>/dev/null;
rm ${work_dir}/cmvn.scp  2>/dev/null;

for file in ${predict_data_dir}/*.bmp; do
  id=$(echo $file | sed -e 's/ /_/g')
  echo "$id $file" >>$images_orig_scp
  echo "$id ${work_dir}/images/$(basename $file)" >>$images_scp
  echo "$id $id" >>$utt2spk
  echo "$id $id" >>$spk2utt
  echo "$id NO_TRANSRIPTION" >>$text
done;
