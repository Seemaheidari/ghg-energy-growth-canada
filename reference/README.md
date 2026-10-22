# Thesis results, extracted

Machine-readable extracts of the `Results` sheet of the thesis workbook — the Stata
output as recorded by the author. These are the **validation target** for the rebuild:
Phase 1 is complete when `results/` reproduces these.

| File | Contents |
|---|---|
| `thesis_adf.csv` | ADF statistics and p-values, levels and first differences, 11 jurisdictions × 3 variables |
| `thesis_cointegration.csv` | Engle–Granger statistic, Johansen rank and trace statistic at that rank |
| `thesis_causality.csv` | Wald test p-values, 7 hypotheses × 11 jurisdictions |
| `thesis_diagnostics.csv` | Breusch–Pagan heteroskedasticity and Breusch–Godfrey autocorrelation |

Critical values used in the thesis:

- **ADF**: 1% −4.380, 5% −3.600, 10% −3.240
- **Engle–Granger** (Phillips–Ouliaris, N = 3 regressors with trend): 1% −5.04, 5% −4.49, 10% −4.20
- **Johansen trace**, 5%: rank 0 = 34.55, rank 1 = 18.17, rank 2 = 3.74

Two notes on reading these files:

- `johansen_rank = "Full rank"` means the trace test rejected at every rank. In the
  Johansen framework that implies a stationary system, i.e. **no** cointegration — not
  strong cointegration. The thesis reads it the other way.
- `bp_hetero_*` columns were computed but never appear in the thesis.
