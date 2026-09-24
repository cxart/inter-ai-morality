##########################################
# INTER-AI MORALITY — BOX 1 CHART
##########################################
# Draws the Box 1 chart from the four bars. Everything quantitative is in box1_stats.R; this only draws.
##########################################

library(ggplot2)

args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% c(2, 3)) {
  stop("Usage: Rscript box1_plot.R <bars.csv> <framing_output.png> [width_inches]")
}

bars_path <- args[[1]]
framing_output <- args[[2]]
figure_width <- if (length(args) == 3) as.numeric(args[[3]]) else 5.85
if (!is.finite(figure_width) || figure_width <= 0) {
  stop("width_inches must be a positive number")
}

HUMAN <- "#51127C"
AI <- "#FD9668"


#=================================
# 1. The cells
#=================================

framing <- read.csv(bars_path, stringsAsFactors = FALSE)


#=================================
# 2. Plot
#=================================

framing$target_identity <- factor(
  framing$target_identity,
  levels = c("human", "ai"),
  labels = c("Human request", "AI request")
)
framing$target_framing <- factor(framing$target_framing, levels = c("efficiency", "distress"))

gap_for <- function(target_framing) {
  part <- framing[framing$target_framing == target_framing, ]
  100 * (part$p[part$target_identity == "Human request"] - part$p[part$target_identity == "AI request"])
}

dodge <- position_dodge(width = 0.68)

box_theme <- theme_classic(base_size = 12) +
  theme(
    text = element_text(colour = "black"),
    legend.position = "top",
    legend.justification = "center",
    legend.key.height = grid::unit(0.45, "lines"),
    legend.key.width = grid::unit(1.1, "lines"),
    legend.text = element_text(colour = "black"),
    axis.text.x = element_text(colour = "black", face = "plain", size = 11.5, lineheight = 1.25, margin = margin(t = 9)),
    axis.text.y = element_text(colour = "#777777"),
    axis.ticks = element_blank(),
    axis.line = element_line(colour = "black", linewidth = 0.45),
    panel.grid = element_blank(),
    panel.background = element_blank(),
    plot.background = element_rect(fill = "white", colour = NA),
    plot.margin = margin(2, 4, 2, 2)
  )

framing_figure <- ggplot(framing, aes(x = target_framing, y = p, fill = target_identity)) +
  geom_col(position = dodge, width = 0.62, colour = "black", linewidth = 0.35) +
  geom_errorbar(aes(ymin = ci_low, ymax = ci_high), position = dodge, width = 0.13, linewidth = 0.5, colour = "black") +
  geom_text(aes(y = ci_high + 0.042, label = sprintf("%.0f%%", 100 * p)), position = dodge, colour = "black", size = 3.65) +
  scale_fill_manual(values = c("Human request" = HUMAN, "AI request" = AI), breaks = c("Human request", "AI request")) +
  scale_y_continuous(
    limits = c(0, 0.75),
    breaks = seq(0, 0.70, by = 0.10),
    labels = scales::label_percent(accuracy = 1),
    expand = expansion(mult = c(0, 0.01))
  ) +
  scale_x_discrete(
    expand = expansion(add = 0.42),
    labels = list(
      bquote(atop(bold("Efficiency framing"), .(sprintf("Human–AI gap: %.0f%% points", gap_for("efficiency"))))),
      bquote(atop(bold("Distress framing"), .(sprintf("Human–AI gap: %.0f%% points", gap_for("distress")))))
    )
  ) +
  labs(x = NULL, y = NULL, fill = NULL) +
  box_theme

ggsave(framing_output, framing_figure, width = figure_width, height = 4.4, dpi = 330, bg = "white")
