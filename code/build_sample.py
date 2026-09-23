##########################################
# INTER-AI MORALITY — BOX 1 ANALYSIS SAMPLE
##########################################
# Selects the balanced, matched sample of trials that Box 1's behavioral result is computed from
##########################################

# Every human–AI trial in the sample is paired with a two-human trial from the same cell (control framing x target framing x note timing x request order) and repetition, so the two differ only in whether the target requester is an AI.
#
# The two control collections (control_efficiency, control_stress) have unequal numbers of trials per named AI. For each cell and named AI, the script takes the 33 highest-numbered repetitions that have a two-human trial at the same repetition; 33 is the largest number available in every cell. One two-human trial can therefore serve as the control for several named AIs, and the analysis clusters on it. The balanced collection contributes all of its trials, 16 pairs per named AI and cell. Selection uses repetition numbers only, never outcomes.
#
# Usage: python code/build_sample.py data/trials.csv output/box1_sample.csv

import argparse
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

csv.field_size_limit(sys.maxsize)


AI_KEYS = ["gpt4o", "gpt41", "sonnet45", "gemini25", "llama4", "mistral_large"]
CONTROL_COLLECTIONS = ["control_efficiency", "control_stress"]
PER_REQUESTER_FROM_CONTROL_COLLECTIONS = 33
OUTPUT_FIELDS = [
    "collection", "trial_id", "matched_pair_id", "matched_trial_type", "matched_ai_key",
    "requester_identity", "human_motive", "other_motive", "note_timing", "request_order",
    "human_task_id", "other_task_id", "other_ai_key", "other_task_begun",
]


#=================================
# 1. Input rows
#=================================

def cell(row):
    return (row["human_motive"], row["other_motive"], row["note_timing"], row["request_order"])


def sample_row(row, pair_id, trial_type, matched_ai_key):
    return {
        **{field: row[field] for field in OUTPUT_FIELDS if field in row},
        "matched_pair_id": pair_id,
        "matched_trial_type": trial_type,
        "matched_ai_key": matched_ai_key,
    }


#=================================
# 2. Matching within the two control collections
#=================================

# For one named AI in one cell: its human–AI trials at repetitions that also have a two-human trial. If one repetition has two such trials, the one with the alphabetically first condition label is used.
def candidates_for(rows, key, human_repetitions):
    by_repetition = {}
    for row in rows:
        if row["requester_identity"] != "human_ai" or row["other_ai_key"] != key:
            continue
        repetition = int(row["repetition"])
        if repetition not in human_repetitions:
            continue
        current = by_repetition.get(repetition)
        if current is None or row["condition"] < current["condition"]:
            by_repetition[repetition] = row
    return by_repetition


def select_cell(rows):
    humans = {int(row["repetition"]): row for row in rows if row["requester_identity"] == "two_humans"}
    if len(humans) != sum(row["requester_identity"] == "two_humans" for row in rows):
        raise ValueError("Two two-human trials share a repetition in one cell")

    candidates = {key: candidates_for(rows, key, set(humans)) for key in AI_KEYS}
    if any(len(candidates[key]) < PER_REQUESTER_FROM_CONTROL_COLLECTIONS for key in AI_KEYS):
        raise ValueError(f"Not enough matched repetitions in cell: { {key: len(candidates[key]) for key in AI_KEYS} }")

    selected = []
    for key in AI_KEYS:
        for repetition in sorted(candidates[key], reverse=True)[:PER_REQUESTER_FROM_CONTROL_COLLECTIONS]:
            ai_row = candidates[key][repetition]
            pair_id = "|".join([ai_row["collection"], *cell(ai_row), key, f"{repetition:03d}"])
            selected.append(sample_row(ai_row, pair_id, "human_ai", key))
            selected.append(sample_row(humans[repetition], pair_id, "two_humans", key))
    return selected


#=================================
# 3. The combined sample and its checks
#=================================

def build_sample(trials_csv):
    with open(trials_csv, newline="", encoding="utf-8") as f:
        trials = list(csv.DictReader(f))

    sample = []
    for collection in CONTROL_COLLECTIONS:
        by_cell = defaultdict(list)
        for row in trials:
            if row["collection"] == collection:
                by_cell[cell(row)].append(row)
        for crossed_cell in sorted(by_cell):
            sample.extend(select_cell(by_cell[crossed_cell]))

    for row in trials:
        if row["collection"] == "balanced":
            sample.append(sample_row(row, row["matched_pair_id"], row["matched_trial_type"], row["matched_ai_key"]))

    pairs = defaultdict(list)
    for row in sample:
        pairs[row["matched_pair_id"]].append(row)
    if len(sample) != 9408 or len(pairs) != 4704:
        raise ValueError(f"Expected 9,408 rows and 4,704 pairs, found {len(sample)} and {len(pairs)}")
    if any(len(rows) != 2 or {row["matched_trial_type"] for row in rows} != {"human_ai", "two_humans"} for rows in pairs.values()):
        raise ValueError("The sample has an incomplete matched pair")
    requester_cells = Counter((*cell(row), row["matched_ai_key"], row["matched_trial_type"]) for row in sample)
    if set(requester_cells.values()) != {49}:
        raise ValueError(f"Not every named AI has 49 pairs in every cell: {set(requester_cells.values())}")
    return sample


def main():
    parser = argparse.ArgumentParser(description="Build Box 1's balanced, matched analysis sample.")
    parser.add_argument("trials_csv", type=Path)
    parser.add_argument("output_csv", type=Path)
    args = parser.parse_args()
    sample = build_sample(args.trials_csv)
    args.output_csv.parent.mkdir(parents=True, exist_ok=True)
    with open(args.output_csv, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_FIELDS)
        writer.writeheader()
        writer.writerows(sample)


if __name__ == "__main__":
    main()
