# Shared helpers for the Quarto pages. Not part of the analysis pipeline.

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(ggplot2)
})

PALETTE <- c(oil = "#C2571A", ontario = "#1F6F8B", other = "#8A8F98")

read_result <- function(f) read_csv(file.path("results", f), show_col_types = FALSE)

# Short labels; the full names are unwieldy on an axis.
SHORT <- c("Canada" = "Canada", "British Columbia" = "BC", "Alberta" = "Alberta",
           "Saskatchewan" = "Sask.", "Manitoba" = "Manitoba", "Ontario" = "Ontario",
           "Quebec" = "Quebec", "Newfoundland and Labrador" = "N.L.",
           "Prince Edward Island" = "P.E.I.", "New Brunswick" = "N.B.",
           "Nova Scotia" = "N.S.")

highlight <- function(geo) {
  case_when(geo %in% c("Alberta", "Saskatchewan") ~ "oil",
            geo == "Ontario" ~ "ontario",
            TRUE ~ "other")
}

theme_site <- function() {
  theme_minimal(base_size = 12) +
    theme(panel.grid.major.y = element_blank(),
          panel.grid.minor = element_blank(),
          plot.title.position = "plot",
          legend.position = "none",
          plot.caption = element_text(colour = "grey40", hjust = 0))
}

# The headline chart: Engle-Granger statistic by jurisdiction.
plot_eg <- function() {
  read_result("engle_granger.csv") |>
    mutate(label = SHORT[geo], grp = highlight(geo)) |>
    ggplot(aes(x = thesis_stat, y = reorder(label, thesis_stat), colour = grp)) +
    geom_vline(xintercept = -4.49, linetype = "dashed", colour = "grey50") +
    geom_point(size = 3.2) +
    scale_colour_manual(values = PALETTE) +
    labs(x = "Engle-Granger test statistic", y = NULL,
         caption = paste("Dashed line: the 5% critical value of -4.49. Points to its",
                         "left show a long-run relationship.\nAlberta and Saskatchewan",
                         "in orange, Ontario in blue.")) +
    theme_site()
}

# How the Johansen rank moves with the lag order.
plot_rank_stability <- function() {
  read_result("johansen.csv") |>
    mutate(label = SHORT[geo], grp = highlight(geo),
           rank_lab = if_else(implied_rank == 3L, "full", as.character(implied_rank))) |>
    ggplot(aes(x = factor(K), y = reorder(label, implied_rank))) +
    geom_tile(aes(fill = grp), colour = "white", alpha = 0.18, linewidth = 1.2) +
    geom_text(aes(label = rank_lab, colour = grp), fontface = "bold", size = 4) +
    scale_fill_manual(values = PALETTE) +
    scale_colour_manual(values = PALETTE) +
    labs(x = "lag order (K)", y = NULL,
         caption = paste("Cointegrating rank implied by the trace test.",
                         "\"full\" means the system tests as stationary,",
                         "which is not\ncointegration. The rank moves with K",
                         "in ten of the eleven jurisdictions.")) +
    theme_site() + theme(panel.grid = element_blank())
}
