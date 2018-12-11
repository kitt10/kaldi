#!/bin/bash

work_dir_loc=$1
work_dir_ocr=$2

images_scp=${work_dir_ocr}/images.scp
images_orig_scp=${work_dir_ocr}/images_orig.scp
utt2spk=${work_dir_ocr}/utt2spk
spk2utt=${work_dir_ocr}/spk2utt
text=${work_dir_ocr}/text

#nulling files
cat </dev/null >$images_scp
cat </dev/null >$images_orig_scp
cat </dev/null >$utt2spk
cat </dev/null >$spk2utt
cat </dev/null >$text
rm ${work_dir_ocr}/feats.scp 2>/dev/null;
rm ${work_dir_ocr}/cmvn.scp  2>/dev/null;

for spk_dir in ${work_dir_loc}/*/; do
  for im_line in ${spk_dir}*.jpg; do
    im_basename=$(basename $im_line)
    id=$(echo $im_basename | sed -e s/.jpg$//)
    echo "$id $im_line" >>$images_orig_scp
    echo "$id ${work_dir_ocr}/images/$(basename $im_line)" >>$images_scp
    echo "$id $id" >>$utt2spk
    echo "$id $id" >>$spk2utt
    echo "$id NO_TRANSRIPTION" >>$text
  done;
done;