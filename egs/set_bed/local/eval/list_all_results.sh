#!/bin/bash

find exp -name "best_wer" | xargs cat  | sort -k2,2g | tee RESULTS
