# 00_setup.R — environment setup. Run once, from the project root.
#
# Preferred route is renv, which pins exact package versions in renv.lock so the
# analysis can be rebuilt identically later:
#
#   install.packages("renv")
#   renv::init()        # scans R/ for library() calls and installs what it finds
#
# renv only locks packages the scripts actually use, so right now it will pick up
# readxl, dplyr and readr. The econometrics packages come in with script 02:
#
#   renv::install(c("urca", "vars", "lmtest", "sandwich"))
#   renv::snapshot()
#
# If you would rather not use renv, this installs the same set globally.

pkgs <- c(
  "readxl",   # read the source workbook
  "dplyr", "tidyr", "readr",
  "urca",     # ur.df (ADF), ca.jo (Johansen)
  "vars",     # VAR estimation, Toda-Yamamoto causality
  "lmtest",   # bgtest (Breusch-Godfrey), bptest (Breusch-Pagan)
  "sandwich",
  "ggplot2"
)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) {
  # CRAN ships arm64 binaries for all of these, so no compiler is needed.
  install.packages(missing, type = "binary")
} else {
  message("all packages already installed")
}
