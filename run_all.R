# run_all.R -- rebuild every result from the source workbook. Takes a few seconds.
#
#   Rscript run_all.R
#
# The CSVs under results/ are committed, so `git diff` after a run is a free
# regression test: if anything has changed, it shows up there.

scripts <- sprintf("R/%s.R", c("01_build_panel", "02_unit_roots",
                               "03_cointegration", "04_causality",
                               "05_diagnostics"))
for (s in scripts) {
  message("\n==== ", s, " ", strrep("=", max(0, 60 - nchar(s))))
  source(s)
}
message("\ndone.")
