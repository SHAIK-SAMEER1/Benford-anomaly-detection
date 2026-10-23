# scripts/cache_usaspending.R
setwd("C:/Users/SAMEER/OneDrive/Desktop/Prob_Proj")
source("R/benford.R")

cat("Processing USAspending into cached panel...\n")
p_raw <- file.path("data", "raw", "usaspending")
if (dir.exists(p_raw)) {
  df <- load_usaspending(p_raw)
  cat("Loaded rows:", nrow(df), "\n")
  if (!dir.exists("data/processed")) dir.create("data/processed", recursive = TRUE)
  saveRDS(df, "data/processed/usaspending_panel.rds")
  readr::write_csv(df, "data/processed/usaspending_clean.csv")
  cat("Saved data/processed/usaspending_panel.rds and usaspending_clean.csv successfully!\n")
} else {
  cat("USAspending directory not found.\n")
}
