# 01_build_panel.R
# Build the analysis panel from the thesis source workbook.
#
# Input :  data/raw/Total Industries Real GDP&GHG&EU 1997-2019Stata.xlsx  (sheet "Data")
# Output:  data/processed/panel.csv
#
# The workbook is the final dataset from Sima Heidari's 2023 Master's project.
# Its "Sources" sheet records the upstream series; see data/raw/PROVENANCE.md.

library(readxl)
library(dplyr)
library(readr)

SRC <- "data/raw/Total Industries Real GDP&GHG&EU 1997-2019Stata.xlsx"
OUT <- "data/processed/panel.csv"

# The eleven jurisdictions the thesis analyses: ten provinces plus Canada.
# The workbook also carries Yukon, NWT and Nunavut, which the thesis excludes
# and which have almost no GHG coverage.
study_geo <- c(
  "Canada",
  "Newfoundland and Labrador", "Prince Edward Island", "Nova Scotia",
  "New Brunswick", "Quebec", "Ontario", "Manitoba", "Saskatchewan",
  "Alberta", "British Columbia"
)

panel <- read_excel(SRC, sheet = "Data") |>
  transmute(
    year           = as.integer(REF_DATE),
    geo            = GEO,
    gdp_real_2012  = as.numeric(GDPrealVALUE),       # millions, chained 2012 dollars
    ghg_kt         = as.numeric(GHGVALUE),           # kilotonnes CO2 equivalent
    energy_tj      = as.numeric(industrialEnergyuse),# terajoules
    in_study       = geo %in% study_geo
  ) |>
  arrange(geo, year)

# --- validation -------------------------------------------------------------

stopifnot(
  "expected 14 jurisdictions"      = n_distinct(panel$geo) == 14,
  "expected 1997-2019"             = identical(range(panel$year), c(1997L, 2019L)),
  "expected 23 years per geo"      = all(table(panel$geo) == 23)
)

incomplete <- panel |>
  filter(in_study) |>
  filter(if_any(c(gdp_real_2012, ghg_kt, energy_tj), is.na))

if (nrow(incomplete)) {
  stop("missing values in study jurisdictions:\n",
       paste(capture.output(print(incomplete)), collapse = "\n"))
}

message(sprintf("panel: %d rows, %d study observations (%d jurisdictions x %d years)",
                nrow(panel), sum(panel$in_study),
                length(study_geo), 23L))

write_csv(panel, OUT)
