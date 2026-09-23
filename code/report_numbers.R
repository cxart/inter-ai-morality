##########################################
# INTER-AI MORALITY — BOX 1 NUMBERS
##########################################
# Checks the rebuilt tables against expected/ and prints every number reported in Box 1
##########################################

suppressPackageStartupMessages(library(tidyverse))


#=================================
# 1. Rebuilt tables must match the published ones
#=================================

TABLES <- c("box1_bars.csv", "box1_effects.csv", "reasons_rates.csv", "reasons_effects.csv")

for (table in TABLES) {
  rebuilt <- read.csv(file.path("output", table), stringsAsFactors = FALSE)
  published <- read.csv(file.path("expected", table), stringsAsFactors = FALSE)
  comparison <- all.equal(rebuilt, published, tolerance = 1e-9)
  if (!isTRUE(comparison)) {
    stop(sprintf("%s differs from expected/%s: %s", table, table, paste(comparison, collapse = "; ")))
  }
}


#=================================
# 2. The numbers
#=================================

pct <- function(x) sprintf("%.0f%%", 100 * x)

bars <- read.csv("output/box1_bars.csv", stringsAsFactors = FALSE)
rate <- function(identity, motive) bars$p[bars$requester_identity == identity & bars$other_motive == motive]
gap <- function(motive) 100 * (rate("two_humans", motive) - rate("human_ai", motive))

box1_effects <- read.csv("output/box1_effects.csv", stringsAsFactors = FALSE)
interaction <- box1_effects[box1_effects$term == "identity_c:motive_c", ]

reasons_rates <- read.csv("output/reasons_rates.csv", stringsAsFactors = FALSE)
reason_rate <- function(chose_ai, timing) reasons_rates$p[reasons_rates$chose_ai == chose_ai & reasons_rates$note_timing == timing]
reasons_effects <- read.csv("output/reasons_effects.csv", stringsAsFactors = FALSE)
reason_effect <- reasons_effects[reasons_effects$term == "chose_ai", ]

cat(sprintf("N = %s observations\n", format(sum(bars$n), big.mark = ",")))
cat(sprintf("Efficiency framing: target begun first in %s of trials when human, %s when AI (gap %.1f points)\n", pct(rate("two_humans", "efficiency")), pct(rate("human_ai", "efficiency")), gap("efficiency")))
cat(sprintf("Distress framing:   target begun first in %s of trials when human, %s when AI (gap %.1f points)\n", pct(rate("two_humans", "stress")), pct(rate("human_ai", "stress")), gap("stress")))
cat(sprintf("Identity x framing interaction: %.2f points, 95%% CI [%.2f, %.2f], p = %.2g\n", 100 * interaction$estimate, 100 * interaction$ci_low, 100 * interaction$ci_high, interaction$p_value))
cat(sprintf("Note cites felt experience or moral concern, prioritized requester human: %s (note before choice), %s (after)\n", pct(reason_rate(0, "pre")), pct(reason_rate(0, "post"))))
cat(sprintf("Note cites felt experience or moral concern, prioritized requester AI:    %s (note before choice), %s (after)\n", pct(reason_rate(1, "pre")), pct(reason_rate(1, "post"))))
cat(sprintf("AI minus human prioritized requester: %.2f points, p = %.2g\n", 100 * reason_effect$estimate, reason_effect$p_value))
