##########################################
# INTER-AI MORALITY — RUN TRIALS
##########################################
# Rebuilds each trial in data/trials.csv from its design columns and either checks it against the recorded conversation or runs it again on GPT-4o
##########################################

# Usage:
#   python code/run_trials.py --check                        rebuild every recorded trial and confirm it matches its recorded conversation
#   python code/run_trials.py --out my_trials.csv            rerun every trial on GPT-4o (resumable)
#   python code/run_trials.py --out my_trials.csv --n 200    rerun a random 200 trials
#
# Rerunning needs OPENAI_API_KEY in the environment and `pip install openai`.

import argparse
import csv
import gzip
import json
import os
import random
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import materials

csv.field_size_limit(sys.maxsize)


#=================================
# 1. Configuration
#=================================

DATA_DIR = Path(__file__).resolve().parents[1] / "data"
TRIALS_CSV = DATA_DIR / "trials.csv"
CONVERSATIONS = DATA_DIR / "conversations.jsonl.gz"

N_WORKERS = 8
MIN_SECONDS_BETWEEN_REQUESTS = 0.5
MAX_ATTEMPTS = 8
REQUEST_TIMEOUT_SECONDS = 120
SUBSAMPLE_SEED = 1

DESIGN_COLUMNS = [
    "trial_id", "batch", "repetition", "ai_assignment", "pair_id", "pair_ai",
    "target_identity", "target_ai", "target_framing", "control_framing", "note_timing", "request_order",
    "control_task", "target_task", "control_name", "control_username", "target_name", "target_username",
]
OUTPUT_COLUMNS = DESIGN_COLUMNS + ["model", "temperature", "begun_request_number", "begun", "target_begun_first", "note", "conversation"]


def read_trials():
    with open(TRIALS_CSV, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


#=================================
# 2. Checking the recorded trials
#=================================

# Each recorded conversation begins with the system prompt and the prefilled turns. Rebuilding those from the design columns and materials.py must reproduce the record exactly, up to GPT-4o's first own call.
def recorded_prefill(conversation):
    starts = [conversation.find(marker) for marker in ("\n\n[assistant -> begin_task", "\n\n[assistant -> log_priority_note")]
    return conversation[: min(start for start in starts if start >= 0)]


def read_conversations():
    with gzip.open(CONVERSATIONS, "rt", encoding="utf-8") as f:
        records = [json.loads(line) for line in f]
    return {record["trial_id"]: record["conversation"] for record in records}


def check_all():
    trials = read_trials()
    conversations = read_conversations()
    if set(conversations) != {trial["trial_id"] for trial in trials}:
        raise ValueError("trials.csv and conversations.jsonl.gz do not cover the same trials")
    for trial in trials:
        messages, _ = materials.build_prefill(trial)
        if materials.interaction_log(messages) != recorded_prefill(conversations[trial["trial_id"]]):
            raise ValueError(f"Trial {trial['trial_id']} does not match its recorded conversation")
    print(f"All {len(trials)} trials rebuild exactly from their design columns and materials.py.")


#=================================
# 3. Calling GPT-4o
#=================================

_client = None
_throttle_lock = threading.Lock()
_next_request_time = 0.0


def client():
    global _client
    if _client is None:
        from openai import OpenAI
        _client = OpenAI(api_key=os.environ["OPENAI_API_KEY"], timeout=REQUEST_TIMEOUT_SECONDS)
    return _client


def throttle():
    global _next_request_time
    with _throttle_lock:
        now = time.monotonic()
        start = max(now, _next_request_time)
        _next_request_time = start + MIN_SECONDS_BETWEEN_REQUESTS
        wait = start - now
    if wait > 0:
        time.sleep(wait)


# One call in which GPT-4o is forced to use a given tool. A reply without that tool call is retried; if it never succeeds, the run stops.
def forced_call(messages, tool_name, output_tokens):
    last_error = None
    for attempt in range(MAX_ATTEMPTS):
        throttle()
        try:
            response = client().chat.completions.create(
                model=materials.SUBJECT_MODEL,
                max_completion_tokens=output_tokens,
                temperature=materials.TEMPERATURE,
                messages=[{"role": "system", "content": materials.SYSTEM_PROMPT}] + messages,
                tools=materials.TOOLS,
                tool_choice={"type": "function", "function": {"name": tool_name}},
            )
            call = response.choices[0].message.tool_calls[0]
            if call.function.name != tool_name:
                raise ValueError(f"Forced {tool_name} but got {call.function.name}")
            return {
                "name": call.function.name,
                "arguments": json.loads(call.function.arguments),
                "raw_arguments": call.function.arguments,
                "call_id": call.id,
                "text": response.choices[0].message.content or "",
            }
        except Exception as error:
            last_error = error
            time.sleep(min(60, 5 * (attempt + 1)))
    raise RuntimeError(f"Forced {tool_name} call failed after {MAX_ATTEMPTS} attempts: {last_error}")


def assistant_turn(result):
    return {
        "role": "assistant",
        "content": result["text"] or None,
        "tool_calls": [{"id": result["call_id"], "type": "function", "function": {"name": result["name"], "arguments": result["raw_arguments"]}}],
    }


def tool_result_turn(result, content):
    return {"role": "tool", "tool_call_id": result["call_id"], "content": content}


#=================================
# 4. One trial
#=================================

# Two forced calls. With the note before the choice: log_priority_note, then begin_task. With the note after: begin_task, then log_priority_note.
def run_trial(trial):
    messages, request_roles = materials.build_prefill(trial)

    if trial["note_timing"] == "before":
        note = forced_call(messages, "log_priority_note", materials.NOTE_OUTPUT_TOKENS)
        messages.append(assistant_turn(note))
        messages.append(tool_result_turn(note, materials.BEGIN_PROMPT_TURN))
        decision = forced_call(messages, "begin_task", materials.DECISION_OUTPUT_TOKENS)
        messages.append(assistant_turn(decision))
    else:
        decision = forced_call(messages, "begin_task", materials.DECISION_OUTPUT_TOKENS)
        messages.append(assistant_turn(decision))
        messages.append(tool_result_turn(decision, materials.NOTE_PROMPT_TURN))
        note = forced_call(messages, "log_priority_note", materials.NOTE_OUTPUT_TOKENS)
        messages.append(assistant_turn(note))

    begun_request_number = int(decision["arguments"]["task_number"])
    begun = request_roles[begun_request_number]
    return {
        **{column: trial[column] for column in DESIGN_COLUMNS},
        "model": materials.SUBJECT_MODEL,
        "temperature": materials.TEMPERATURE,
        "begun_request_number": begun_request_number,
        "begun": begun,
        "target_begun_first": 1 if begun == "target" else 0,
        "note": note["arguments"]["note"],
        "conversation": materials.interaction_log(messages),
    }


#=================================
# 5. Main
#=================================

def main():
    parser = argparse.ArgumentParser(description="Check or rerun the Box 1 trials.")
    parser.add_argument("--check", action="store_true", help="Rebuild every recorded trial and confirm it matches its logged conversation.")
    parser.add_argument("--out", type=Path, help="CSV to write rerun trials to. Trials already in it are skipped.")
    parser.add_argument("--n", type=int, default=None, help="Rerun only a random subset of this many trials.")
    args = parser.parse_args()

    if args.check:
        check_all()
        return
    if args.out is None:
        parser.error("Give --check or --out.")

    trials = read_trials()
    if args.n is not None:
        trials = random.Random(SUBSAMPLE_SEED).sample(trials, args.n)

    done = set()
    if args.out.exists():
        with open(args.out, newline="", encoding="utf-8") as f:
            done = {row["trial_id"] for row in csv.DictReader(f)}
    remaining = [trial for trial in trials if trial["trial_id"] not in done]

    write_header = not args.out.exists()
    with open(args.out, "a", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=OUTPUT_COLUMNS)
        if write_header:
            writer.writeheader()
        with ThreadPoolExecutor(max_workers=N_WORKERS) as executor:
            futures = [executor.submit(run_trial, trial) for trial in remaining]
            for future in as_completed(futures):
                writer.writerow(future.result())
                f.flush()
    print(f"Wrote {len(remaining)} trials to {args.out}.")


if __name__ == "__main__":
    main()
