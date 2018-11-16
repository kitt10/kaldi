#### Pashto OCR

This is a Kaldi recipe for the Pashto OCR data - a handwritten text in Arabic (or "Pashto" -  one of the two official languages of Afghanistan). At the moment limited to single isolated words.

##### Database size
The database consists of 1862 different words and two sets of authors (speakers in Kaldi-ASR):
1. US: 12 authors, 13K samples
2. AF: 370 authors, 420K samples

<!--
##### Default experimental setting
* training set: 350 AF authors (411K samples)
* evaluation set: 20 AF authors (22K samples)

##### Results

| Model   | %WER |                                          |
| --------|:----:|:-----------------------------------------|
| mono    |126.58| [ 28654 / 22637, 10176 ins, 144 del, 18334 sub ] |
| tri     | 69.25| [ 15675 / 22637, 4425 ins, 96 del, 11154 sub ] |
| tri2    | 34.50| [ 7810 / 22637, 1106 ins, 69 del, 6635 sub ] |
| tri3    | 40.87| [ 9252 / 22637, 1534 ins, 71 del, 7647 sub ] |
| cnn     |  5.45| [ 1233 / 22637, 3 ins, 13 del, 1217 sub ] |
| e2e cnn |  4.17| [ 944 / 22637, 2 ins, 9 del, 933 sub ] |

* _mono_ : a simple monophone alignement
* _tri_ : _mono_ -> deltas
* _tri2_ : _tri_ -> LDA+MLLT
* _tri3_ : _tri2_ -> SAT+FMLLR
* _cnn_ : _tri3_ -> 7CNN+3TDNN
* _e2e cnn_ : 7CNN+3TDNN with flat start (end2end system)
-->