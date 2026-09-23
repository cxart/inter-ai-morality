#!/usr/bin/env bash
##########################################
# INTER-AI MORALITY — REPRODUCE BOX 1
##########################################
# Rebuilds every number and the chart in Box 1 from data/trials.csv and checks them against expected/
##########################################

set -euo pipefail
cd "$(dirname "$0")"

(cd data && shasum -a 256 -c SHA256SUMS)
python3 code/run_trials.py --check

mkdir -p output
python3 code/build_sample.py data/trials.csv output/box1_sample.csv
Rscript code/box1_stats.R output/box1_sample.csv output/box1_effects.csv output/box1_bars.csv
Rscript code/box1_plot.R output/box1_bars.csv output/box1_plot.png
Rscript code/reasons_stats.R data/trials.csv output/reasons_effects.csv output/reasons_rates.csv

cmp output/box1_sample.csv expected/box1_sample.csv
Rscript code/report_numbers.R
