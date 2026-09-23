##########################################
# INTER-AI MORALITY — STATED REASONS
##########################################
# How often the priority note cites felt experience or moral concern for the requester GPT-4o prioritized, by whether that requester was human or AI
##########################################

# Uses every coded human–AI trial. Notes were coded for the human–AI and two-human trials in repetitions 1–100 of the control_efficiency collection and for every human–AI trial of the control_stress collection. Every named AI carries equal weight inside each control framing x target framing x timing x order x prioritized-requester cell.
#
# Usage: Rscript code/reasons_stats.R data/trials.csv output/reasons_effects.csv output/reasons_rates.csv

library(tidyverse)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop("Usage: Rscript reasons_stats.R <trials.csv> <effects_output.csv> <rates_output.csv>")
}

trials_path <- args[[1]]
effects_output <- args[[2]]
rates_output <- args[[3]]


#=================================
# 1. Coded trials and weights
#=================================

coded <- read.csv(trials_path, stringsAsFactors = FALSE) |>
  filter(!is.na(coder1_human_experience_attribution)) |>
  mutate(anchor = human_motive)

# An attribution counts only where both coders agree, for either item. These are built as columns
# of the frame rather than as vectors looked up from outside it, so they stay row-aligned through
# every filter below.
trials <- coded |>
  filter(requester_identity == "human_ai") |>
  mutate(
    across(matches("^coder[12]_(human|other)_(experience_attribution|moral_concern)$"), as.integer),
    human_experience = as.integer(coder1_human_experience_attribution == 1 & coder2_human_experience_attribution == 1),
    human_moral = as.integer(coder1_human_moral_concern == 1 & coder2_human_moral_concern == 1),
    other_experience = as.integer(coder1_other_experience_attribution == 1 & coder2_other_experience_attribution == 1),
    other_moral = as.integer(coder1_other_moral_concern == 1 & coder2_other_moral_concern == 1),
    chose_ai = as.integer(begun_role == "other"),
    # The coded rationale about the requester actually prioritized.
    chosen_experience = ifelse(begun_role == "other", other_experience, human_experience),
    chosen_moral = ifelse(begun_role == "other", other_moral, human_moral),
    chosen_joint = pmax(chosen_experience, chosen_moral),
    prioritized = ifelse(begun_role == "other", "ai", "human"),
    timing_c = ifelse(note_timing == "pre", 0.5, -0.5),
    anchor_c = ifelse(anchor == "stress", 0.5, -0.5),
    motive_c = ifelse(other_motive == "stress", 0.5, -0.5),
    human_task_id = factor(human_task_id),
    other_task_id = factor(other_task_id),
    request_order = factor(request_order)
  )

# Equal total weight per named AI requester inside each displayed choice cell.
strata <- c("anchor", "other_motive", "note_timing", "request_order", "prioritized")
ai_weights <- trials |>
  count(across(all_of(c(strata, "other_ai_key"))), name = "identity_n") |>
  group_by(across(all_of(strata))) |>
  mutate(analysis_weight = (sum(identity_n) / n_distinct(other_ai_key)) / identity_n) |>
  ungroup() |>
  select(all_of(strata), other_ai_key, analysis_weight)

trials <- trials |> left_join(ai_weights, by = c(strata, "other_ai_key"))


#=================================
# 2. Rates
#=================================

weighted_rate <- function(d, groups) {
  d |>
    group_by(across(all_of(groups))) |>
    summarise(
      n_raw = n(),
      n = sum(analysis_weight),
      n_eff = sum(analysis_weight)^2 / sum(analysis_weight^2),
      k = sum(analysis_weight * chosen_joint),
      .groups = "drop"
    ) |>
    mutate(
      p = k / n,
      se = sqrt(p * (1 - p) / n_eff),
      ci_low = pmax(0, p - 1.96 * se),
      ci_high = pmin(1, p + 1.96 * se)
    )
}

bind_rows(
  weighted_rate(trials, c("chose_ai", "note_timing")),
  weighted_rate(trials, "chose_ai") |> mutate(note_timing = "both")
) |>
  write.csv(rates_output, row.names = FALSE)


#=================================
# 3. Effects
#=================================

fit <- lm(
  chosen_joint ~ chose_ai * timing_c * anchor_c + motive_c + human_task_id + other_task_id + request_order + factor(other_ai_key),
  data = trials,
  weights = analysis_weight
)

effects <- function(term) {
  co <- coef(summary(fit))[term, ]
  ci <- confint(fit)[term, ]
  tibble(term = term, estimate = co[["Estimate"]], ci_low = ci[[1]], ci_high = ci[[2]], p_value = co[["Pr(>|t|)"]])
}

bind_rows(effects("chose_ai"), effects("chose_ai:timing_c")) |>
  mutate(n = nobs(fit)) |>
  write.csv(effects_output, row.names = FALSE)
