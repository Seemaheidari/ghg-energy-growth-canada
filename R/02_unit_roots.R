# 02_unit_roots.R
# Augmented Dickey-Fuller tests on each series, in levels and first differences.
#
# Input :  data/processed/panel.csv
#          reference/thesis_adf.csv
# Output:  results/unit_roots.csv            our own results
#          results/thesis_adf_spec.csv       the thesis specification, recovered
#          results/unit_roots_vs_thesis.csv  comparison
#
# The thesis does not state which ADF specification it used. Section 4 of this
# script recovers it by search: every one of its 66 reported statistics is
# reproduced exactly by
#
#     levels       trend term, lag chosen per series (0-3)
#     differences  constant only, lag 0 throughout
#
# which is consistent with the critical values it quotes (-4.380 / -3.600 /
# -3.240 are the trend-case values at T = 25) and with the lag(0) visible in the
# author's saved Stata output. The repository reports its own AIC-selected
# results alongside, in section 5.

library(dplyr)
library(tidyr)
library(readr)
library(urca)

MAX_LAG <- 4L

# --- 1. the ADF regression --------------------------------------------------
#
#   dy_t = alpha + beta*t + gamma*y_{t-1} + sum_i delta_i dy_{t-i} + e_t
#
# with the test statistic the t ratio on gamma. Written out rather than taken
# from a package so the lag and sample handling are explicit; cross-checked
# against urca::ur.df below.

adf_fit <- function(y, k, trend, start = NULL) {
  n <- length(y)
  d <- diff(y)                       # d[j] = dy_{j+1}
  idx <- (if (is.null(start)) k + 1L else start):(n - 1L)
  if (length(idx) < k + 5L) return(NULL)

  X <- data.frame(dy = d[idx], level = y[idx])
  if (trend) X$t <- idx + 1L
  if (k > 0L) for (i in seq_len(k)) X[[paste0("dlag", i)]] <- d[idx - i]

  fit <- lm(dy ~ ., data = X)
  list(k = k, n = length(idx), aic = AIC(fit),
       stat = summary(fit)$coefficients["level", "t value"])
}

# MacKinnon's response-surface p-value. punitroot prints a note for small
# samples on every call; it is true of every series here and said once below.
adf_p <- function(stat, n, trend) {
  suppressWarnings(utils::capture.output(
    p <- urca::punitroot(stat, N = n, trend = trend, statistic = "t")
  ))
  p
}

adf_at <- function(y, k, trend) {
  f <- adf_fit(y, k, trend)
  if (is.null(f)) return(NULL)
  tibble(lag = f$k, n_obs = f$n, stat = f$stat,
         p = adf_p(f$stat, f$n, if (trend) "ct" else "c"))
}

# Lag by AIC on a sample held fixed at MAX_LAG so the criteria are comparable,
# then re-estimated at that lag on all observations it allows.
adf_aic <- function(y, trend, max_lag = MAX_LAG) {
  cand <- Filter(Negate(is.null),
                 lapply(0:max_lag, adf_fit, y = y, trend = trend,
                        start = max_lag + 1L))
  if (!length(cand)) return(NULL)
  adf_at(y, cand[[which.min(vapply(cand, `[[`, numeric(1), "aic"))]]$k, trend)
}

# --- 2. data ----------------------------------------------------------------

panel <- read_csv("data/processed/panel.csv", show_col_types = FALSE) |>
  filter(in_study) |>
  transmute(geo, year,
            gdp    = log(gdp_real_2012),
            ghg    = log(ghg_kt),
            energy = log(energy_tj)) |>
  pivot_longer(c(gdp, ghg, energy), names_to = "variable", values_to = "value") |>
  arrange(geo, variable, year)

series <- function(g, v, transform) {
  y <- panel$value[panel$geo == g & panel$variable == v]
  if (transform == "diff") diff(y) else y
}

# --- 3. cross-check against urca --------------------------------------------

chk <- series("Alberta", "gdp", "level")
stopifnot("ADF regression disagrees with urca::ur.df" = isTRUE(all.equal(
  adf_fit(chk, k = 1L, trend = TRUE)$stat,
  ur.df(chk, type = "trend", lags = 1L)@teststat[1],
  tolerance = 1e-8)))
message("cross-check against urca::ur.df: OK")
message("note: MacKinnon p-values are extrapolated below T = 25; every series here is T <= 23")

# --- 4. recover the thesis specification ------------------------------------

thesis <- read_csv("reference/thesis_adf.csv", show_col_types = FALSE) |>
  pivot_longer(-c(geo, variable),
               names_to = c("transform", ".value"),
               names_pattern = "(level|diff)_(stat|p)") |>
  rename(thesis_stat = stat, thesis_p = p)

recovered <- thesis |>
  rowwise() |>
  mutate(fit = list({
    y <- series(geo, variable, transform)
    grid <- expand_grid(trend = c(TRUE, FALSE), k = 0:MAX_LAG)
    cand <- Map(function(tr, k) adf_fit(y, k, tr), grid$trend, grid$k)
    ok   <- !vapply(cand, is.null, logical(1))
    stat <- vapply(cand[ok], `[[`, numeric(1), "stat")
    best <- which.min(abs(stat - thesis_stat))
    tibble(spec = if (grid$trend[ok][best]) "trend" else "drift",
           lag  = grid$k[ok][best],
           stat = stat[best])
  })) |>
  ungroup() |>
  unnest(fit) |>
  mutate(repro_error = stat - thesis_stat)

write_csv(select(recovered, geo, variable, transform, spec, lag,
                 thesis_stat, stat, repro_error),
          "results/thesis_adf_spec.csv")

exact <- sum(abs(recovered$repro_error) < 0.005)
message(sprintf("\nthesis specification recovered: %d of %d statistics reproduced to within 0.005",
                exact, nrow(recovered)))
print(table(transform = recovered$transform, spec = recovered$spec))
print(table(transform = recovered$transform, lag = recovered$lag))

# --- 5. our own results, lag by AIC -----------------------------------------
#
# Trend in levels, constant only in differences -- the specification recovered
# above -- but with the lag chosen by AIC rather than taken from the thesis.

ours <- distinct(panel, geo, variable) |>
  expand_grid(transform = c("level", "diff")) |>
  rowwise() |>
  mutate(fit = list(adf_aic(series(geo, variable, transform),
                            trend = transform == "level"))) |>
  ungroup() |>
  unnest(fit) |>
  mutate(spec = if_else(transform == "level", "trend", "drift"),
         reject_5pct = stat < if_else(transform == "level", -3.600, -3.000)) |>
  select(geo, variable, transform, spec, lag, n_obs, stat, p, reject_5pct) |>
  arrange(geo, variable, transform)

write_csv(ours, "results/unit_roots.csv")

# --- 6. comparison ----------------------------------------------------------

comparison <- ours |>
  inner_join(select(recovered, geo, variable, transform,
                    thesis_lag = lag, thesis_stat, thesis_p),
             by = c("geo", "variable", "transform")) |>
  mutate(d_stat    = stat - thesis_stat,
         same_lag  = lag == thesis_lag,
         crit      = if_else(transform == "level", -3.600, -3.000),
         same_call = (stat < crit) == (thesis_stat < crit)) |>
  arrange(desc(abs(d_stat)))

write_csv(comparison, "results/unit_roots_vs_thesis.csv")

message(sprintf("\nAIC vs thesis: same lag in %d of %d; same 5%% conclusion in %d of %d",
                sum(comparison$same_lag), nrow(comparison),
                sum(comparison$same_call), nrow(comparison)))
message(sprintf("median |difference| in statistic: %.3f", median(abs(comparison$d_stat))))

disagree <- filter(comparison, !same_call)
if (nrow(disagree)) {
  message("\nDifferent conclusion at 5% in ", nrow(disagree), " case(s):")
  print(as.data.frame(select(disagree, geo, variable, transform,
                             lag, thesis_lag, stat, thesis_stat, d_stat)),
        row.names = FALSE, digits = 4)
}
