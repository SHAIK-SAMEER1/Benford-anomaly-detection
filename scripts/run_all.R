#!/usr/bin/env Rscript
###############################################################################
##  scripts/run_all.R -- one command rebuilds every output of the project.
##
##  Usage (from the project root):
##      Rscript scripts/run_all.R                 full run (200 experiment reps)
##      Rscript scripts/run_all.R --quick         fast run (30 reps)
##      Rscript scripts/run_all.R --data=PATH     use a specific WDI zip / CSV /
##                                               folder instead of the automatic
##                                               search
##      Rscript scripts/run_all.R --out=DIR       write outputs somewhere else
##      Rscript scripts/run_all.R --no-report     skip the HTML/DOCX report
##
##  The script exits with status 1 if any mandatory output is missing or empty.
###############################################################################

## ---------------------------------------------------------------- arguments
args_all <- commandArgs(trailingOnly = TRUE)
quick       <- "--quick" %in% args_all
no_report   <- "--no-report" %in% args_all
opt_of <- function(name, default) {
  hit <- args_all[startsWith(args_all, paste0("--", name, "="))]
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else default
}
data_arg <- opt_of("data", NULL)
out_root <- opt_of("out", "outputs")

## ------------------------------------------------------------- project root
find_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:6) {
    if (file.exists(file.path(d, "R", "benford.R"))) return(d)
    d_parent <- dirname(d)
    if (identical(d_parent, d)) break
    d <- d_parent
  }
  normalizePath(getwd())
}
ROOT <- find_root()
source(file.path(ROOT, "R", "benford.R"))

# an absolute --out path is used as given, a relative one sits under the project root
OUT_ROOT <- if (grepl("^([A-Za-z]:|/|\\\\)", out_root)) out_root else file.path(ROOT, out_root)
TABLES <- file.path(OUT_ROOT, "tables")
FIGURES <- file.path(OUT_ROOT, "figures")
for (d in c(TABLES, FIGURES, file.path(ROOT, "data", "processed"),
            file.path(ROOT, "data", "fixtures"), file.path(ROOT, "reports"))) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

step <- function(...) cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), paste0(...)))
set.seed(2025)
ALPHA <- 0.05
MIN_N <- 110L
R_REPS <- if (quick) 30L else 200L

## --------------------------------------------------------------- pandoc check
ensure_pandoc <- function() {
  if (rmarkdown::pandoc_available()) return(TRUE)
  cands <- c(
    file.path(Sys.getenv("ProgramFiles"), "RStudio", "resources", "app", "bin", "quarto", "bin", "tools"),
    file.path(Sys.getenv("ProgramFiles"), "RStudio", "resources", "app", "bin", "pandoc"),
    file.path(Sys.getenv("ProgramFiles"), "Quarto", "bin", "tools"),
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "RStudio", "resources", "app", "bin", "quarto", "bin", "tools"),
    file.path(Sys.getenv("LOCALAPPDATA"), "Programs", "Quarto", "bin", "tools"))
  for (c1 in cands) {
    if (nzchar(c1) && file.exists(file.path(c1, "pandoc.exe"))) {
      Sys.setenv(RSTUDIO_PANDOC = c1)
      if (rmarkdown::pandoc_available()) return(TRUE)
    }
  }
  FALSE
}
PANDOC_OK <- ensure_pandoc()

## =========================================================== 1. load the data
step("Loading data ...")
panel_info <- load_curated_panel(root = ROOT, data_arg = data_arg)
panel      <- panel_info$panel
IS_SYNTHETIC <- isTRUE(panel_info$is_synthetic)
USASPEND <- try(load_usaspending(file.path(ROOT, "data", "raw", "usaspending")), silent = TRUE)
if (!inherits(USASPEND, "try-error") && !is.null(USASPEND) && nrow(USASPEND) > 0) {
  panel <- rbind(panel[, names(USASPEND)], USASPEND)
  panel_info$notes <- c(panel_info$notes, sprintf("Optional USASpending file picked up: %d rows.", nrow(USASPEND)))
  step("  optional USASpending data included: ", nrow(USASPEND), " rows")
} else {
  panel_info$notes <- c(panel_info$notes, "No optional USASpending CSV found in data/raw/usaspending/ (this dataset is optional).")
}
step(sprintf("  source: %s", panel_info$source_label))
step(sprintf("  panel rows: %d | indicators: %d | synthetic: %s",
             nrow(panel), length(unique(panel$indicator_code)), IS_SYNTHETIC))
if (IS_SYNTHETIC) step("  *** SYNTHETIC - NOT REAL DATA: no WDI file was found ***")

## save the cleaned curated panel
clean_path <- file.path(ROOT, "data", "processed", "wdi_clean.csv")
utils::write.csv(panel, clean_path, row.names = FALSE, na = "")
step("  wrote ", clean_path)

## ================================================== 2. run the core analysis
step("Running Benford analyses on every analysis unit ...")
A <- run_benford_analysis(panel, alpha = ALPHA, min_n = MIN_N, extended = TRUE,
                          bootstrap = TRUE, B = if (quick) 200L else 1000L)
step(sprintf("  %d units tested, %d units skipped (below N = %d)",
             nrow(A$chi_square), if (is.null(A$skipped)) 0L else nrow(A$skipped), MIN_N))

## ========================================================== 3. write the tables
step("Writing result tables ...")
write_tab <- function(df, name) {
  if (is.null(df) || !nrow(df)) df <- data.frame(note = "no rows produced")
  p <- file.path(TABLES, name)
  utils::write.csv(df, p, row.names = FALSE, na = "")
  invisible(p)
}
write_tab(A$descriptive,            "descriptive_statistics.csv")
write_tab(A$cleaning,               "cleaning_exclusions.csv")
write_tab(A$suitability,            "suitability_summary.csv")
write_tab(benford_probability_table(), "benford_expected_probabilities.csv")
write_tab(A$first_digit_frequency,  "first_digit_frequency.csv")
write_tab(A$chi_square,             "chi_square_results.csv")
write_tab(A$chi_square[, c("indicator_code", "indicator_label", "indicator_role", "unit_type",
                           "unit_label", "n", "x2", "df", "p_raw", "p_holm", "p_bh", "alpha",
                           "validity_tier", "mad", "nigrini_band", "cohens_w", "flag",
                           "interpretation")], "anomaly_flags.csv")
write_tab(A$two_digit,              "two_digit_results.csv")
if (!is.null(A$skipped)) write_tab(A$skipped, "skipped_units.csv")
step("  tables written to ", TABLES)

## ============================================================ 4. experiments
step(sprintf("Running the controlled synthetic manipulation experiment (R = %d) ...", R_REPS))
t0 <- Sys.time()
EXP <- run_experiment(n = 2000L, R = R_REPS, seed = 2025L, alpha = ALPHA)
step(sprintf("  experiment done in %.1f s (%d replicates)",
             as.numeric(difftime(Sys.time(), t0, units = "secs")), nrow(EXP$replicates)))
ANOVA <- experiment_anova(EXP$replicates, alpha = ALPHA)
REG   <- experiment_regression(EXP$replicates)
write_tab(EXP$replicates, "experiment_replicates.csv")
write_tab(EXP$summary,    "experiment_summary.csv")
write_tab(ANOVA,          "anova_results.csv")
write_tab(REG,            "regression_results.csv")

## write the labelled test fixture
fix <- data.frame(record_id = seq_len(2000L),
                  value = synthetic_benford_base(2000L, seed = 2025L),
                  source = "SYNTHETIC - NOT REAL DATA")
utils::write.csv(fix, file.path(ROOT, "data", "fixtures", "synthetic_benford_sample.csv"),
                 row.names = FALSE)

## ============================================================== 5. figures
step("Building figures ...")
CB <- c(observed = "#0072B2", expected = "#D55E00", alt = "#009E73",
        warn = "#CC79A7", neutral = "#999999")
th <- ggplot2::theme_bw(base_size = 10) +
  ggplot2::theme(strip.text = ggplot2::element_text(size = 7),
                 plot.title = ggplot2::element_text(size = 11, face = "bold"),
                 legend.position = "bottom")
pct_lab <- function(x) sprintf("%.0f%%", 100 * x)
syn_note <- if (IS_SYNTHETIC)
  "SYNTHETIC - NOT REAL DATA: generated fallback panel, not World Bank data" else
  paste0("Source: ", panel_info$source_label)

pooled   <- A$first_digit_frequency[A$first_digit_frequency$unit_type == "pooled", ]
chi_pool <- A$chi_square[A$chi_square$unit_type == "pooled", ]
plab <- unique(pooled[, c("indicator_code", "indicator_label")])
plab$short <- paste0(plab$indicator_label, " (", plab$indicator_code, ")")
pooled$panel_label <- plab$short[match(pooled$indicator_code, plab$indicator_code)]
pooled$panel_label <- factor(pooled$panel_label, levels = plab$short[order(plab$indicator_code)])
chi_pool$panel_label <- factor(plab$short[match(chi_pool$indicator_code, plab$indicator_code)],
                               levels = levels(pooled$panel_label))

## figure 1/2: histograms and log-scale histograms of the curated columns
pv <- panel[panel$indicator_code %in% plab$indicator_code, ]
pv <- pv[is.finite(pv$value) & pv$value > 0, ]
pv$panel_label <- factor(plab$short[match(pv$indicator_code, plab$indicator_code)],
                         levels = levels(pooled$panel_label))
g1 <- ggplot2::ggplot(pv, ggplot2::aes(x = value)) +
  ggplot2::geom_histogram(bins = 40, fill = CB[["observed"]], colour = "white") +
  ggplot2::facet_wrap(~panel_label, scales = "free", ncol = 3) +
  ggplot2::labs(title = paste("Histograms of the curated columns (pooled country-years)"),
                subtitle = syn_note, x = "value (native units)", y = "count") + th
ggplot2::ggsave(file.path(FIGURES, "fig_descriptives_histograms.png"), g1,
                width = 11, height = 7, dpi = 150, bg = "white")

g2 <- ggplot2::ggplot(pv, ggplot2::aes(x = log10(value))) +
  ggplot2::geom_histogram(bins = 40, fill = CB[["alt"]], colour = "white") +
  ggplot2::facet_wrap(~panel_label, scales = "free_y", ncol = 3) +
  ggplot2::labs(title = "Log10-scale histograms (Benford-conforming data are roughly uniform on this scale)",
                subtitle = syn_note, x = "log10(value)", y = "count") + th
ggplot2::ggsave(file.path(FIGURES, "fig_descriptives_log_histograms.png"), g2,
                width = 11, height = 7, dpi = 150, bg = "white")

## figure 3: observed vs expected first-digit distribution
g3 <- ggplot2::ggplot(pooled, ggplot2::aes(x = factor(digit))) +
  ggplot2::geom_col(ggplot2::aes(y = observed_proportion, fill = "Observed"),
                    position = ggplot2::position_dodge(width = 0.9)) +
  ggplot2::geom_point(ggplot2::aes(y = expected_proportion, colour = "Benford expected"), size = 2) +
  ggplot2::geom_line(ggplot2::aes(y = expected_proportion, colour = "Benford expected", group = 1),
                     linewidth = 0.7) +
  ggplot2::facet_wrap(~panel_label, ncol = 3) +
  ggplot2::scale_fill_manual("", values = c(Observed = CB[["observed"]])) +
  ggplot2::scale_colour_manual("", values = c("Benford expected" = CB[["expected"]])) +
  ggplot2::scale_y_continuous(labels = pct_lab) +
  ggplot2::labs(title = "Observed vs Benford-expected first-digit proportions (pooled country-years)",
                subtitle = syn_note, x = "first significant digit", y = "proportion") + th
ggplot2::ggsave(file.path(FIGURES, "fig_observed_vs_expected.png"), g3,
                width = 11, height = 7, dpi = 150, bg = "white")

## figure 4: standardised residuals per digit
g4 <- ggplot2::ggplot(pooled, ggplot2::aes(x = factor(digit), y = pearson_residual)) +
  ggplot2::geom_col(fill = CB[["observed"]]) +
  ggplot2::geom_hline(yintercept = c(-1.96, 1.96), linetype = "dashed",
                      colour = CB[["expected"]]) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.3) +
  ggplot2::facet_wrap(~panel_label, ncol = 3) +
  ggplot2::labs(title = "Standardised (Pearson) residuals by first digit",
                subtitle = paste(syn_note, "| dashed lines mark +/- 1.96 (screening heuristic)"),
                x = "first significant digit", y = "(O - E) / sqrt(E)") + th
ggplot2::ggsave(file.path(FIGURES, "fig_residuals_by_digit.png"), g4,
                width = 11, height = 7, dpi = 150, bg = "white")

## figure 5: MAD comparison with Nigrini bands
chi_pool$panel_label_ord <- stats::reorder(chi_pool$panel_label, chi_pool$mad)
g5 <- ggplot2::ggplot(chi_pool, ggplot2::aes(x = panel_label_ord, y = mad,
                                             fill = indicator_role)) +
  ggplot2::geom_col() +
  ggplot2::geom_hline(yintercept = 0.006, linetype = "dotted") +
  ggplot2::geom_hline(yintercept = 0.012, linetype = "dashed") +
  ggplot2::geom_hline(yintercept = 0.015, linetype = "solid") +
  ggplot2::annotate("text", x = 0.6, y = 0.0065, hjust = 0, size = 2.6,
                    label = "0.006 close conformity") +
  ggplot2::annotate("text", x = 0.6, y = 0.0125, hjust = 0, size = 2.6,
                    label = "0.012 acceptable") +
  ggplot2::annotate("text", x = 0.6, y = 0.0155, hjust = 0, size = 2.6,
                    label = "0.015 marginal") +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual("", values = c("benford-plausible" = CB[["observed"]],
                                            "negative control" = CB[["warn"]],
                                            "secondary (optional)" = CB[["neutral"]])) +
  ggplot2::labs(title = "First-digit MAD against the Nigrini conformity bands (pooled country-years)",
                subtitle = syn_note, x = NULL, y = "mean absolute deviation (MAD)") + th
ggplot2::ggsave(file.path(FIGURES, "fig_mad_comparison.png"), g5,
                width = 10, height = 5, dpi = 150, bg = "white")

## figure 6: region / subset comparison of MAD
reg <- A$chi_square[A$chi_square$unit_type == "region", ]
reg$panel_label <- factor(plab$short[match(reg$indicator_code, plab$indicator_code)],
                          levels = levels(pooled$panel_label))
reg$flag_mark <- ifelse(!is.na(reg$p_bh) & reg$p_bh < ALPHA, "+", "")
g6 <- ggplot2::ggplot(reg, ggplot2::aes(x = group_value, y = panel_label, fill = mad)) +
  ggplot2::geom_tile(colour = "white") +
  ggplot2::geom_text(ggplot2::aes(label = paste0(flag_mark, "\n", sprintf("%.3f", mad))),
                     size = 2.2, colour = "black") +
  ggplot2::scale_fill_viridis_c("MAD", option = "viridis") +
  ggplot2::labs(title = "MAD by region and indicator ('+' = adjusted p < 0.05)",
                subtitle = paste(syn_note, "| flags are review prompts, never proof of fraud"),
                x = NULL, y = NULL) +
  th + ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 7),
                      legend.position = "right")
ggplot2::ggsave(file.path(FIGURES, "fig_region_mad.png"), g6,
                width = 11, height = 6, dpi = 150, bg = "white")

## figure 7: detection-rate curves
S <- EXP$summary
S$manip_label <- factor(manipulation_labels()[S$manipulation],
                        levels = unname(manipulation_labels()))
g7 <- ggplot2::ggplot(S, ggplot2::aes(x = true_alteration_rate, y = detection_rate)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = pmax(0, detection_rate - detection_se),
                                    ymax = pmin(1, detection_rate + detection_se)),
                       alpha = 0.2, fill = CB[["observed"]]) +
  ggplot2::geom_line(colour = CB[["observed"]], linewidth = 0.9) +
  ggplot2::geom_point(colour = CB[["observed"]], size = 2) +
  ggplot2::geom_hline(yintercept = ALPHA, linetype = "dashed", colour = CB[["expected"]]) +
  ggplot2::facet_wrap(~manip_label) +
  ggplot2::scale_x_continuous(labels = pct_lab) +
  ggplot2::scale_y_continuous(labels = pct_lab, limits = c(0, 1)) +
  ggplot2::labs(title = "Detection rate of the first-digit chi-square test vs true alteration rate",
                subtitle = "SYNTHETIC manipulation experiment | dashed line = alpha = 0.05 | error bars = +/- 1 SE",
                x = "true fraction of records altered", y = "proportion of replicates flagged (p < 0.05)") + th
ggplot2::ggsave(file.path(FIGURES, "fig_experiment_detection_curves.png"), g7,
                width = 11, height = 4.5, dpi = 150, bg = "white")

## figure 8: MAD boxplots
REP <- EXP$replicates
REP$manip_label <- factor(manipulation_labels()[REP$manipulation],
                          levels = unname(manipulation_labels()))
REP$level_f <- factor(sprintf("%.0f%%", 100 * REP$true_alteration_rate),
                      levels = sprintf("%.0f%%", 100 * EXP$levels))
g8 <- ggplot2::ggplot(REP, ggplot2::aes(x = level_f, y = mad)) +
  ggplot2::geom_boxplot(fill = CB[["alt"]], outlier.size = 0.4) +
  ggplot2::geom_hline(yintercept = 0.006, linetype = "dashed", colour = CB[["expected"]]) +
  ggplot2::facet_wrap(~manip_label) +
  ggplot2::labs(title = "MAD versus true alteration level by manipulation type",
                subtitle = "SYNTHETIC experiment | dashed line = 0.006 close-conformity band",
                x = "true fraction of records altered", y = "first-digit MAD") + th
ggplot2::ggsave(file.path(FIGURES, "fig_experiment_mad_boxplots.png"), g8,
                width = 11, height = 4.5, dpi = 150, bg = "white")

## figure 9: regression of MAD on the true alteration rate
reglabs <- REG
reglabs$manip_label <- factor(manipulation_labels()[reglabs$manipulation],
                              levels = unname(manipulation_labels()))
reglabs$lab <- sprintf("y = %.4f + %.4f x\nR2 = %.3f, p = %s",
                       reglabs$intercept, reglabs$slope, reglabs$r_squared,
                       vapply(reglabs$p_value, format_p, character(1)))
g9 <- ggplot2::ggplot(REP, ggplot2::aes(x = true_alteration_rate, y = mad)) +
  ggplot2::geom_point(alpha = 0.25, colour = CB[["observed"]], size = 0.8) +
  ggplot2::geom_smooth(method = "lm", formula = y ~ x, colour = CB[["expected"]],
                       fill = CB[["expected"]], alpha = 0.15) +
  ggplot2::geom_text(data = reglabs, ggplot2::aes(x = 0.02, y = Inf, label = lab),
                     inherit.aes = FALSE, hjust = 0, vjust = 1.2, size = 2.8) +
  ggplot2::facet_wrap(~manip_label) +
  ggplot2::scale_x_continuous(labels = pct_lab) +
  ggplot2::labs(title = "Regression of the screening measure (MAD) on the true alteration rate",
                subtitle = "SYNTHETIC experiment | dose-response of the measure, not evidence about real data",
                x = "true fraction of records altered", y = "first-digit MAD") + th
ggplot2::ggsave(file.path(FIGURES, "fig_experiment_regression.png"), g9,
                width = 11, height = 4.5, dpi = 150, bg = "white")
step("  figures written to ", FIGURES)

## ============================================================== 6. manifest
step("Writing the data manifest ...")
raw_present <- !is.na(panel_info$source_file) && file.exists(panel_info$source_file)
mtime <- if (raw_present) format(file.info(panel_info$source_file)$mtime, "%Y-%m-%d %H:%M:%S") else NA_character_
codes_present <- unique(panel$indicator_code)
manifest <- data.frame(
  field = c("source_name", "source_url", "landing_page", "local_main_file", "local_country_file",
            "download_attempted", "download_date_or_file_timestamp", "is_synthetic",
            "selected_indicator_codes", "indicator_codes_missing",
            "rows_panel_before_cleaning", "rows_panel_after_cleaning",
            "row_counts_before_cleaning_wide", "cleaning_decisions", "terms_of_use_note",
            "optional_secondary_dataset", "limitations"),
  value = c(
    if (IS_SYNTHETIC) "SYNTHETIC - NOT REAL DATA (fallback panel, no WDI file found)" else "World Bank World Development Indicators (WDI) bulk CSV",
    "https://databankfiles.worldbank.org/public/ddpext_download/WDI_CSV.zip",
    "https://databank.worldbank.org/source/world-development-indicators",
    if (raw_present) panel_info$source_file else "not found (no download attempted in this run)",
    if (!is.na(panel_info$country_file)) panel_info$country_file else "not found",
    if (IS_SYNTHETIC) "no (a local WDI copy was searched first, no download was performed)" else "no (a local copy of the WDI bulk CSV was found in the workspace)",
    if (raw_present) paste0("not downloaded; local file timestamp ", mtime) else "not downloaded",
    as.character(IS_SYNTHETIC),
    paste(codes_present, collapse = "; "),
    if (length(panel_info$codes_missing)) paste(panel_info$codes_missing, collapse = "; ") else "none",
    if (is.na(panel_info$rows_before)) "not applicable (synthetic fallback)" else as.character(panel_info$rows_before),
    as.character(nrow(panel)),
    if (is.na(panel_info$rows_before)) "not applicable (synthetic fallback)" else as.character(nrow(panel)),
    "Wide to long via tidyr::pivot_longer; non-numeric fields removed; empty cells dropped; only country ids with a non-empty Region in WDICountry.csv kept (so World/region/income-group aggregates are removed); zeros, NA/NaN, Inf and non-numeric text excluded from digit analysis; negatives analysed by magnitude (see cleaning_exclusions.csv)",
    "The WDI bulk file is published by the World Bank as open data; confirm the current terms on the World Bank Data Terms of Use page before redistribution (https://www.worldbank.org/en/about/legal/terms-of-use).",
    "USASpending.gov bulk data are optional and were not required; if a CSV is placed in data/raw/usaspending/ the pipeline analyses its amount columns by magnitude.",
    "Pooled country-years are not independent (the same country appears in many years), so pooled p-values are optimistic; Benford's Law is a screening heuristic, not proof of fraud; bounded indicators (life expectancy, fertility) are expected to deviate."),
  stringsAsFactors = FALSE)
utils::write.csv(manifest, file.path(TABLES, "data_manifest.csv"), row.names = FALSE)

md <- c(paste0("# DATA MANIFEST - ", if (IS_SYNTHETIC) "SYNTHETIC - NOT REAL DATA" else "World Bank WDI"),
        "", paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
        "", "| field | value |", "|---|---|",
        sprintf("| %s | %s |", manifest$field, gsub("|", "/", manifest$value, fixed = TRUE)),
        "", "## Notes", "",
        paste0("- ", panel_info$notes),
        "", "## What the student must do", "",
        "1. Download https://databankfiles.worldbank.org/public/ddpext_download/WDI_CSV.zip",
        "2. Place it at `data/raw/WDI_CSV.zip` (or unzip it to `data/raw/wdi/`).",
        "3. Re-run `Rscript scripts/run_all.R`; the pipeline picks it up automatically.",
        "4. Optional: export a small USASpending subset from https://www.usaspending.gov/download_center",
        "   (one fiscal year, one award type) into `data/raw/usaspending/`.")
writeLines(md, file.path(ROOT, "data", "DATA_MANIFEST.md"))
step("  manifest written")

## ============================================================== 7. report
report_html <- file.path(ROOT, "reports", "benford_report.html")
report_docx <- file.path(ROOT, "reports", "benford_report.docx")
report_status <- "skipped (--no-report)"
if (!no_report) {
  step("Rendering the report ...")
  rmd <- file.path(ROOT, "reports", "benford_report.Rmd")
  if (!file.exists(rmd)) {
    report_status <- "Rmd source missing"
  } else if (!PANDOC_OK) {
    report_status <- "pandoc not found: rmarkdown cannot render HTML or DOCX"
    step("  ", report_status)
  } else {
    out_dir_abs <- normalizePath(OUT_ROOT, winslash = "/")
    ok <- tryCatch({
      rmarkdown::render(rmd, output_format = "html_document",
                        output_file = basename(report_html),
                        output_dir = dirname(report_html),
                        params = list(out_dir = out_dir_abs), quiet = TRUE)
      TRUE
    }, error = function(e) { step("  HTML render failed: ", conditionMessage(e)); FALSE })
    report_status <- if (ok) "HTML created" else "HTML render failed"
    ok2 <- tryCatch({
      rmarkdown::render(rmd, output_format = "word_document",
                        output_file = basename(report_docx),
                        output_dir = dirname(report_docx),
                        params = list(out_dir = out_dir_abs), quiet = TRUE)
      TRUE
    }, error = function(e) { step("  DOCX render failed: ", conditionMessage(e)); FALSE })
    if (ok2) report_status <- paste(report_status, "+ DOCX created")
    step("  report status: ", report_status)
  }
}

## ====================================================== 8. verify and summarise
step("Verifying mandatory outputs ...")
required <- c(
  file.path(TABLES, c("descriptive_statistics.csv", "cleaning_exclusions.csv",
                      "suitability_summary.csv", "benford_expected_probabilities.csv",
                      "first_digit_frequency.csv", "chi_square_results.csv",
                      "anomaly_flags.csv", "two_digit_results.csv",
                      "experiment_replicates.csv", "experiment_summary.csv",
                      "anova_results.csv", "regression_results.csv", "data_manifest.csv")),
  file.path(FIGURES, c("fig_descriptives_histograms.png", "fig_descriptives_log_histograms.png",
                       "fig_observed_vs_expected.png", "fig_residuals_by_digit.png",
                       "fig_mad_comparison.png", "fig_region_mad.png",
                       "fig_experiment_detection_curves.png", "fig_experiment_mad_boxplots.png",
                       "fig_experiment_regression.png")))
if (!no_report) required <- c(required, report_html)
missing <- required[!file.exists(required) | file.size(required) == 0]

cat("\n================ HEADLINE RESULTS (actual numbers) ================\n")
for (key in c("latest_year", "pooled")) {
  sub <- A$chi_square[A$chi_square$unit_type == key, ]
  if (!nrow(sub)) next
  cat(sprintf("\n-- %s --\n", if (key == "latest_year") "latest complete year cross-section" else "pooled country-years"))
  for (i in seq_len(nrow(sub))) {
    cat(sprintf("%-58s N=%6d  X2=%10s df=%2d p_raw=%9s p_bh=%9s %-8s MAD=%.4f  %s\n",
                substr(sub$indicator_label[i], 1, 58), sub$n[i],
                ifelse(is.na(sub$x2[i]), "NA", sprintf("%.3f", sub$x2[i])),
                sub$df[i], format_p(sub$p_raw[i]), format_p(sub$p_bh[i]),
                sub$validity_tier[i], sub$mad[i], sub$flag[i]))
  }
}
cat("\n-- experiment summary (true alteration rate -> detection rate / mean MAD) --\n")
for (tp in unique(EXP$summary$manipulation)) {
  d <- EXP$summary[EXP$summary$manipulation == tp, ]
  cat(sprintf("%-22s ", tp),
      paste(sprintf("%3.0f%%: %.2f / %.4f", 100 * d$true_alteration_rate, d$detection_rate, d$mean_mad),
            collapse = "   "), "\n")
}
cat(sprintf("\nEmpirical type-I error at 0%% alteration (level 0 detection rate): %s\n",
            paste(sprintf("%s = %.3f", unique(EXP$summary$manipulation),
                          EXP$summary$detection_rate[EXP$summary$true_alteration_rate == 0][
                            match(unique(EXP$summary$manipulation),
                                  EXP$summary$manipulation[EXP$summary$true_alteration_rate == 0])]),
                  collapse = " | ")))
cat(sprintf("alpha = %.3f | total replicates = %d\n", ALPHA, nrow(EXP$replicates)))

cat("\n================ FILE CHECK ================\n")
if (length(missing)) {
  cat("MISSING or EMPTY outputs:\n"); cat(paste0("  - ", missing, "\n"))
} else {
  cat(sprintf("All %d mandatory outputs exist and are non-empty.\n", length(required)))
}
cat(sprintf("Report: %s\n", report_status))
cat(sprintf("Dataset: %s\n", panel_info$source_label))
cat("==================================================================\n")

if (length(missing)) quit(status = 1) else quit(status = 0)
