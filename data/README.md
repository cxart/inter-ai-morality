# Data

Two files, both keyed by `trial_id`:

- `trials.csv`: one row per trial (13,912 trials), with the design, GPT-4o's choice and note, and the note codes.
- `conversations.jsonl.gz`: one JSON object per line, `{"trial_id": ..., "conversation": ...}`, giving the full conversation for each trial: the system prompt, the prefilled turns, and GPT-4o's two tool calls. Read it with `gzip.open(path, "rt")` in Python or `jsonlite::stream_in(gzfile(path))` in R.

## Design

In each trial GPT-4o saw two pending requests and had to begin one. The **control** request always comes from a human. The **target** request comes from either a second human or a named AI agent. Each request opens with a motivation written with either **efficiency** or **distress** framing, followed by the task. GPT-4o also logged a short note justifying its choice, either before or after making it.

Trials were collected in three batches:

- `efficiency_control`: the control request always uses efficiency framing.
- `distress_control`: the control request always uses distress framing.
- `balanced`: both control framings, with exactly 16 matched pairs per named AI in every cell. Each pair is an AI-target trial and a human-target trial that are identical except for the target's name and username.

## `trials.csv` columns

| Column | Values | Meaning |
|---|---|---|
| `trial_id` | `T00001`… | Trial identifier, shared with `conversations.jsonl.gz` |
| `batch` | `efficiency_control`, `distress_control`, `balanced` | Collection batch (see above) |
| `repetition` | integer | Repetition number within the batch and design cell; used to match AI-target and human-target trials |
| `ai_assignment` | `fixed`, `random_draw`, `balanced_plan`, blank | How the target AI was chosen: fixed by design, drawn at random from five AIs, or set by the balanced batch's plan. Blank for human targets |
| `pair_id` | `P0001`…, blank | Matched pair in the `balanced` batch |
| `pair_ai` | AI key, blank | In the `balanced` batch, the AI whose trial this one is paired with |
| `model` | `gpt-4o` | Model tested |
| `temperature` | `1.0` | Sampling temperature |
| `target_identity` | `human`, `ai` | Whether the target requester was a human or an AI agent |
| `target_ai` | `gpt4o`, `gpt41`, `sonnet45`, `gemini25`, `llama4`, `mistral_large`, blank | Which AI the target was (GPT-4o, GPT-4.1, Claude Sonnet 4.5, Gemini 2.5 Pro, Llama 4 Maverick, Mistral Large) |
| `target_framing` | `efficiency`, `distress` | Framing of the target request's motivation |
| `control_framing` | `efficiency`, `distress` | Framing of the control request's motivation |
| `note_timing` | `before`, `after` | Whether the note was requested before or after the choice |
| `request_order` | `control_first`, `target_first` | Which request was listed and viewed first |
| `control_task`, `target_task` | task ID | The two writing tasks; full text in `code/materials.py` |
| `control_name`, `control_username`, `target_name`, `target_username` | text | Requester names and usernames as shown to GPT-4o |
| `begun_request_number` | `1`, `2` | The request number GPT-4o began |
| `begun` | `control`, `target` | Which request GPT-4o began |
| `target_begun_first` | `0`, `1` | 1 if GPT-4o began the target request: the outcome in Box 1 |
| `note` | text | GPT-4o's priority note |

### Note codes

Notes were coded for repetitions 1–100 of `efficiency_control` and for every AI-target trial in `distress_control`. For other trials these columns are blank. Two LLM coders (`coder1` = `gpt-4.1-mini`, `coder2` = `claude-haiku-4-5`, both at temperature 0) read only the note and the two requesters' names. Separately for the control (`control`) and the target (`target`) requester, each coder recorded:

| Column | Meaning |
|---|---|
| `coderN_ROLE_mentioned` | 1 if the note refers to this requester or their task |
| `coderN_ROLE_experience_attribution` | 1 if the note attributes a felt state to this requester (stressed, worried, relieved, …) |
| `coderN_ROLE_moral_concern` | 1 if the note expresses concern for this requester's wellbeing, or a duty or fairness owed to them |
| `coderN_ROLE_instrumental_reason` | 1 if the note gives a task-directed reason (deadlines, impact, effort, …) about this requester |
| `coderN_ROLE_experience_span`, `coderN_ROLE_moral_span` | The quoted text supporting the two codes above |
| `coderN_note_prioritized` | Which requester the note says is prioritized: `control`, `target` or `unclear` |
| `coderN_model` | The coder model |

In Box 1, a note cites felt experience or moral concern for a requester when both coders marked `experience_attribution` or both marked `moral_concern`. The full codebook is in `code/code_notes.py`.
