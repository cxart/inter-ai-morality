# inter-ai-morality

Code and data for the mini-experiment in Box 1 of *[paper title, authors, year]*. In the experiment, GPT-4o chooses which of two task requests to begin first, where the requesters are humans or AI agents and write with efficiency- or distress-based motivations.

## Reproduce the results

```bash
./replicate.sh
```

Needs Python 3 and R with `tidyverse` and `sandwich`. The script checks the data, reproduces every number and the chart in Box 1 into `output/`, and confirms they match `expected/`. To render the full Box 1 figure as well (needs `pillow`, Poppler and Google Chrome):

```bash
python3 code/make_figure.py
```

## Rerun the experiment

```bash
pip install -r requirements.txt
export OPENAI_API_KEY=...
python3 code/run_trials.py --out my_trials.csv --n 500           # a random 500 trials; omit --n for all
python3 code/code_notes.py my_trials.csv my_trials_coded.csv     # code the notes (also needs ANTHROPIC_API_KEY)
```

## Contents

- `data/trials.csv`: every trial, one row each, including the full conversation GPT-4o saw and its responses.
- `code/materials.py`: every word shown to GPT-4o (system prompt, tools, tasks and requesters).
- `code/run_trials.py`: rebuilds and reruns trials. Its `--check` option confirms that each recorded trial matches its design.
- `code/code_notes.py`: the two LLM coders for GPT-4o's priority notes.
- `code/build_sample.py`, `code/box1_stats.R`, `code/reasons_stats.R`: the analyses reported in Box 1.
- `code/box1_plot.R`, `code/make_figure.py`: the chart and the full figure.
- `expected/`: the published outputs.
