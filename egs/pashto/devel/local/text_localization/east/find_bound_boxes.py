#!/usr/bin/env python3

import cv2
import time
import math
import os
from collections import OrderedDict
import numpy as np
import tensorflow as tf

import locality_aware_nms as nms_locality
import lanms

tf.app.flags.DEFINE_string('corpus_dir', 'corpus', '')
tf.app.flags.DEFINE_string('gpu_list', '0', '')
tf.app.flags.DEFINE_string('checkpoint_path', 'local/text_localization/east/trained_model/', '')
tf.app.flags.DEFINE_string('output_dir', '', '')
tf.app.flags.DEFINE_bool('no_write_images', False, 'do not write images')

import model
from icdar import restore_rectangle

FLAGS = tf.app.flags.FLAGS

class Frame():
    
    def __init__(self, c):
        self.x0, self.y0 = c[0], c[1]
        self.x1, self.y1 = c[2], c[3]
        self.x2, self.y2 = c[4], c[5]
        self.x3, self.y3 = c[6], c[7]
        self.a = np.mean((c[2:4], c[4:6]), axis=0)
        self.b = np.mean((c[:2], c[6:]), axis=0)
        self.h = abs(self.y1-self.y2)
        self.k = (self.b[1]-self.a[1])/(self.b[0]-self.a[0])
        self.q = self.a[1]-self.k*self.a[0]
        self.id = [self.a[1], self.b[1]]
        self.row = None
        self.cost = 0
        self.next = None

def get_images():
    '''
    find image files in the corpus
    :return: list of files found
    '''
    files = []
    exts = ['bmp']
    for parent, _dirnames, filenames in os.walk(FLAGS.corpus_dir):
        for filename in filenames:
            for ext in exts:
                if filename.endswith(ext):
                    files.append(os.path.join(parent, filename))
                    break
    print('Found {} images'.format(len(files)))
    return sorted(files)


def resize_image(im, max_side_len=2400):
    '''
    resize image to a size multiple of 32 which is required by the network
    :param im: the resized image
    :param max_side_len: limit of max image size to avoid out of memory in gpu
    :return: the resized image and the resize ratio
    '''
    h, w, _ = im.shape

    resize_w = w
    resize_h = h

    # limit the max side
    if max(resize_h, resize_w) > max_side_len:
        ratio = float(max_side_len) / resize_h if resize_h > resize_w else float(max_side_len) / resize_w
    else:
        ratio = 1.
    resize_h = int(resize_h * ratio)
    resize_w = int(resize_w * ratio)

    resize_h = resize_h if resize_h % 32 == 0 else (resize_h // 32 - 1) * 32
    resize_w = resize_w if resize_w % 32 == 0 else (resize_w // 32 - 1) * 32
    im = cv2.resize(im, (int(resize_w), int(resize_h)))

    ratio_h = resize_h / float(h)
    ratio_w = resize_w / float(w)

    return im, (ratio_h, ratio_w)


def detect(score_map, geo_map, timer, score_map_thresh=0.8, box_thresh=0.1, nms_thres=0.2):
    '''
    restore text boxes from score map and geo map
    :param score_map:
    :param geo_map:
    :param timer:
    :param score_map_thresh: threshhold for score map
    :param box_thresh: threshhold for boxes
    :param nms_thres: threshold for nms
    :return:
    '''
    if len(score_map.shape) == 4:
        score_map = score_map[0, :, :, 0]
        geo_map = geo_map[0, :, :, ]
    # filter the score map
    xy_text = np.argwhere(score_map > score_map_thresh)
    # sort the text boxes via the y axis
    xy_text = xy_text[np.argsort(xy_text[:, 0])]
    # restore
    start = time.time()
    text_box_restored = restore_rectangle(xy_text[:, ::-1]*4, geo_map[xy_text[:, 0], xy_text[:, 1], :]) # N*4*2
    print('{} text boxes before nms'.format(text_box_restored.shape[0]))
    boxes = np.zeros((text_box_restored.shape[0], 9), dtype=np.float32)
    boxes[:, :8] = text_box_restored.reshape((-1, 8))
    boxes[:, 8] = score_map[xy_text[:, 0], xy_text[:, 1]]
    timer['restore'] = time.time() - start
    # nms part
    start = time.time()
    # boxes = nms_locality.nms_locality(boxes.astype(np.float64), nms_thres)
    boxes = lanms.merge_quadrangle_n9(boxes.astype('float32'), nms_thres)
    timer['nms'] = time.time() - start

    if boxes.shape[0] == 0:
        return None, timer

    # here we filter some low score boxes by the average score map, this is different from the orginal paper
    for i, box in enumerate(boxes):
        mask = np.zeros_like(score_map, dtype=np.uint8)
        cv2.fillPoly(mask, box[:8].reshape((-1, 4, 2)).astype(np.int32) // 4, 1)
        boxes[i, 8] = cv2.mean(score_map, mask)[0]
    boxes = boxes[boxes[:, 8] > box_thresh]

    return boxes, timer


def sort_poly(p):
    min_axis = np.argmin(np.sum(p, axis=1))
    p = p[[min_axis, (min_axis+1)%4, (min_axis+2)%4, (min_axis+3)%4]]
    if abs(p[0, 0] - p[1, 0]) > abs(p[0, 1] - p[1, 1]):
        return p
    else:
        return p[[0, 3, 2, 1]]


def dst(b1, b2):
    return np.abs(np.mean(b1.id)-np.mean(b2.id))

def main(argv=None):
    import os
    os.environ['CUDA_VISIBLE_DEVICES'] = FLAGS.gpu_list

    with tf.get_default_graph().as_default():
        input_images = tf.placeholder(tf.float32, shape=[None, None, None, 3], name='input_images')
        global_step = tf.get_variable('global_step', [], initializer=tf.constant_initializer(0), trainable=False)

        f_score, f_geometry = model.model(input_images, is_training=False)

        variable_averages = tf.train.ExponentialMovingAverage(0.997, global_step)
        saver = tf.train.Saver(variable_averages.variables_to_restore())

        with tf.Session(config=tf.ConfigProto(allow_soft_placement=True)) as sess:
            ckpt_state = tf.train.get_checkpoint_state(FLAGS.checkpoint_path)
            model_path = os.path.join(FLAGS.checkpoint_path, os.path.basename(ckpt_state.model_checkpoint_path))
            print('Restore from {}'.format(model_path))
            saver.restore(sess, model_path)

            im_fn_list = get_images()
            for im_fn in im_fn_list:
                im = cv2.imread(im_fn)[:, :, ::-1]
                start_time = time.time()
                im_resized, (ratio_h, ratio_w) = resize_image(im)

                timer = {'net': 0, 'restore': 0, 'nms': 0}
                start = time.time()
                score, geometry = sess.run([f_score, f_geometry], feed_dict={input_images: [im_resized]})
                timer['net'] = time.time() - start

                boxes, timer = detect(score_map=score, geo_map=geometry, timer=timer)
                print('{} : net {:.0f}ms, restore {:.0f}ms, nms {:.0f}ms'.format(
                    im_fn, timer['net']*1000, timer['restore']*1000, timer['nms']*1000))

                duration = time.time() - start_time
                print('[timing] {}'.format(duration))

                if boxes is not None:
                    boxes = boxes[:, :8].reshape((-1, 4, 2))
                    boxes[:, :, 0] /= ratio_w
                    boxes[:, :, 1] /= ratio_h

                    ## Connect boxes into lines using the chain map algorithm
                    frames = list()
                    for box in boxes:
                        box = sort_poly(box.astype(np.int32))
                        frames.append(Frame((box[0, 0],   # x0
                                             box[0, 1],   # y0
                                             box[1, 0],   # x1
                                             box[1, 1],   # y1
                                             box[2, 0],   # x2
                                             box[2, 1],   # y2
                                             box[3, 0],   # x3
                                             box[3, 1]))) # y3

                    frames = sorted(frames, key=lambda l:l.y3)  # sort top-down

                    # the chain map
                    tmp = frames[:]
                    frame = tmp[0]
                    while tmp:
                        dsts = [dst(frame, f) for f in tmp]
                        amin = np.argmin(dsts)
                        frame.cost = dsts[amin]
                        frame.next = tmp.pop(amin)
                        frame = frame.next

                    row = 0
                    rows = dict()
                    f = frames[0]
                    while f:
                        row += 1
                        rows[row] = [f]
                        f.row = row
                        f = f.next
                    
                    ## Save to file
                    im_filename = os.path.basename(im_fn)
                    im_dirpath = im_fn.rstrip(im_filename)
                    if FLAGS.output_dir != '':
                        im_dirpath = FLAGS.output_dir
                        
                    res_txt_file_bb = os.path.join(im_dirpath, '{}_bb.txt'.format(im_filename.split('.')[0]))
                    res_txt_file_lines = os.path.join(im_dirpath, '{}_lines.txt'.format(im_filename.split('.')[0]))

                    with open(res_txt_file_bb, 'w') as f:
                        for box in boxes:
                            # to avoid submitting errors
                            box = sort_poly(box.astype(np.int32))
                            if np.linalg.norm(box[0] - box[1]) < 5 or np.linalg.norm(box[3]-box[0]) < 5:
                                continue
                            f.write('{},{},{},{},{},{},{},{}\r\n'.format(
                                box[0, 0], box[0, 1], box[1, 0], box[1, 1], box[2, 0], box[2, 1], box[3, 0], box[3, 1],
                            ))
                            #cv2.polylines(im[:, :, ::-1], [box.astype(np.int32).reshape((-1, 1, 2))], True, color=(255, 255, 0), thickness=1)

                    with open(res_txt_file_lines, 'w') as f:
                        for r, r_frames in rows.items():
                            x_min = min([f.x0 for f in r_frames]+[f.x3 for f in r_frames])
                            x_max = max([f.x1 for f in r_frames]+[f.x2 for f in r_frames])
                            y_min = min([f.y0 for f in r_frames]+[f.y1 for f in r_frames])
                            y_max = max([f.y2 for f in r_frames]+[f.y3 for f in r_frames])
                            c0 = [x_min, y_min]
                            c1 = [x_max, y_min]
                            c2 = [x_max, y_max]
                            c3 = [x_min, y_max]
                            
                            f.write('{},{},{},{}\r\n'.format(
                                c0[0], c0[1], c2[0], c2[1]))
                            cv2.polylines(im[:, :, ::-1], [np.array([c0, c1, c2, c3]).astype(np.int32).reshape((-1, 1, 2))], True, color=(0, 0, 255), thickness=1)
                            cv2.putText(im[:, :, ::-1], str(r), (c0[0]-10, c0[1]-10), cv2.FONT_HERSHEY_SIMPLEX, fontScale=1, color=(0, 0, 255))

                if not FLAGS.no_write_images:                    
                    res_img_file = os.path.join(im_dirpath, '{}_lines.bmp'.format(im_filename.split('.')[0]))
                    cv2.imwrite(res_img_file, im[:, :, ::-1])

if __name__ == '__main__':
    tf.app.run()
