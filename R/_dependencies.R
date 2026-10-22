# Not executed, and not part of the pipeline.
#
# renv discovers dependencies by scanning for library() calls. Quarto renders the
# .qmd pages through knitr and rmarkdown, which nothing in this project calls
# directly, so without this file renv::restore() would leave a fresh clone unable
# to build the site.

library(knitr)
library(rmarkdown)
