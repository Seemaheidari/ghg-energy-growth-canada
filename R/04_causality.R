# 04_causality.R
# Granger causality tests.
#
# Input :  data/processed/panel.csv
#          reference/thesis_causality.csv
# Output:  results/causality.csv
#          results/causality_vs_thesis.csv
#
# Section 3 of the thesis describes the Toda-Yamamoto (1995) procedure: estimate a
# VAR with k + dmax lags, where dmax is the maximal order of integration, and test
# only the first k. The extra lags are what give the Wald statistic its standard
# asymptotic distribution when the variables are integrated.
#
# That is not what produces the reported p-values. All 77 of them are reproduced,
# to within the thesis's own 4-decimal rounding, by a single-lag regression in log
# levels with a linear trend,
#
#     y_t = a + b*t + c1*lnGHG_{t-1} + c2*lnGDP_{t-1}
#               + c3*lnGDP2_{t-1} + c4*lnENC_{t-1} + e_t
#
# and an F test on the relevant coefficient. There is no augmentation, so the
# safeguard the cited procedure exists to provide is absent. Section 3 below
# therefore runs Toda-Yamamoto properly alongside, and reports where the two differ.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
})

DMAX <- 1L   # every series is I(1); see results/unit_roots.csv

panel <- read_csv("data/processed/panel.csv", show_col_types = FALSE) |>
  filter(in_study) |> arrange(geo, year)

thesis <- read_csv("reference/thesis_causality.csv", show_col_types = FALSE)
jurisdictions <- thesis$geo

# effect variable, then the causing variable(s)
HYP <- list(
  ghg_to_gdp         = list("gdp", "ghg"),
  energy_to_gdp      = list("gdp", "enc"),
  gdp_gdp2_to_ghg    = list("ghg", c("gdp", "gdp2")),
  energy_to_ghg      = list("ghg", "enc"),
  gdp_to_energy      = list("enc", "gdp"),
  gdp_gdp2_to_energy = list("enc", c("gdp", "gdp2")),
  ghg_to_energy      = list("enc", "ghg")
)
SYS <- c("ghg", "gdp", "gdp2", "enc")

vars_of <- function(g) {
  d <- filter(panel, geo == g)
  tibble(ghg = log(d$ghg_kt), gdp = log(d$gdp_real_2012),
         enc = log(d$energy_tj)) |> mutate(gdp2 = gdp^2)
}

lag_vec <- function(x, k) c(rep(NA_real_, k), head(x, -k))

# Joint Wald test that the named coefficients are zero. `stat = "F"` divides by
# the number of restrictions and refers to F, as Stata's `test` does after
# `regress`; `stat = "chi2"` refers the Wald statistic to chi-squared, which is
# what Toda-Yamamoto calls for.
wald <- function(fit, keep, stat) {
  b <- coef(fit); V <- vcov(fit)
  keep <- intersect(keep, names(b))
  if (!length(keep)) return(NA_real_)
  R <- diag(length(b))[match(keep, names(b)), , drop = FALSE]
  q <- nrow(R)
  W <- as.numeric(t(R %*% b) %*% solve(R %*% V %*% t(R)) %*% (R %*% b))
  if (stat == "chi2") pchisq(W, q, lower.tail = FALSE)
  else                pf(W / q, q, fit$df.residual, lower.tail = FALSE)
}

# --- 1. the specification that reproduces the thesis ------------------------

thesis_spec <- function(d, dep, cause) {
  X <- data.frame(y = d[[dep]], trend = seq_len(nrow(d)))
  for (v in SYS) X[[v]] <- lag_vec(d[[v]], 1L)
  X <- na.omit(X)
  wald(lm(y ~ ., data = X), cause, "F")
}

# --- 2. Toda-Yamamoto, as described in section 3 ----------------------------
#
# VAR equation with k + dmax lags of every variable; the Wald test covers only
# the first k lags of the causing variable(s) and is referred to chi-squared.

toda_yamamoto <- function(d, dep, cause, k) {
  p <- k + DMAX
  X <- data.frame(y = d[[dep]], trend = seq_len(nrow(d)))
  for (v in SYS) for (i in seq_len(p)) X[[paste0(v, "_", i)]] <- lag_vec(d[[v]], i)
  X <- na.omit(X)
  if (nrow(X) < ncol(X) + 3L) return(NA_real_)
  wald(lm(y ~ ., data = X),
       as.vector(outer(cause, seq_len(k), function(v, i) paste0(v, "_", i))),
       "chi2")
}

# --- 3. run -----------------------------------------------------------------

results <- expand_grid(geo = jurisdictions, hypothesis = names(HYP)) |>
  rowwise() |>
  mutate(
    dep    = HYP[[hypothesis]][[1]],
    p_thesis_spec = thesis_spec(vars_of(geo), dep, HYP[[hypothesis]][[2]]),
    p_ty_k1       = toda_yamamoto(vars_of(geo), dep, HYP[[hypothesis]][[2]], 1L),
    p_ty_k2       = toda_yamamoto(vars_of(geo), dep, HYP[[hypothesis]][[2]], 2L)
  ) |>
  ungroup() |>
  dplyr::select(-dep)

reported <- thesis |>
  pivot_longer(-geo, names_to = "hypothesis", values_to = "p_reported")

comparison <- results |>
  inner_join(reported, by = c("geo", "hypothesis")) |>
  mutate(repro_error = p_thesis_spec - p_reported,
         sig_reported = p_reported    < 0.05,
         sig_repro    = p_thesis_spec < 0.05,
         sig_ty_k1    = p_ty_k1       < 0.05,
         sig_ty_k2    = p_ty_k2       < 0.05)

write_csv(results, "results/causality.csv")
write_csv(comparison, "results/causality_vs_thesis.csv")

# --- 4. report --------------------------------------------------------------

message(sprintf("\nreproduction of the reported p-values: %d of %d within 0.001 (max error %.5f)",
                sum(abs(comparison$repro_error) < 0.001), nrow(comparison),
                max(abs(comparison$repro_error))))

message(sprintf("\ncausality found at 5%%:\n  as reported        : %d of %d",
                sum(comparison$sig_reported), nrow(comparison)))
message(sprintf("  Toda-Yamamoto k=1  : %d", sum(comparison$sig_ty_k1, na.rm = TRUE)))
message(sprintf("  Toda-Yamamoto k=2  : %d", sum(comparison$sig_ty_k2, na.rm = TRUE)))

message("\nby hypothesis (reported / TY k=1 / TY k=2):")
comparison |>
  group_by(hypothesis) |>
  summarise(reported = sum(sig_reported),
            ty_k1 = sum(sig_ty_k1, na.rm = TRUE),
            ty_k2 = sum(sig_ty_k2, na.rm = TRUE), .groups = "drop") |>
  as.data.frame() |> print(row.names = FALSE)

flip <- filter(comparison, sig_reported != sig_ty_k1)
message(sprintf("\nconclusion changes under Toda-Yamamoto (k=1) in %d of %d tests:",
                nrow(flip), nrow(comparison)))
if (nrow(flip)) {
  print(as.data.frame(flip[, c("geo", "hypothesis", "p_reported", "p_ty_k1")]),
        row.names = FALSE, digits = 4)
}

# The thesis's headline causality claim.
ghg_gdp <- filter(comparison, hypothesis == "ghg_to_gdp")
message(sprintf("\nGHG predicts GDP nowhere: reported %s, Toda-Yamamoto k=1 %s",
                if (!any(ghg_gdp$sig_reported)) "confirmed" else "NOT confirmed",
                if (!any(ghg_gdp$sig_ty_k1, na.rm = TRUE)) "confirmed" else "NOT confirmed"))
