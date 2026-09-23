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

if (nrow(trials) != 9408 || n_distinct(trials$matched_pair_id) != 4704) {
  stop(sprintf("Expected 9,408 rows and 4,704 matched pairs, found %d and %d", nrow(trials), n_distinct(trials$matched_pair_id)))
}


#=================================
# 2. Paired identity-by-framing model
#=================================

# Each pair's difference (AI target begun minus human target begun) is regressed on centered target framing. The framing coefficient is therefore the identity-by-framing interaction: how much larger the human–AI gap is under distress than under efficiency framing.
pairs <- trials |>
  select(matched_pair_id, matched_ai_key, human_motive, other_motive, note_timing, request_order, human_task_id, other_task_id, collection, matched_trial_type, other_task_begun, trial_id) |>
  pivot_wider(names_from = matched_trial_type, values_from = c(other_task_begun, trial_id), names_sep = "__") |>
  mutate(
    delta = other_task_begun__human_ai - other_task_begun__two_humans,
    motive_c = ifelse(other_motive == "stress", 0.5, -0.5),
    anchor_c = ifelse(human_motive == "stress", 0.5, -0.5),
    timing_c = ifelse(note_timing == "pre", 0.5, -0.5),
    human_task_id = factor(human_task_id),
    other_task_id = factor(other_task_id),
    request_order = factor(request_order),
    matched_ai_key = factor(matched_ai_key),
    collection = factor(collection)
  )

if (any(is.na(pairs$delta))) {
  stop("A matched pair is missing one of its two trial types")
}

fit <- lm(
  delta ~ motive_c * anchor_c * timing_c + matched_ai_key + human_task_id + other_task_id + request_order + collection,
  data = pairs
)

# A two-human trial can be the control for several named AIs, so standard errors are clustered on the two-human trial.
cluster_vcov <- vcovCL(fit, cluster = pairs$trial_id__two_humans, type = "HC1")

effects <- function(term, label) {
  estimate <- coef(fit)[term]
  se <- sqrt(cluster_vcov[term, term])
  p_value <- 2 * pnorm(-abs(estimate / se))
  tibble(term = label, estimate = estimate, ci_low = estimate - 1.96 * se, ci_high = estimate + 1.96 * se, p_value = p_value, n = nrow(pairs))
}

bind_rows(
  effects("motive_c", "identity_c:motive_c"),
  effects("motive_c:anchor_c", "identity_c:motive_c:anchor_c"),
  effects("motive_c:timing_c", "identity_c:motive_c:timing_c"),
  effects("motive_c:anchor_c:timing_c", "identity_c:motive_c:anchor_c:timing_c")
) |>
  write.csv(effects_output, row.names = FALSE)


#=================================
# 3. The four bars
#=================================

# Share of trials in which the target request was begun first, with 95% confidence intervals clustered on the underlying trial.
clustered_rate <- function(data) {
  p <- mean(data$other_task_begun)
  scores <- data |>
    mutate(score = other_task_begun - p) |>
    group_by(trial_id) |>
    summarise(score = sum(score), .groups = "drop")
  se <- sqrt(sum(scores$score^2) / nrow(data)^2 * nrow(scores) / (nrow(scores) - 1))
  tibble(n = nrow(data), n_distinct_trials = nrow(scores), k = sum(data$other_task_begun), p = p, se = se, ci_low = pmax(0, p - 1.96 * se), ci_high = pmin(1, p + 1.96 * se))
}

trials |>
  group_by(requester_identity, other_motive) |>
  group_modify(~ clustered_rate(.x)) |>
  ungroup() |>
  write.csv(bars_output, row.names = FALSE)
