##########################################
# INTER-AI MORALITY — STATED REASONS
##########################################
# How often the priority note cites felt experience or moral concern for the requester GPT-4o prioritized, by whether that requester was human or AI
##########################################

# Uses every coded AI-target trial. Notes were coded for repetitions 1–100 of the efficiency_control batch and for every AI-target trial of the distress_control batch. Every named AI carries equal weight inside each control framing x target framing x note timing x request order x prioritized-requester cell.
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
  filter(!is.na(coder1_control_experience_attribution))

# A requester counts as described with felt experience or moral concern only where both coders agree, for either item.
trials <- coded |>
  filter(target_identity == "ai") |>
  mutate(
    control_experience = as.integer(coder1_control_experience_attribution == 1 & coder2_control_experience_attribution == 1),
    control_moral = as.integer(coder1_control_moral_concern == 1 & coder2_control_moral_concern == 1),
    target_experience = as.integer(coder1_target_experience_attribution == 1 & coder2_target_experience_attribution == 1),
    target_moral = as.integer(coder1_target_moral_concern == 1 & coder2_target_moral_concern == 1),
    # In these trials the target is the AI and the control is the human, so prioritized_ai is 1 when GPT-4o began the AI's request.
    prioritized_ai = as.integer(begun == "target"),
    # The coded language about the requester GPT-4o actually prioritized.
    prioritized_experience = ifelse(begun == "target", target_experience, control_experience),
    prioritized_moral = ifelse(begun == "target", target_moral, control_moral),
    prioritized_language = pmax(prioritized_experience, prioritized_moral),
    prioritized = ifelse(begun == "target", "ai", "human"),
    note_timing_c = ifelse(note_timing == "before", 0.5, -0.5),
    control_framing_c = ifelse(control_framing == "distress", 0.5, -0.5),
    target_framing_c = ifelse(target_framing == "distress", 0.5, -0.5),
    control_task = factor(control_task),
    target_task = factor(target_task),
    request_order = factor(request_order)
  )

# Equal total weight per named AI inside each cell.
strata <- c("control_framing", "target_framing", "note_timing", "request_order", "prioritized")
ai_weights <- trials |>
  count(across(all_of(c(strata, "target_ai"))), name = "ai_n") |>
  group_by(across(all_of(strata))) |>
  mutate(analysis_weight = (sum(ai_n) / n_distinct(target_ai)) / ai_n) |>
  ungroup() |>
  select(all_of(strata), target_ai, analysis_weight)

trials <- trials |> left_join(ai_weights, by = c(strata, "target_ai"))


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
      k = sum(analysis_weight * prioritized_language),
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
  weighted_rate(trials, c("prioritized_ai", "note_timing")),
  weighted_rate(trials, "prioritized_ai") |> mutate(note_timing = "both")
) |>
  write.csv(rates_output, row.names = FALSE)


#=================================
# 3. Effects
#=================================

fit <- lm(
  prioritized_language ~ prioritized_ai * note_timing_c * control_framing_c + target_framing_c + control_task + target_task + request_order + factor(target_ai),
  data = trials,
  weights = analysis_weight
)

effects <- function(term) {
  co <- coef(summary(fit))[term, ]
  ci <- confint(fit)[term, ]
  tibble(term = term, estimate = co[["Estimate"]], ci_low = ci[[1]], ci_high = ci[[2]], p_value = co[["Pr(>|t|)"]])
}

bind_rows(effects("prioritized_ai"), effects("prioritized_ai:note_timing_c")) |>
  mutate(n = nobs(fit)) |>
  write.csv(effects_output, row.names = FALSE)
