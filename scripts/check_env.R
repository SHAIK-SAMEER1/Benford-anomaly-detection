# scripts/check_env.R
# Validates R package dependencies for RUN_PROJECT.bat
pkgs <- c("shiny", "bslib", "readr", "dplyr", "tidyr", "ggplot2", 
          "DT", "testthat", "rmarkdown", "knitr", "jsonlite")
installed <- rownames(installed.packages())
missing <- pkgs[!pkgs %in% installed]

if (length(missing) > 0) {
  cat("MISSING PACKAGES:", paste(missing, collapse = ", "), "\n")
  quit(status = 2, save = "no")
} else {
  cat("All required R packages are installed and ready.\n")
  quit(status = 0, save = "no")
}
