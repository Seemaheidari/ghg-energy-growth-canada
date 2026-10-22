# 99_verify_panel.R
# Check that 01_build_panel.R reproduces the committed panel.
#
# The committed data/processed/panel.csv was generated directly from the source
# workbook before R was available on this machine. This script rebuilds it with
# 01_build_panel.R and compares the two numerically.
#
# Run from the project root:  source("R/99_verify_panel.R")

library(readr)
library(dplyr)

OUT <- "data/processed/panel.csv"
stopifnot("run this from the project root" = file.exists(OUT))

committed <- read_csv(OUT, show_col_types = FALSE)

source("R/01_build_panel.R")          # overwrites OUT
rebuilt <- read_csv(OUT, show_col_types = FALSE)

key      <- c("year", "geo")
num_cols <- c("gdp_real_2012", "ghg_kt", "energy_tj")

problems <- character()
check <- function(ok, msg) if (!isTRUE(ok)) problems <<- c(problems, msg)

check(identical(dim(committed), dim(rebuilt)),
      sprintf("dimensions differ: committed %s, rebuilt %s",
              paste(dim(committed), collapse = "x"),
              paste(dim(rebuilt),   collapse = "x")))

check(identical(sort(names(committed)), sort(names(rebuilt))),
      "column names differ")

if (!length(problems)) {
  a <- arrange(committed, geo, year)
  b <- arrange(rebuilt,   geo, year)

  check(identical(a[key], b[key]), "geo/year keys differ")
  check(identical(a$in_study, b$in_study), "in_study flags differ")

  for (col in num_cols) {
    cmp <- all.equal(a[[col]], b[[col]], tolerance = 1e-9)
    check(isTRUE(cmp), sprintf("%s differs: %s", col, paste(cmp, collapse = "; ")))
  }
}

if (length(problems)) {
  message("\nPANEL VERIFICATION FAILED\n")
  for (p in problems) message("  - ", p)
  stop("rebuilt panel does not match the committed one", call. = FALSE)
}

message(sprintf(
  "\nPANEL VERIFIED\n  %d rows, %d study observations across %d jurisdictions, %d-%d\n",
  nrow(rebuilt), sum(rebuilt$in_study),
  n_distinct(rebuilt$geo[rebuilt$in_study]),
  min(rebuilt$year), max(rebuilt$year)))

message("Number formatting may differ from the committed file even when the values ")
message("match exactly. If `git diff` shows changes, that is expected on the first ")
message("run -- commit it, and the file becomes R-canonical from then on.")
