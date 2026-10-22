# 03_cointegration.R
# Engle-Granger and Johansen cointegration tests.
#
# Input :  data/processed/panel.csv
#          reference/thesis_cointegration.csv
# Output:  results/engle_granger.csv
#          results/johansen.csv                  full rank ladder, all jurisdictions
#          results/cointegration_vs_thesis.csv
#
# As with the unit root tests, the thesis does not state its specification, so each
# is recovered by search and reported alongside our own AIC-selected version.
#
# The two tests examine different models, which is the main reason they disagree:
#
#   Engle-Granger  ln GHG ~ trend + ln GDP + (ln GDP)^2 + ln ENC   -- the EKC equation
#   Johansen       {ln GHG, ln GDP, ln ENC} with an unrestricted trend
#
# (ln GDP)^2 cannot enter the Johansen system: it is not a linear transformation of
# ln GDP, so a linear VAR cannot carry both.

# vars pulls in MASS, which masks dplyr::select(). run_all.R sources every script
# into one session, so the masking outlives this file and load order cannot fix
# it: select() is qualified throughout 03, 04 and 05 instead.
suppressPackageStartupMessages({
  library(vars)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(urca)
})

MAX_LAG <- 4L

# Phillips-Ouliaris, N = 3 regressors with trend, as quoted in the thesis.
EG_CRIT   <- c(`1%` = -5.04, `5%` = -4.49, `10%` = -4.20)
# Johansen trace, 5%, three variables with an unrestricted trend, as quoted.
JOH_CRIT5 <- c(`0` = 34.55, `1` = 18.17, `2` = 3.74)

panel <- read_csv("data/processed/panel.csv", show_col_types = FALSE) |>
  filter(in_study) |>
  arrange(geo, year)

jurisdictions <- unique(panel$geo)

vars_of <- function(g) {
  d <- filter(panel, geo == g)
  tibble(ghg = log(d$ghg_kt), gdp = log(d$gdp_real_2012),
         enc = log(d$energy_tj)) |>
    mutate(gdp2 = gdp^2, t = row_number())
}

thesis <- read_csv("reference/thesis_cointegration.csv", show_col_types = FALSE)

# ============================================================================
# 1. Engle-Granger
# ============================================================================
#
# Step 1 estimates the EKC equation; step 2 tests its residuals for a unit root.
# The residual test carries a constant and the lag varies by jurisdiction, which
# is what reproduces the reported statistics.

eg_resid <- function(g) resid(lm(ghg ~ t + gdp + gdp2 + enc, data = vars_of(g)))

eg_stat <- function(e, k) suppressWarnings(ur.df(e, type = "drift", lags = k)@teststat[1])

eg <- lapply(jurisdictions, function(g) {
  e   <- eg_resid(g)
  tgt <- thesis$eg_stat[thesis$geo == g]

  stats <- vapply(0:MAX_LAG, function(k) eg_stat(e, k), numeric(1))
  k_thesis <- which.min(abs(stats - tgt)) - 1L

  # our own: lag by AIC on the residual ADF regression
  aics <- vapply(0:MAX_LAG, function(k) {
    d <- diff(e); idx <- (MAX_LAG + 1L):(length(e) - 1L)
    X <- data.frame(dy = d[idx], level = e[idx])
    if (k > 0L) for (i in seq_len(k)) X[[paste0("dl", i)]] <- d[idx - i]
    AIC(lm(dy ~ ., data = X))
  }, numeric(1))
  k_aic <- which.min(aics) - 1L

  tibble(geo = g,
         thesis_stat = tgt, thesis_lag = k_thesis,
         repro_stat  = stats[k_thesis + 1L],
         aic_lag = k_aic, aic_stat = stats[k_aic + 1L])
}) |> bind_rows() |>
  mutate(repro_error  = repro_stat - thesis_stat,
         thesis_coint = thesis_stat < EG_CRIT[["5%"]],
         aic_coint    = aic_stat    < EG_CRIT[["5%"]])

write_csv(eg, "results/engle_granger.csv")

# ============================================================================
# 2. Johansen
# ============================================================================
#
# ecdet = "none" with the trend supplied as an exogenous regressor is Stata's
# unrestricted-trend case, which is what the quoted critical values belong to.

joh_trace <- function(g, K) {
  d  <- as.matrix(vars_of(g)[, c("ghg", "gdp", "enc")])
  dv <- matrix(seq_len(nrow(d)), ncol = 1, dimnames = list(NULL, "trend"))
  ts <- tryCatch(suppressWarnings(
    ca.jo(d, type = "trace", ecdet = "none", K = K, spec = "longrun",
          dumvar = dv)@teststat), error = function(e) NULL)
  if (is.null(ts)) return(NULL)
  rev(ts)                                  # index 1,2,3 -> rank 0,1,2
}

# Rank implied by the sequential trace test at 5%: the first rank not rejected.
implied_rank <- function(trace) {
  for (r in 0:2) if (!isTRUE(trace[r + 1L] > JOH_CRIT5[[as.character(r)]])) return(r)
  3L                                        # rejected everywhere -> full rank
}

# Lag order is not identifiable at this sample size: across the eleven
# jurisdictions AIC chooses 4 almost everywhere and SC chooses 1 almost
# everywhere. A 3-variable VAR with a trend at K = 4 fits 14 parameters per
# equation to 19 observations. Rather than pick a criterion, the ladder is
# reported at every K from 2 to 4 so the sensitivity is visible.

K_RANGE <- 2:4

joh <- expand_grid(geo = jurisdictions, K = K_RANGE) |>
  rowwise() |>
  mutate(ts = list(joh_trace(geo, K))) |>
  ungroup() |>
  filter(!vapply(ts, is.null, logical(1))) |>
  mutate(trace_r0 = vapply(ts, `[`, numeric(1), 1),
         trace_r1 = vapply(ts, `[`, numeric(1), 2),
         trace_r2 = vapply(ts, `[`, numeric(1), 3),
         implied_rank = vapply(ts, implied_rank, integer(1))) |>
  dplyr::select(-ts)

# K that reproduces each reported statistic at its reported rank.
recovered <- lapply(jurisdictions, function(g) {
  tgt <- thesis$johansen_trace_at_rank[thesis$geo == g]
  rk  <- thesis$johansen_rank[thesis$geo == g]
  if (is.na(tgt) || !rk %in% c("0", "1", "2"))
    return(tibble(geo = g, thesis_K = NA_integer_, repro_trace = NA_real_))
  r <- as.integer(rk)
  cand <- filter(joh, geo == g)
  vals <- c(cand$trace_r0, cand$trace_r1, cand$trace_r2)[r * nrow(cand) + seq_len(nrow(cand))]
  best <- which.min(abs(vals - tgt))
  tibble(geo = g, thesis_K = cand$K[best], repro_trace = vals[best])
}) |> bind_rows() |>
  left_join(dplyr::select(thesis, geo, thesis_rank = johansen_rank,
                   thesis_trace = johansen_trace_at_rank), by = "geo") |>
  mutate(repro_error = repro_trace - thesis_trace)

write_csv(joh, "results/johansen.csv")
write_csv(recovered, "results/johansen_vs_thesis.csv")

# ============================================================================
# 3. Report
# ============================================================================

eg_exact <- sum(abs(eg$repro_error) < 0.005, na.rm = TRUE)
message(sprintf("\nEngle-Granger: %d of %d statistics reproduced to within 0.005",
                eg_exact, nrow(eg)))
message("  residual-ADF lags recovered: ",
        paste(sprintf("%s=%d", eg$geo, eg$thesis_lag), collapse = ", "))

tested <- sum(!is.na(recovered$thesis_trace))
exact  <- sum(abs(recovered$repro_error) < 0.005, na.rm = TRUE)
message(sprintf("\nJohansen: %d of %d reported statistics reproduced to within 0.005",
                exact, tested))
miss <- filter(recovered, !is.na(thesis_trace), abs(repro_error) >= 0.005)
if (nrow(miss)) {
  message("  not reproduced:")
  print(as.data.frame(miss[, c("geo", "thesis_rank", "thesis_trace",
                               "repro_trace", "repro_error")]),
        row.names = FALSE, digits = 5)
}

message("\nRank implied by the sequential trace test, by lag order:")
ranks <- joh |>
  dplyr::select(geo, K, implied_rank) |>
  pivot_wider(names_from = K, values_from = implied_rank, names_prefix = "K=") |>
  left_join(dplyr::select(thesis, geo, thesis = johansen_rank), by = "geo")
print(as.data.frame(ranks), row.names = FALSE)

stable <- joh |> group_by(geo) |> summarise(n = n_distinct(implied_rank)) |>
  filter(n == 1) |> pull(geo)
message(sprintf("\nrank unchanged across K = 2, 3, 4 in %d of %d jurisdictions%s",
                length(stable), length(jurisdictions),
                if (length(stable)) paste0(": ", paste(stable, collapse = ", ")) else ""))

full <- filter(joh, implied_rank == 3L)
message(sprintf("full rank (a stationary system, i.e. no cointegration) in %d of %d fits",
                nrow(full), nrow(joh)))

comparison <- eg |>
  dplyr::select(geo, eg_thesis = thesis_stat, eg_repro = repro_stat,
         eg_coint = thesis_coint) |>
  left_join(dplyr::select(recovered, geo, joh_thesis_rank = thesis_rank), by = "geo") |>
  left_join(ranks[, c("geo", "K=3")], by = "geo") |>
  rename(joh_rank_K3 = `K=3`) |>
  mutate(both = eg_coint & joh_rank_K3 %in% 1:2)

write_csv(comparison, "results/cointegration_vs_thesis.csv")

message(sprintf("\nAt K = 3, both tests find a long-run relationship in: %s",
                paste(comparison$geo[comparison$both], collapse = ", ")))
