# scripts/test_shiny_sources.R
setwd("C:/Users/SAMEER/OneDrive/Desktop/Prob_Proj")
source("R/benford.R")
app <- source("app.R")$value
cat("app.R loaded OK.\n")

shiny::testServer(app, {
  cat("Testing USAspending source in Shiny...\n")
  session$setInputs(src = "usaspending", load = 1)
  st <- data_state()
  cat("USAspending label:", st$label, "\n")
  cat("Rows:", nrow(st$df), "Columns:", ncol(st$df), "Synthetic:", st$synthetic, "\n")
  stopifnot(!is.null(st$df), nrow(st$df) > 0, !st$synthetic)
  
  session$setInputs(col4 = "USASPEND.FEDERAL_ACTION_OBLIGATION", alpha = 0.05, sub_var4 = "none")
  ch <- output$chi_tbl
  cat("Chi-tbl length:", nchar(ch), "| contains X2:", grepl("X2", ch), "\n")
  stopifnot(grepl("X2", ch))
  
  cat("\nTesting bundled WDI source in Shiny...\n")
  session$setInputs(src = "bundled", load = 1)
  st_b <- data_state()
  cat("Bundled label:", st_b$label, "Rows:", nrow(st_b$df), "\n")
  stopifnot(!is.null(st_b$df), nrow(st_b$df) > 0)
  
  cat("\nTesting synthetic source in Shiny...\n")
  session$setInputs(src = "synthetic", load = 1)
  st_s <- data_state()
  cat("Synthetic label:", st_s$label, "Synthetic:", st_s$synthetic, "\n")
  stopifnot(st_s$synthetic)
  
  cat("\n>>> ALL SHINY DATA SOURCES TESTED SUCCESSFULLY! <<<\n")
})
