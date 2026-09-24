##########################################
# INTER-AI MORALITY — BOX 1 ANALYSIS SAMPLE
##########################################
# Selects the balanced, matched sample of trials that Box 1's behavioral result is computed from
##########################################

# Every AI-target trial in the sample is paired with a human-target trial from the same cell (control framing x target framing x note timing x request order) and repetition, so the two differ only in whether the target requester is an AI.
#
# The efficiency_control and distress_control batches have unequal numbers of trials per named AI. For each cell and named AI, the script takes the 33 highest-numbered repetitions that have a human-target trial at the same repetition; 33 is the largest number available in every cell. One human-target trial can therefore serve as the match for several named AIs, and the analysis clusters on it. In these batches the target AI was either fixed by design or drawn at random from a pool; if both produced the same AI at the same repetition, the fixed trial is used. The balanced batch contributes all of its pairs, 16 per named AI and cell. Selection uses repetition numbers only, never outcomes.
#
# Usage: python code/build_sample.py data/trials.csv output/box1_sample.csv

import argparse
import csv
import sys
from collections import Counter, defaultdict
from pathlib import Path

csv.field_size_limit(sys.maxsize)


AI_KEYS = ["gpt4o", "gpt41", "sonnet45", "gemini25", "llama4", "mistral_large"]
CONTROL_BATCHES = ["efficiency_control", "distress_control"]
PER_AI_FROM_CONTROL_BATCHES = 33
ASSIGNMENT_PREFERENCE = {"fixed": 0, "random_draw": 1}
OUTPUT_FIELDS = [
    "pair_id", "pair_ai", "trial_id", "batch", "target_identity", "target_ai",
    "control_framing", "target_framing", "note_timing", "request_order",
    "control_task", "target_task", "target_begun_first",
]


#=================================
# 1. Input rows
#=================================

def cell(row):
    return (row["control_framing"], row["target_framing"], row["note_timing"], row["request_order"])


def sample_row(row, pair_id, pair_ai):
    return {**{field: row[field] for field in OUTPUT_FIELDS if field not in ("pair_id", "pair_ai")}, "pair_id": pair_id, "pair_ai": pair_ai}


#=================================
# 2. Matching within the two control batches
#=================================

# For one named AI in one cell: its AI-target trials at repetitions that also have a human-target trial.
def candidates_for(rows, ai, human_repetitions):
    by_repetition = {}
    for row in rows:
        if row["target_identity"] != "ai" or row["target_ai"] != ai:
            continue
        repetition = int(row["repetition"])
        if repetition not in human_repetitions:
            continue
        current = by_repetition.get(repetition)
        if current is None or ASSIGNMENT_PREFERENCE[row["ai_assignment"]] < ASSIGNMENT_PREFERENCE[current["ai_assignment"]]:
            by_repetition[repetition] = row
    return by_repetition


def select_cell(rows):
    humans = {int(row["repetition"]): row for row in rows if row["target_identity"] == "human"}
    if len(humans) != sum(row["target_identity"] == "human" for row in rows):
        raise ValueError("Two human-target trials share a repetition in one cell")

    candidates = {ai: candidates_for(rows, ai, set(humans)) for ai in AI_KEYS}
    if any(len(candidates[ai]) < PER_AI_FROM_CONTROL_BATCHES for ai in AI_KEYS):
        raise ValueError(f"Not enough matched repetitions in cell: { {ai: len(candidates[ai]) for ai in AI_KEYS} }")

    selected = []
    for ai in AI_KEYS:
        for repetition in sorted(candidates[ai], reverse=True)[:PER_AI_FROM_CONTROL_BATCHES]:
            ai_row = candidates[ai][repetition]
            pair_id = "|".join([ai_row["batch"], *cell(ai_row), ai, f"{repetition:03d}"])
            selected.append(sample_row(ai_row, pair_id, ai))
            selected.append(sample_row(humans[repetition], pair_id, ai))
    return selected


#=================================
# 3. The combined sample and its checks
#=================================

def build_sample(trials_csv):
    with open(trials_csv, newline="", encoding="utf-8") as f:
        trials = list(csv.DictReader(f))

    sample = []
    for batch in CONTROL_BATCHES:
        by_cell = defaultdict(list)
        for row in trials:
            if row["batch"] == batch:
                by_cell[cell(row)].append(row)
        for crossed_cell in sorted(by_cell):
            sample.extend(select_cell(by_cell[crossed_cell]))

    for row in trials:
        if row["batch"] == "balanced":
            sample.append(sample_row(row, row["pair_id"], row["pair_ai"]))

    pairs = defaultdict(list)
    for row in sample:
        pairs[row["pair_id"]].append(row)
    if len(sample) != 9408 or len(pairs) != 4704:
        raise ValueError(f"Expected 9,408 rows and 4,704 pairs, found {len(sample)} and {len(pairs)}")
    if any(len(rows) != 2 or {row["target_identity"] for row in rows} != {"ai", "human"} for rows in pairs.values()):
        raise ValueError("The sample has an incomplete matched pair")
    ai_cells = Counter((*cell(row), row["pair_ai"], row["target_identity"]) for row in sample)
    if set(ai_cells.values()) != {49}:
        raise ValueError(f"Not every named AI has 49 pairs in every cell: {set(ai_cells.values())}")
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
