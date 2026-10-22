# 05_diagnostics.R
# Residual diagnostics on the EKC single equation.
#
# Input :  data/processed/panel.csv
#          reference/thesis_diagnostics.csv
# Output:  results/diagnostics.csv
#          results/diagnostics_vs_thesis.csv
#
# Both tests are run on the same equation the Engle-Granger step estimates in 03:
#
#     ln GHG = a + b*t + c*ln GDP + d*(ln GDP)^2 + e*ln ENC + u
#
# The specifications reproduce the thesis exactly:
#
#   Breusch-Godfrey  order 9, referred to chi-squared
#   Breusch-Pagan    against fitted values, one degree of freedom, unstudentised
#                    -- Stata's `estat hettest`
#
# Order 9 is a great many lags for 23 observations: the auxiliary regression then
# carries 14 regressors and leaves 9 residual degrees of freedom. Lower orders are
# reported alongside so the conclusion can be judged.
#
# The Breusch-Pagan results never appear in the thesis. They are computed in the
# author's workbook and reported here for the first time.

library(dplyr)
library(tidyr)
library(readr)
library(lmtest)

BG_ORDER_THESIS <- 9L
BG_ORDERS       <- 1:4

panel <- read_csv("data/processed/panel.csv", show_col_types = FALSE) |>
  filter(in_study) |> arrange(geo, year)

thesis <- read_csv("reference/thesis_diagnostics.csv", show_col_types = FALSE)
jurisdictions <- thesis$geo

ekc_fit <- function(g) {
  d <- filter(panel, geo == g)
  m <- tibble(ghg = log(d$ghg_kt), gdp = log(d$gdp_real_2012),
              enc = log(d$energy_tj)) |>
    mutate(gdp2 = gdp^2, t = row_number())
  lm(ghg ~ t + gdp + gdp2 + enc, data = m)
}

# --- 1. the thesis specifications -------------------------------------------

main <- lapply(jurisdictions, function(g) {
  f  <- ekc_fit(g)
  bg <- bgtest(f, order = BG_ORDER_THESIS, type = "Chisq")
  bp <- bptest(f, varformula = ~ fitted(f), studentize = FALSE)
  bpk <- bptest(f)                       # Koenker's studentised version
  tibble(geo = g,
         n_obs = nobs(f), n_coef = length(coef(f)),
         bg_chi2 = unname(bg$statistic), bg_p = unname(bg$p.value),
         bp_chi2 = unname(bp$statistic), bp_p = unname(bp$p.value),
         bp_koenker_p = unname(bpk$p.value))
}) |> bind_rows()

# --- 2. Breusch-Godfrey at lower orders -------------------------------------

by_order <- expand_grid(geo = jurisdictions, order = BG_ORDERS) |>
  rowwise() |>
  mutate(p = unname(bgtest(ekc_fit(geo), order = order, type = "Chisq")$p.value)) |>
  ungroup()

wide <- by_order |>
  pivot_wider(names_from = order, values_from = p, names_prefix = "bg_p_order")

diagnostics <- left_join(main, wide, by = "geo")
write_csv(diagnostics, "results/diagnostics.csv")

# --- 3. comparison ----------------------------------------------------------

comparison <- diagnostics |>
  select(geo, bg_chi2, bg_p, bp_chi2, bp_p) |>
  inner_join(thesis, by = "geo") |>
  mutate(d_bg = bg_chi2 - bg_autocorr_chi2,
         d_bp = bp_chi2 - bp_hetero_chi2)

write_csv(comparison, "results/diagnostics_vs_thesis.csv")

message(sprintf("\nBreusch-Godfrey: %d of %d reproduced within 0.01 (max error %.4f)",
                sum(abs(comparison$d_bg) < 0.01), nrow(comparison),
                max(abs(comparison$d_bg))))
message(sprintf("Breusch-Pagan  : %d of %d reproduced within 0.01 (max error %.4f)",
                sum(abs(comparison$d_bp) < 0.01), nrow(comparison),
                max(abs(comparison$d_bp))))

# --- 4. report --------------------------------------------------------------

message(sprintf("\nautocorrelation at order %d: %d reject at 5%%, %d more at 10%%",
                BG_ORDER_THESIS, sum(main$bg_p < 0.05),
                sum(main$bg_p >= 0.05 & main$bg_p < 0.10)))
message(sprintf("  5%%: %s", paste(main$geo[main$bg_p < 0.05], collapse = ", ")))
message(sprintf(" 10%%: %s", paste(main$geo[main$bg_p >= 0.05 & main$bg_p < 0.10],
                                   collapse = ", ")))

message("\nBreusch-Godfrey p-values by order (9 is the thesis's):")
tbl <- diagnostics |>
  select(geo, starts_with("bg_p_order"), `order9` = bg_p)
print(as.data.frame(tbl), row.names = FALSE, digits = 3)

message(sprintf(
  "\nrejects at 5%% by order: %s",
  paste(sprintf("order %d: %d", c(BG_ORDERS, BG_ORDER_THESIS),
                c(vapply(BG_ORDERS, function(o)
                    sum(by_order$p[by_order$order == o] < 0.05), integer(1)),
                  sum(main$bg_p < 0.05))), collapse = " | ")))

message(sprintf("\nheteroskedasticity: %d of %d reject at 10%% (Koenker version: %d)",
                sum(main$bp_p < 0.10), nrow(main), sum(main$bp_koenker_p < 0.10)))
message("  the thesis computed these but never reported them")

message(sprintf("\nnote: at order %d the auxiliary regression has %d regressors and %d observations",
                BG_ORDER_THESIS, main$n_coef[1] + BG_ORDER_THESIS, main$n_obs[1]))
