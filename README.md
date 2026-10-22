# Greenhouse gas emissions, energy use and economic growth in Canadian provinces

A reproducible reimplementation of the econometric analysis in Sima Heidari,
*Aggregation and Causality in Environmental Accounts* (Master's project, Department of
Economics, University of Saskatchewan, 2023; supervisors Joel Bruneau and Maxym Chaban).

The thesis tests whether greenhouse gas emissions, industrial energy use and real GDP
share a long-run relationship in each Canadian province and nationally, 1997–2019, and
whether any of them predicts the others. The original work was done in Stata; the
do-files ran from temporary directories and did not survive. This repository rebuilds
the analysis in R from the surviving dataset.

## Status

| | |
|---|---|
| Panel built | ✅ 11 jurisdictions × 23 years, complete |
| Provenance recovered | ✅ StatCan table IDs and ECCC source, see [`data/raw/PROVENANCE.md`](data/raw/PROVENANCE.md) |
| Thesis results extracted | ✅ machine-readable in [`reference/`](reference/) |
| R + renv | ✅ R 4.6.1, 34 packages pinned in `renv.lock` |
| Unit roots (`02`) | ✅ all 66 thesis statistics reproduced exactly |
| Cointegration (`03`) | ✅ Engle–Granger 11/11; Johansen 6 of 8 |
| Causality, diagnostics | ⬜ `04`–`05` not yet written |

## Layout

```
data/raw/          source workbook + PROVENANCE.md
data/processed/    panel.csv — the one file the analysis reads
R/                 numbered scripts, run in order
reference/         the thesis's own results, for validating the rebuild
results/           generated CSVs (git-ignored)
figures/           generated plots (git-ignored)
```

## Getting started

R is not yet installed on this machine. Install it from
[CRAN](https://cran.r-project.org/bin/macosx/) (a `.pkg` installer, needs an
administrator password), then:

```r
source("R/00_setup.R")   # installs packages
source("R/01_build_panel.R")
```

`01_build_panel.R` reads the source workbook, validates coverage, and writes
`data/processed/panel.csv`.

> **Note on `panel.csv`.** The committed copy was generated directly from the workbook
> while R was unavailable, so that downstream work was not blocked. Running
> `01_build_panel.R` should reproduce it exactly — confirming that is the first
> verification step once R is installed.

## The plan

**Phase 1 — reproduce.** Rebuild each test and diff against `reference/`. Where the
numbers match, the pipeline is validated. Where they do not, there is something to look
at. Scripts `02_unit_roots.R`, `03_cointegration.R`, `04_causality.R`,
`05_diagnostics.R`.

**Phase 2 — extend.** Small-sample corrections (Reinsel–Ahn on the trace statistic) and
anything else worth checking, kept clearly separate from Phase 1 so that "what the thesis
found" and "what re-examination found" never blur.

**Phase 3 — presentation.** A Quarto site for a general and a technical audience, built
from these same scripts so it cannot drift from the analysis.

## Method, in brief

All variables in natural logarithms. Each jurisdiction is treated as its own time series
and tested separately; there is no cross-sectional pooling.

1. **ADF** unit root tests, levels and first differences. The thesis does not state
   its specification; `02_unit_roots.R` recovers it by search and reproduces all 66
   reported statistics exactly (worst error 0.0005, which is the thesis's own
   rounding). The convention is **a trend term in levels** with the lag varying by
   series, and **a constant only, at lag 0**, in first differences.
2. **Engle–Granger** two-step on the EKC single equation —
   `ln GHG ~ trend + ln GDP + (ln GDP)² + ln ENC` — against Phillips–Ouliaris critical
   values. The residual test carries a constant, at lag 0 in eight jurisdictions, 1 in
   Newfoundland and Labrador and 3 in Saskatchewan and New Brunswick. All eleven
   reported statistics reproduce exactly.
3. **Johansen** trace test on the three-variable system `{ln GHG, ln GDP, ln ENC}` with
   an unrestricted trend. The squared term is absent here: `(ln GDP)²` is not a linear
   transformation of `ln GDP`, so it cannot enter a linear VAR. The two cointegration
   tests therefore examine different specifications, which is why they disagree.
4. **Toda–Yamamoto / Wald** tests for Granger causality.
5. **Breusch–Godfrey** and **Breusch–Pagan** diagnostics.

## What the thesis found

Cointegration appears at the national level and in Ontario on the Engle–Granger test, and
in five of ten provinces on the Johansen test. Ontario is the only jurisdiction where
both agree. Greenhouse gas emissions do not predict GDP anywhere.

Every series is non-stationary in levels, and 27 of 33 are stationary after first
differencing — so the I(1) finding the cointegration tests rest on is confirmed. At a lag
order of 3, nine of the eleven Johansen ranks reproduce as reported, Ontario and Prince
Edward Island being the exceptions.

Two caveats carried over deliberately, both documented in `reference/`:

- Canada, Saskatchewan and Newfoundland and Labrador return **full rank** on the Johansen
  test. Full rank means a stationary system — not cointegration — and contradicts the ADF
  finding that every series is I(1). With 23 annual observations the trace statistic
  over-rejects badly, so these are most likely small-sample artifacts. Phase 2 tests this.
- The **Breusch–Pagan** results in `reference/thesis_diagnostics.csv` were computed but
  never reported in the thesis. No jurisdiction shows heteroskedasticity at the 10% level.
- Choosing ADF lags by **AIC** rather than taking the thesis's own agrees on 43 of 66 and
  changes the 5% conclusion in 4, all of them first differences where the thesis used lag
  0. See `results/unit_roots_vs_thesis.csv`.
- **Lag order is not identifiable at this sample size.** Across the eleven jurisdictions
  AIC chooses 4 almost everywhere and SC chooses 1 almost everywhere; a 3-variable VAR
  with a trend at K = 4 fits 14 parameters per equation to 19 observations. The Johansen
  rank therefore changes with K in **ten of the eleven** jurisdictions. `03` reports the
  ladder at K = 2, 3 and 4 rather than choosing one.
- **Canada is the exception, and not in the thesis's favour.** It returns full rank at
  every lag order tested, so the Johansen result for Canada is not a lag artifact: the
  system tests as stationary, which is *not* cointegration. The thesis's claim of a
  national long-run relationship rests on Engle–Granger alone.
- Two Johansen statistics do not reproduce under any specification searched: **New
  Brunswick** (reported 12.04 at rank 0, nearest 32.15) and **Prince Edward Island**
  (reported 16.48 at rank 1, nearest 15.27). The reported New Brunswick figure also sits
  against the rank-1 critical value rather than the rank-0 one in the source workbook,
  which suggests a transcription slip rather than a different specification.

## Citation and licence

Authorship, licence and citation are not yet settled — the underlying work is Sima
Heidari's. Add `LICENSE` and `CITATION.cff` before making the repository public.

Data are redistributed under the Statistics Canada Open Licence and the Open Government
Licence – Canada; see [`data/raw/PROVENANCE.md`](data/raw/PROVENANCE.md).
