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
rate <- function(identity, framing) bars$p[bars$target_identity == identity & bars$target_framing == framing]
gap <- function(framing) 100 * (rate("human", framing) - rate("ai", framing))

box1_effects <- read.csv("output/box1_effects.csv", stringsAsFactors = FALSE)
interaction <- box1_effects[box1_effects$term == "identity_x_target_framing", ]

reasons_rates <- read.csv("output/reasons_rates.csv", stringsAsFactors = FALSE)
reason_rate <- function(prioritized_ai, timing) reasons_rates$p[reasons_rates$prioritized_ai == prioritized_ai & reasons_rates$note_timing == timing]
reasons_effects <- read.csv("output/reasons_effects.csv", stringsAsFactors = FALSE)
reason_effect <- reasons_effects[reasons_effects$term == "prioritized_ai", ]

cat(sprintf("N = %s observations\n", format(sum(bars$n), big.mark = ",")))
cat(sprintf("Efficiency framing: target begun first in %s of trials when human, %s when AI (gap %.1f points)\n", pct(rate("human", "efficiency")), pct(rate("ai", "efficiency")), gap("efficiency")))
cat(sprintf("Distress framing:   target begun first in %s of trials when human, %s when AI (gap %.1f points)\n", pct(rate("human", "distress")), pct(rate("ai", "distress")), gap("distress")))
cat(sprintf("Identity x framing interaction: %.2f points, 95%% CI [%.2f, %.2f], p = %.2g\n", 100 * interaction$estimate, 100 * interaction$ci_low, 100 * interaction$ci_high, interaction$p_value))
cat(sprintf("Note cites felt experience or moral concern, prioritized requester human: %s (note before choice), %s (after)\n", pct(reason_rate(0, "before")), pct(reason_rate(0, "after"))))
cat(sprintf("Note cites felt experience or moral concern, prioritized requester AI:    %s (note before choice), %s (after)\n", pct(reason_rate(1, "before")), pct(reason_rate(1, "after"))))
cat(sprintf("AI minus human prioritized requester: %.2f points, p = %.2g\n", 100 * reason_effect$estimate, reason_effect$p_value))
