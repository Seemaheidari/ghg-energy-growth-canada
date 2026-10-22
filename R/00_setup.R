# Package setup. Run once.
#
# The project uses renv for reproducibility. On a fresh clone:
#   renv::restore()
# To initialise it the first time (this machine, once R is installed):
#   install.packages("renv"); renv::init()

pkgs <- c(
  "readxl",   # read the source workbook
  "dplyr",    # data manipulation
  "tidyr",
  "readr",
  "urca",     # ur.df (ADF), ca.jo (Johansen)
  "vars",     # VAR estimation, Toda-Yamamoto causality
  "lmtest",   # bgtest (Breusch-Godfrey), bptest (Breusch-Pagan)
  "sandwich",
  "ggplot2"
)

missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing)
invisible(lapply(pkgs, library, character.only = TRUE))
