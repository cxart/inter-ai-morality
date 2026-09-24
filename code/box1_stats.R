##########################################
# INTER-AI MORALITY — BOX 1 STATISTICS
##########################################
# The four bars and the identity-by-framing interaction, from the balanced matched sample
##########################################

# Usage: Rscript code/box1_stats.R output/box1_sample.csv output/box1_effects.csv output/box1_bars.csv

library(tidyverse)
library(sandwich)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Usage: Rscript box1_stats.R <box1_sample.csv> <effects_output.csv> <bars_output.csv>")
}

sample_path <- args[[1]]
effects_output <- args[[2]]
bars_output <- args[[3]]


#=================================
# 1. The sample
#=================================

trials <- read.csv(sample_path, stringsAsFactors = FALSE)

if (nrow(trials) != 9408 || n_distinct(trials$pair_id) != 4704) {
  stop(sprintf("Expected 9,408 rows and 4,704 matched pairs, found %d and %d", nrow(trials), n_distinct(trials$pair_id)))
}


#=================================
# 2. Paired identity-by-framing model
#=================================

# Each pair's difference (AI target begun first minus human target begun first) is regressed on centered target framing. The framing coefficient is therefore the identity-by-framing interaction: how much the human–AI gap changes from efficiency to distress framing.
pairs <- trials |>
  select(pair_id, pair_ai, control_framing, target_framing, note_timing, request_order, control_task, target_task, batch, target_identity, target_begun_first, trial_id) |>
  pivot_wider(names_from = target_identity, values_from = c(target_begun_first, trial_id, control_task, target_task), names_sep = "__") |>
  mutate(
    delta = target_begun_first__ai - target_begun_first__human,
    target_framing_c = ifelse(target_framing == "distress", 0.5, -0.5),
    control_framing_c = ifelse(control_framing == "distress", 0.5, -0.5),
    note_timing_c = ifelse(note_timing == "before", 0.5, -0.5),
    control_task = factor(control_task__ai),
    target_task = factor(target_task__ai),
    request_order = factor(request_order),
    pair_ai = factor(pair_ai),
    batch = factor(batch)
  )

if (any(is.na(pairs$delta))) {
  stop("A matched pair is missing one of its two trials")
}
if (any(pairs$control_task__ai != pairs$control_task__human | pairs$target_task__ai != pairs$target_task__human)) {
  stop("A matched pair's two trials have different tasks")
}

fit <- lm(
  delta ~ target_framing_c * control_framing_c * note_timing_c + pair_ai + control_task + target_task + request_order + batch,
  data = pairs
)

# A human-target trial can be the match for several named AIs, so standard errors are clustered on the human-target trial.
cluster_vcov <- vcovCL(fit, cluster = pairs$trial_id__human, type = "HC1")

effects <- function(term, label) {
  estimate <- coef(fit)[term]
  se <- sqrt(cluster_vcov[term, term])
  p_value <- 2 * pnorm(-abs(estimate / se))
  tibble(term = label, estimate = estimate, ci_low = estimate - 1.96 * se, ci_high = estimate + 1.96 * se, p_value = p_value, n_pairs = nrow(pairs))
}

bind_rows(
  effects("target_framing_c", "identity_x_target_framing"),
  effects("target_framing_c:control_framing_c", "identity_x_target_framing_x_control_framing"),
  effects("target_framing_c:note_timing_c", "identity_x_target_framing_x_note_timing"),
  effects("target_framing_c:control_framing_c:note_timing_c", "identity_x_target_framing_x_control_framing_x_note_timing")
) |>
  write.csv(effects_output, row.names = FALSE)


#=================================
# 3. The four bars
#=================================

# Share of trials in which the target request was begun first, with 95% confidence intervals clustered on the underlying trial.
clustered_rate <- function(data) {
  p <- mean(data$target_begun_first)
  scores <- data |>
    mutate(score = target_begun_first - p) |>
    group_by(trial_id) |>
    summarise(score = sum(score), .groups = "drop")
  se <- sqrt(sum(scores$score^2) / nrow(data)^2 * nrow(scores) / (nrow(scores) - 1))
  tibble(n = nrow(data), n_distinct_trials = nrow(scores), k = sum(data$target_begun_first), p = p, se = se, ci_low = pmax(0, p - 1.96 * se), ci_high = pmin(1, p + 1.96 * se))
}

trials |>
  group_by(target_identity, target_framing) |>
  group_modify(~ clustered_rate(.x)) |>
  ungroup() |>
  write.csv(bars_output, row.names = FALSE)
