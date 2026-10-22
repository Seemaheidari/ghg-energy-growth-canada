# Data provenance

The analysis panel is built from one workbook carried over from the thesis:

**`Total Industries Real GDP&GHG&EU 1997-2019Stata.xlsx`** — the final dataset used for
every result in Sima Heidari, *Aggregation and Causality in Environmental Accounts*
(Master's project, Department of Economics, University of Saskatchewan, 2023).
Sheet `Data` holds the panel; sheet `Sources` records the upstream series; sheet
`Results` holds the Stata output, extracted here into `reference/`.

## Upstream series

| Variable | Unit | Source |
|---|---|---|
| Real GDP, chained 2012 dollars | millions | Statistics Canada table **36-10-0402-01** ([pid 3610040201](https://www150.statcan.gc.ca/t1/tbl1/en/cv.action?pid=3610040201)) |
| Industrial energy use (final demand) | terajoules | Statistics Canada table **25-10-0029-01** ([pid 2510002901](https://www150.statcan.gc.ca/t1/tbl1/en/cv.action?pid=2510002901)) |
| Greenhouse gas emissions | kilotonnes CO₂e | Environment and Climate Change Canada, [Canada's Official Greenhouse Gas Inventory, A-IPCC-Sector](https://data.ec.gc.ca/data/substances/monitor/canada-s-official-greenhouse-gas-inventory/A-IPCC-Sector/?lang=en) |

Industry coverage follows the NAICS classification, total of all industries.

Statistics Canada material is used under the
[Statistics Canada Open Licence](https://www.statcan.gc.ca/en/reference/licence);
ECCC material under the [Open Government Licence – Canada](https://open.canada.ca/en/open-government-licence-canada).

## Two things worth knowing

**1. Canada is the sum of its parts.** The `Sources` sheet states that both GDP and GHG
for "Canada" were obtained by adding the jurisdictions up, not taken as an independently
published national series. Checking the panel confirms it: Canada equals the sum of the
ten provinces plus the three territories, to rounding. This matters for a study about
aggregation — the national series is an accounting identity over the provincial ones, not
a separate measurement.

**2. GHG does not come from Statistics Canada.** Section 2 of the thesis states that the
data were "obtained from the Statistics Canada website." That holds for GDP and energy
use; emissions come from Environment and Climate Change Canada.

## Coverage

14 jurisdictions × 23 years (1997–2019) = 322 rows. The eleven the thesis analyses — ten
provinces plus Canada — are complete, with no missing values. The three territories are
carried in `panel.csv` with `in_study = FALSE`: Nunavut and the Northwest Territories
have essentially no GHG coverage in this vintage, which is why the thesis excludes them.

## Raw files not committed

The original Statistics Canada downloads in the thesis folder (`GDP.xlsx` 41 MB,
`GDP 1997-2020 Detailed.xlsx` 48 MB, `GDP each sector every province.csv` 50 MB and
others) are not in this repository. The table identifiers above are enough to retrieve
them, and the 48 KB workbook committed here is the dataset the thesis actually used.
