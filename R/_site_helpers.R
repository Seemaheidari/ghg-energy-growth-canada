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

# ---------------------------------------------------------------------------
# A plain-language map of the provincial results.
#
# A tile grid rather than a true map: provinces sit in roughly their geographic
# positions, every one is equally legible whatever its area, and it needs no
# spatial packages (sf would drag GDAL into CI for no benefit here).

PROVINCE_GRID <- tibble::tribble(
  ~geo,                        ~abbr, ~name,              ~col, ~row,
  "British Columbia",          "BC",  "British Columbia",    1,    1,
  "Alberta",                   "AB",  "Alberta",             2,    1,
  "Saskatchewan",              "SK",  "Saskatchewan",        3,    1,
  "Manitoba",                  "MB",  "Manitoba",            4,    1,
  "Ontario",                   "ON",  "Ontario",             5,    1,
  "Quebec",                    "QC",  "Quebec",              6,    1,
  "Newfoundland and Labrador", "NL",  "Nfld. & Labrador",    7,    1,
  "New Brunswick",             "NB",  "New Brunswick",       6,    2,
  "Prince Edward Island",      "PE",  "P.E.I.",              7,    2,
  "Nova Scotia",               "NS",  "Nova Scotia",         6,    3
)

VERDICT_FILL <- c(both = "#1B6B7F", one = "#8FBCC9", neither = "#DFE3E7")
VERDICT_LAB  <- c(both    = "Found by both methods",
                  one     = "Found by one of the two",
                  neither = "Not found")

# How many of the two methods find a lasting link, plus what actually happened
# to each jurisdiction between the first year and the last. The two are not the
# same question -- one asks whether the series move together over the long run,
# the other is simply end-to-end change -- but the numbers give the shading
# something concrete to sit against.
province_verdict <- function() {
  eg  <- read_result("engle_granger.csv") |> dplyr::select(geo, eg = thesis_coint)
  joh <- read_result("johansen.csv") |> dplyr::filter(K == 3) |>
    dplyr::transmute(geo, joh = implied_rank %in% 1:2)

  change <- readr::read_csv("data/processed/panel.csv", show_col_types = FALSE) |>
    dplyr::filter(in_study) |>
    dplyr::group_by(geo) |>
    dplyr::arrange(year) |>
    dplyr::summarise(
      d_gdp = 100 * (dplyr::last(gdp_real_2012) / dplyr::first(gdp_real_2012) - 1),
      d_ghg = 100 * (dplyr::last(ghg_kt)        / dplyr::first(ghg_kt)        - 1),
      .groups = "drop")

  dplyr::inner_join(eg, joh, by = "geo") |>
    dplyr::inner_join(change, by = "geo") |>
    dplyr::mutate(verdict = dplyr::case_when(eg & joh ~ "both",
                                             eg | joh ~ "one",
                                             TRUE     ~ "neither"))
}

pct <- function(x) sprintf("%+.0f%%", x)

plot_province_map <- function() {
  v <- province_verdict()
  d <- dplyr::inner_join(PROVINCE_GRID, v, by = "geo") |>
    dplyr::mutate(verdict = factor(verdict, names(VERDICT_FILL)))
  ca  <- dplyr::filter(v, geo == "Canada")
  ink <- function(x) if (x == "neither") "#4A5058" else "white"

  ggplot(d, aes(col, row)) +
    geom_tile(aes(fill = verdict), colour = "white", linewidth = 2,
              width = 0.97, height = 0.97) +
    geom_text(aes(label = name, colour = verdict), size = 2.9, nudge_y = 0.34) +
    geom_text(aes(label = abbr, colour = verdict), size = 5.6,
              fontface = "bold", nudge_y = 0.13) +
    geom_text(aes(label = paste("economy  ", pct(d_gdp)), colour = verdict),
              size = 2.8, nudge_y = -0.17) +
    geom_text(aes(label = paste("emissions", pct(d_ghg)), colour = verdict),
              size = 2.8, fontface = "bold", nudge_y = -0.32) +

    # Canada is not a province; it sits apart, outlined rather than filled flat.
    annotate("tile", x = 2.5, y = 2.5, width = 2.9, height = 0.97,
             fill = VERDICT_FILL[[ca$verdict]], colour = "grey45",
             linewidth = 0.5, linetype = "22") +
    annotate("text", x = 2.5, y = 2.5 - 0.11, label = "CANADA",
             fontface = "bold", size = 5.6, colour = ink(ca$verdict)) +
    annotate("text", x = 2.5, y = 2.5 - 0.32, label = "the country as a whole",
             size = 2.9, colour = ink(ca$verdict)) +
    annotate("text", x = 2.5, y = 2.5 + 0.15,
             label = paste("economy  ", pct(ca$d_gdp)),
             size = 2.8, colour = ink(ca$verdict)) +
    annotate("text", x = 2.5, y = 2.5 + 0.32,
             label = paste("emissions", pct(ca$d_ghg)),
             size = 2.8, fontface = "bold", colour = ink(ca$verdict)) +

    scale_fill_manual(values = VERDICT_FILL, labels = VERDICT_LAB,
                      drop = FALSE, name = NULL,
                      guide = guide_legend(override.aes = list(colour = NA))) +
    scale_colour_manual(values = c(both = "white", one = "white",
                                   neither = "#4A5058"), guide = "none") +
    scale_y_reverse() +
    labs(
      title = "Does the economy still grow in step with emissions?",
      subtitle = paste("Change between 1997 and 2019, and whether a lasting",
                       "statistical link between\nemissions, energy use and",
                       "economic output could be detected"),
      caption = sprintf(paste(
        "Every province grew; emissions rose in some and fell in others. The",
        "shading answers a separate\nquestion -- whether the two move together",
        "over the long run. Two standard methods were used:\nthey agree a link",
        "is there in %d jurisdiction, agree it is not in %d, and disagree in the",
        "remaining %d.\n\"Not found\" means the link could not be detected in 23",
        "years of data, not that none exists."),
        sum(v$verdict == "both"), sum(v$verdict == "neither"),
        sum(v$verdict == "one"))) +
    theme_void(base_size = 12) +
    theme(legend.position = "top",
          legend.justification = "left",
          legend.key.size = unit(18, "pt"),
          legend.text = element_text(size = 10.5, margin = margin(l = 4, r = 14)),
          legend.margin = margin(b = 10),
          plot.title = element_text(face = "bold", size = 15.5),
          plot.subtitle = element_text(colour = "grey30", size = 11,
                                       margin = margin(b = 4)),
          plot.caption = element_text(colour = "grey40", hjust = 0, size = 8.8,
                                      margin = margin(t = 14)),
          plot.title.position = "plot",
          plot.caption.position = "plot",
          plot.margin = margin(12, 12, 12, 12))
}


# How the answer moves with one arbitrary modelling choice. Stated as found or
# not found rather than as a cointegrating rank: "rank 3", which the literature
# calls full rank, means no lasting link, and showing the word "full" to a
# general reader invites exactly the misreading this project documents.
plot_lag_sensitivity <- function() {
  labels <- dplyr::bind_rows(dplyr::select(PROVINCE_GRID, geo, name),
                             tibble::tibble(geo = "Canada", name = "CANADA"))

  d <- read_result("johansen.csv") |>
    dplyr::inner_join(labels, by = "geo") |>
    dplyr::mutate(found = implied_rank %in% 1:2)

  flips <- d |> dplyr::group_by(name) |>
    dplyr::summarise(changes = dplyr::n_distinct(found) > 1,
                     n = sum(found), .groups = "drop")
  n_changes <- sum(flips$changes)
  n_total   <- nrow(flips)

  ggplot(d, aes(factor(K), factor(name, levels = dplyr::arrange(flips, n)$name))) +
    geom_tile(aes(fill = found), colour = "white", linewidth = 2.5) +
    geom_text(aes(label = ifelse(found, "found", "not found"), colour = found),
              size = 3.1, fontface = "bold") +
    scale_fill_manual(values = c(`TRUE` = "#8FBCC9", `FALSE` = "#DFE3E7"),
                      guide = "none") +
    scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "#4A5058"),
                        guide = "none") +
    labs(x = "how many years of history the model is allowed to look back",
         y = NULL,
         title = "The answer depends on a choice nothing in the data settles",
         caption = sprintf(paste("Each column is a defensible setting of one",
                                 "modelling dial. In %d of the %d jurisdictions",
                                 "the\nanswer changes depending on where it is",
                                 "set."), n_changes, n_total)) +
    theme_minimal(base_size = 12) +
    theme(panel.grid = element_blank(),
          plot.title = element_text(face = "bold", size = 13),
          plot.title.position = "plot",
          plot.caption = element_text(colour = "grey40", hjust = 0, size = 9),
          plot.caption.position = "plot",
          axis.title.x = element_text(colour = "grey30", size = 10,
                                      margin = margin(t = 8)))
}
