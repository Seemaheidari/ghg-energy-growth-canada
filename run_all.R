# run_all.R -- rebuild every result from the source workbook.
#
#   Rscript run_all.R            rebuild if anything has changed
#   RUN_ALL_FORCE=1 Rscript run_all.R    rebuild regardless
#
# This is also the site's pre-render step, which Quarto runs before *every*
# render -- and in `quarto preview` that means on every page request. So the
# work is skipped when results/ is already newer than every input. Change a
# script, the data or a reference file and it runs again, which is what keeps
# the published pages from drifting away from the code.
#
# The CSVs under results/ are committed, so `git diff` after a run is a free
# regression test: if anything has changed, it shows up there.

scripts <- sprintf("R/%s.R", c("01_build_panel", "02_unit_roots",
                               "03_cointegration", "04_causality",
                               "05_diagnostics"))

inputs  <- c(scripts,
             list.files("data/raw", full.names = TRUE, pattern = "[.]xlsx$"),
             list.files("reference", full.names = TRUE, pattern = "[.]csv$"))
outputs <- list.files("results", full.names = TRUE, pattern = "[.]csv$")

newest <- function(f) if (length(f)) max(file.mtime(f)) else -Inf
oldest <- function(f) if (length(f)) min(file.mtime(f)) else -Inf

fresh <- length(outputs) > 0 && oldest(outputs) > newest(inputs)

if (fresh && !nzchar(Sys.getenv("RUN_ALL_FORCE"))) {
  message(sprintf("results/ is up to date (%d files); skipping. RUN_ALL_FORCE=1 to rebuild.",
                  length(outputs)))
} else {
  for (s in scripts) {
    message("\n==== ", s, " ", strrep("=", max(0, 60 - nchar(s))))
    source(s)
  }
  message("\ndone.")
}
