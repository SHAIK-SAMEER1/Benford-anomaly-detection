###############################################################################
##  tests/testthat/test-core.R
##  Test suite for the Benford's Law project (BMAT202L / BMAT202P, Slot F1).
##  Run with:  Rscript -e "testthat::test_dir('tests/testthat')"
###############################################################################

library(testthat)

.project_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:8) {
    if (file.exists(file.path(d, "R", "benford.R"))) return(d)
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  normalizePath(getwd())
}
ROOT <- .project_root()
source(file.path(ROOT, "R", "benford.R"))

REF_P1 <- c(0.30103, 0.17609, 0.12494, 0.09691, 0.07918, 0.06695, 0.05799,
            0.05115, 0.04576)

## --------------------------------------------------------------------- probs
test_that("Benford first-digit probabilities are correct", {
  p <- benford_first_probs()
  expect_equal(sum(p), 1, tolerance = 1e-12)
  expect_equal(as.numeric(p), REF_P1, tolerance = 1e-5)
  expect_equal(names(p), as.character(1:9))
})

test_that("first-two-digit and second-digit probabilities each sum to 1", {
  p2 <- benford_first2_probs()
  ps <- benford_second_probs()
  expect_equal(length(p2), 90)
  expect_equal(sum(p2), 1, tolerance = 1e-12)
  expect_equal(length(ps), 10)
  expect_equal(sum(ps), 1, tolerance = 1e-12)
  expect_equal(as.numeric(ps), c(0.1196790, 0.1138900, 0.1088210, 0.1043300,
                                 0.1003080, 0.0966772, 0.0933747, 0.0903520,
                                 0.0875701, 0.0849974), tolerance = 1e-4)
})

test_that("expected counts match the Review-1 example", {
  e <- benford_expected_counts(benford_first_probs(), 10000)
  expect_equal(unname(e[1]), 3010.3, tolerance = 0.1)
  expect_equal(unname(e[9]), 457.6, tolerance = 0.1)
})

test_that("minimum sample size thresholds are computed, not hard-coded", {
  expect_equal(min_sample_reliable(benford_first_probs()), 110)
  expect_true(min_sample_reliable(benford_first2_probs()) >= 1145 &&
                min_sample_reliable(benford_first2_probs()) <= 1150)
  expect_equal(min_sample_all_ge_1(benford_first_probs()), 22)
})

## ------------------------------------------------------------------- digits
test_that("first_digit handles integers, decimals, powers of ten and notation", {
  expect_equal(first_digit(c(123, 987)), c(1, 9))
  expect_equal(first_digit(0.00417), 4)
  expect_equal(first_digit(c(1000, 0.001, 9999.999)), c(1, 1, 9))
  expect_equal(first_digit(c(3.2e-7, 9.99e15)), c(3, 9))
  expect_equal(first_digit(-250), 2)
  expect_equal(first_digit(c(0, NA, NaN, Inf, -Inf)), rep(NA_real_, 5))
  expect_equal(first_digit("not a number"), NA_real_)
  expect_equal(first_digit(c(1, 2, 3), n = 2), c(10, 20, 30))
  expect_equal(first_digit(c(0.00417, 1234.5), n = 2), c(41, 12))
})

test_that("first_digit is stable at exact powers of ten", {
  expect_equal(first_digit(10^(0:15)), rep(1, 16))
  expect_equal(first_digit(10^(-(1:10))), rep(1, 10))
  expect_equal(first_digit(c(100, 1e6, 1e-6)), c(1, 1, 1))
})

test_that("second_digit extracts the second significant digit", {
  expect_equal(second_digit(c(123, 0.0987, 5, -4567)), c(2, 8, 0, 5))
  expect_equal(second_digit(1000), 0)
  expect_equal(second_digit(c(0, NA, Inf)), rep(NA_real_, 3))
})

test_that("digit_counts returns all classes with correct zeros", {
  dc <- digit_counts(c(1, 10, 100, 200, 3), "first")
  expect_equal(nrow(dc), 9)
  expect_equal(sum(dc$count), 5)
  expect_equal(dc$count[1], 3)
  expect_equal(dc$count[5], 0)
  expect_equal(sum(dc$proportion), 1, tolerance = 1e-12)
  dc2 <- digit_counts(c(10, 10, 55), "first2")
  expect_equal(nrow(dc2), 90)
  expect_equal(dc2$count[dc2$digit == "10"], 2)
})

## ----------------------------------------------------------------- cleaning
test_that("clean_numeric classifies every exclusion category", {
  x <- c(5, 0, -3, NA, NaN, Inf, "abc", 12.5)
  cl <- clean_numeric(x)
  cts <- stats::setNames(cl$counts$n, cl$counts$category)
  expect_equal(unname(cts["total_values"]), 8)
  expect_equal(unname(cts["missing_NA_NaN"]), 2)
  expect_equal(unname(cts["non_finite_Inf"]), 1)
  expect_equal(unname(cts["invalid_non_numeric"]), 1)
  expect_equal(unname(cts["zero_excluded"]), 1)
  expect_equal(unname(cts["negative_used_as_magnitude"]), 1)
  expect_equal(unname(cts["eligible_values"]), 3)
  expect_equal(cl$eligible, c(5, 3, 12.5))
  expect_equal(cl$n_eligible, 3L)
})

test_that("clean_numeric can exclude negatives instead of using magnitudes", {
  cl <- clean_numeric(c(1, -2, 3), use_magnitude = FALSE)
  expect_equal(cl$eligible, c(1, 3))
  cts <- stats::setNames(cl$counts$n, cl$counts$category)
  expect_equal(unname(cts["negative_excluded"]), 1)
  expect_equal(unname(cts["negative_used_as_magnitude"]), 0)
})

test_that("clean_numeric is graceful for empty and all-NA input", {
  expect_equal(clean_numeric(numeric(0))$n_eligible, 0L)
  expect_equal(clean_numeric(c(NA, NA))$n_eligible, 0L)
  expect_equal(clean_numeric(letters)$n_eligible, 0L)
})

test_that("describe_numeric reports the expected summary", {
  d <- describe_numeric(c(1, 2, 3, 4, 5, NA))
  expect_equal(d$n, 5)
  expect_equal(d$missing, 1)
  expect_equal(d$mean, 3)
  expect_equal(d$median, 3)
  expect_equal(d$min, 1)
  expect_equal(d$max, 5)
  expect_true(abs(d$skewness) < 1e-9)
  expect_equal(describe_numeric(numeric(0))$n, 0)
})

## ------------------------------------------------------------- chi-square
test_that("manual chi-square equals stats::chisq.test", {
  counts <- c(30, 18, 12, 10, 8, 7, 6, 5, 4)
  p <- benford_first_probs()
  ours <- chisq_benford(counts, p)
  ref  <- suppressWarnings(stats::chisq.test(x = counts, p = as.numeric(p)))
  expect_equal(ours$N, sum(counts))
  expect_equal(ours$df, 8)
  expect_equal(ours$x2, unname(ref$statistic), tolerance = 1e-8)
  expect_equal(ours$p, ref$p.value, tolerance = 1e-8)
})

test_that("chi-square equals an independent hand calculation", {
  counts <- c(30, 18, 12, 10, 8, 7, 6, 5, 4)
  E <- 100 * c(0.30103, 0.17609, 0.12494, 0.09691, 0.07918, 0.06695, 0.05799,
               0.05115, 0.04576)
  x2_hand <- sum((counts - E)^2 / E)
  ours <- chisq_benford(counts, benford_first_probs())
  expect_equal(ours$x2, x2_hand, tolerance = 1e-3)
  expect_equal(ours$df, 8)
})

test_that("perfectly Benford counts give X2 = 0 and p = 1", {
  p <- benford_first_probs()
  res <- chisq_benford(1e6 * p, p)
  expect_equal(res$x2, 0, tolerance = 1e-9)
  expect_equal(res$p, 1, tolerance = 1e-9)
  expect_equal(res$tier, "Reliable")
})

test_that("validity tiers follow the specified rules", {
  p <- benford_first_probs()
  expect_equal(chisq_benford(rep(0, 9), p)$tier, "Not run")
  expect_true(is.na(chisq_benford(rep(0, 9), p)$p))
  expect_true(nzchar(chisq_benford(rep(0, 9), p)$note))
  expect_true(is.na(chisq_benford(rep(0, 9), p)$x2))

  small <- chisq_benford(49 * p, p)
  expect_equal(small$tier, "Not run")
  expect_true(is.na(small$p))

  caution <- chisq_benford(109 * p, p)
  expect_equal(caution$tier, "Caution")
  expect_false(is.na(caution$p))
  expect_true(grepl("Cochran", caution$note))

  reliable <- chisq_benford(110 * p, p)
  expect_equal(reliable$tier, "Reliable")

  too_sparse <- chisq_benford(60 * p, p)
  expect_equal(too_sparse$tier, "Not run")

  f2 <- chisq_benford(rep(1, 90), benford_first2_probs())
  expect_equal(f2$tier, "Not run")
  expect_true(grepl("expected count", f2$note, ignore.case = TRUE))
})

test_that("MAD, residuals and Cohen's w are correct on a hand example", {
  obs <- c(0.5, 0.5)
  exp <- c(0.4, 0.6)
  expect_equal(benford_mad(obs, exp), 0.1)
  counts <- c(30, 18, 12, 10, 8, 7, 6, 5, 4)
  p <- benford_first_probs()
  res <- chisq_benford(counts, p)
  expect_equal(res$mad, mean(abs(counts / 100 - as.numeric(p))), tolerance = 1e-12)
  expect_equal(res$residuals, (counts - res$E) / sqrt(res$E), tolerance = 1e-12)
  expect_equal(res$cohen_w, sqrt(res$x2 / 100), tolerance = 1e-12)
  expect_equal(cohens_w(10, 100), sqrt(0.1), tolerance = 1e-12)
})

test_that("Nigrini band assignment is correct at the boundaries", {
  expect_equal(nigrini_band(0), "Close conformity")
  expect_equal(nigrini_band(0.006), "Close conformity")
  expect_equal(nigrini_band(0.0061), "Acceptable conformity")
  expect_equal(nigrini_band(0.012), "Acceptable conformity")
  expect_equal(nigrini_band(0.0121), "Marginal conformity")
  expect_equal(nigrini_band(0.015), "Marginal conformity")
  expect_equal(nigrini_band(0.0151), "Nonconformity")
  expect_true(is.na(nigrini_band(NA)))
})

test_that("multiple-testing adjustment equals p.adjust", {
  p <- c(0.01, 0.04, 0.03, 0.2, NA)
  adj <- adjust_family(p, "unit test family")
  expect_equal(adj$p_raw, p)
  expect_equal(adj$p_holm, stats::p.adjust(p, method = "holm"))
  expect_equal(adj$p_bh, stats::p.adjust(p, method = "BH"))
  expect_equal(unique(adj$family), "unit test family")
  expect_equal(unique(adj$family_size), 4)
})

## ------------------------------------------------------------------- flags
test_that("flag_anomaly returns each of the five categories", {
  expect_equal(flag_anomaly(FALSE, 10)$flag, "Not assessed - unsuitable data")
  expect_equal(flag_anomaly(TRUE, 10, p_adjusted = NA)$flag,
               "Not assessed - insufficient sample")
  expect_equal(flag_anomaly(TRUE, 200, p_adjusted = 0.001, mad = 0.05)$flag,
               "Statistical deviation: significant AND practically material")
  expect_equal(flag_anomaly(TRUE, 200, p_adjusted = 0.001, mad = 0.004)$flag,
               "Statistically significant but small deviation")
  expect_equal(flag_anomaly(TRUE, 200, p_adjusted = 0.30, mad = 0.05)$flag,
               "No significant deviation detected")
  interp <- flag_anomaly(TRUE, 200, p_adjusted = 0.001, mad = 0.05)$interpretation
  expect_true(grepl("not evidence of fraud", interp))
  expect_false(grepl("fraud detected", interp))
})

## ------------------------------------------------------------- suitability
test_that("suitability screening separates usable from unusable columns", {
  set.seed(11)
  good <- 10^stats::runif(400, 0, 7)
  expect_equal(suitability(good, "gdp_value")$verdict, "Suitable")
  expect_false(identical(suitability(1:400, "row_id")$verdict, "Suitable"))
  expect_false(identical(suitability(stats::runif(400, 0, 100), "score_pct")$verdict, "Suitable"))
  capped <- c(10^stats::runif(200, 0, 6), rep(1e6, 200))
  expect_false(identical(suitability(capped, "award_value")$verdict, "Suitable"))
  expect_equal(suitability(c(10^stats::runif(20, 0, 6)), "x")$verdict, "Unsuitable")
})

## ------------------------------------------------------------- experiment
test_that("the experiment is reproducible and does not mutate its control", {
  base <- synthetic_benford_base(500, seed = 7)
  before <- base
  m <- manipulate_vector(base, "round_number", rate = 0.2, seed = 3)
  expect_identical(base, before)
  expect_equal(m$n_altered, 100L)

  e1 <- run_experiment(n = 500, R = 3, levels = c(0, 0.2), seed = 42)
  e2 <- run_experiment(n = 500, R = 3, levels = c(0, 0.2), seed = 42)
  expect_identical(e1$replicates, e2$replicates)
  e3 <- run_experiment(n = 500, R = 3, levels = c(0, 0.2), seed = 43)
  expect_false(identical(e1$replicates$p, e3$replicates$p))
})

test_that("the true alteration rate is stored separately and matches the altered count", {
  base <- synthetic_benford_base(1000, seed = 5)
  e <- run_experiment(n = 1000, R = 2, levels = c(0, 0.1), seed = 99)
  expect_true(all(c("true_alteration_rate", "n_altered", "observed_alteration_rate") %in%
                    names(e$replicates)))
  lvl0 <- e$replicates[e$replicates$true_alteration_rate == 0, ]
  expect_equal(unique(lvl0$n_altered), 0L)
  expect_equal(unique(lvl0$observed_alteration_rate), 0)
  lvl1 <- e$replicates[e$replicates$true_alteration_rate == 0.1, ]
  expect_equal(unique(lvl1$n_altered), 100L)
  # the statistical columns never contain the true rate under another name
  expect_false(any(grepl("true", names(e$replicates)[!names(e$replicates) %in%
                                                     c("true_alteration_rate")])))
})

test_that("manipulation types produce the intended structural changes", {
  base <- synthetic_benford_base(2000, seed = 8)
  bias <- manipulate_vector(base, "leading_digit_bias", rate = 0.3, seed = 1)
  d <- first_digit(bias$data[bias$altered_index])
  expect_true(all(d %in% 5:9))
  rd <- manipulate_vector(base, "round_number", rate = 0.3, seed = 1)
  expect_true(all(rd$data[rd$altered_index] == round(rd$data[rd$altered_index])))
  pa <- manipulate_vector(base, "partial_alteration", rate = 0.3, seed = 1)
  ratio <- pa$data[pa$altered_index] / base[pa$altered_index]
  expect_true(all(ratio >= 0.8 & ratio <= 1.2))
})

## --------------------------------------------------------------- outliers
test_that("invalid inputs return graceful, informative results", {
  expect_silent(clean_numeric(numeric(0)))
  expect_silent(describe_numeric(numeric(0)))
  expect_silent(suitability(numeric(0), "empty column"))
  sv <- benford_test_values(numeric(0), "first")
  expect_equal(sv$N, 0)
  expect_equal(sv$tier, "Not run")
  expect_true(is.na(sv$p))
  expect_silent(benford_test_values(c(NA, NA), "first"))
  expect_silent(benford_test_values(letters, "first"))
  one <- benford_test_values(42, "first")
  expect_equal(one$N, 1)
  expect_equal(one$tier, "Not run")
  expect_equal(suitability(numeric(0), "empty")$verdict, "Unsuitable")
  expect_silent(benford_test_values(c("1", "2", "three"), "first"))
})

test_that("bootstrap MAD interval is reproducible and ordered", {
  set.seed(3)
  v <- 10^stats::runif(300, 0, 5)
  ci1 <- bootstrap_mad_ci(v, "first", B = 60, seed = 1)
  ci2 <- bootstrap_mad_ci(v, "first", B = 60, seed = 1)
  expect_identical(ci1, ci2)
  expect_true(ci1[["lower"]] <= ci1[["upper"]])
})

## ------------------------------------------------------ pipeline (end to end)
test_that("run_all.R creates every required output", {
  rscript <- local({
    cands <- c(file.path(R.home("bin"), "Rscript.exe"),
               file.path(R.home("bin"), "x64", "Rscript.exe"),
               file.path(R.home("bin"), "Rscript"),
               file.path(R.home("bin"), "x64", "Rscript"))
    hit <- cands[file.exists(cands)]
    if (length(hit)) hit[1] else "Rscript"
  })
  out_dir <- file.path(tempdir(), paste0("benford_out_", as.integer(Sys.time())))
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  old <- setwd(ROOT); on.exit(setwd(old), add = TRUE)
  status <- system2(rscript,
                    args = c(shQuote(file.path(ROOT, "scripts", "run_all.R")),
                             "--quick", "--no-report",
                             paste0("--out=", normalizePath(out_dir, winslash = "/"))),
                    stdout = FALSE, stderr = FALSE)
  expect_equal(status, 0L)

  tabs <- c("descriptive_statistics.csv", "cleaning_exclusions.csv",
            "suitability_summary.csv", "benford_expected_probabilities.csv",
            "first_digit_frequency.csv", "chi_square_results.csv",
            "anomaly_flags.csv", "two_digit_results.csv",
            "experiment_replicates.csv", "experiment_summary.csv",
            "anova_results.csv", "regression_results.csv", "data_manifest.csv")
  figs <- c("fig_descriptives_histograms.png", "fig_descriptives_log_histograms.png",
            "fig_observed_vs_expected.png", "fig_residuals_by_digit.png",
            "fig_mad_comparison.png", "fig_region_mad.png",
            "fig_experiment_detection_curves.png", "fig_experiment_mad_boxplots.png",
            "fig_experiment_regression.png")
  for (f in tabs) {
    p <- file.path(out_dir, "tables", f)
    expect_true(file.exists(p), info = f)
    expect_gt(file.size(p), 0)
  }
  for (f in figs) {
    p <- file.path(out_dir, "figures", f)
    expect_true(file.exists(p), info = f)
    expect_gt(file.size(p), 0)
  }
  ch <- utils::read.csv(file.path(out_dir, "tables", "chi_square_results.csv"))
  expect_true(all(c("x2", "df", "p_raw", "p_holm", "p_bh", "validity_tier", "mad",
                    "flag") %in% names(ch)))
  expect_true(any(ch$validity_tier == "Not run") ||
                all(ch$min_expected_count >= 1, na.rm = TRUE))
  unlink(out_dir, recursive = TRUE)
})

## ----------------------------------------------------- dashboard (headless)
test_that("the Shiny app renders a live first-digit result", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("DT")
  old <- setwd(ROOT); on.exit(setwd(old), add = TRUE)
  app <- source(file.path(ROOT, "app.R"))$value
  expect_true(inherits(app, "shiny.appobj"))
  panel <- file.path(ROOT, "data", "processed", "wdi_clean.csv")
  shiny::testServer(app, {
    src <- if (file.exists(panel)) "bundled" else "synthetic"
    session$setInputs(src = src, load = 1)
    if (identical(src, "bundled")) {
      session$setInputs(col4 = "SP.POP.TOTL", alpha = 0.05, sub_var4 = "none")
    }
    ch <- output$chi_tbl
    expect_true(is.character(ch))
    expect_match(ch, "X2")
    expect_match(ch, "validity_tier")
    expect_match(ch, "Reliable|Caution|Not run")
    dec <- output$decision
    expect_false(is.null(dec))

    # the synthetic source must raise a visible banner and still compute a result
    session$setInputs(src = "synthetic", load = 1)
    session$setInputs(col4 = "SYN.GDP", alpha = 0.05, sub_var4 = "none")
    banner <- paste(as.character(output$synth_banner), collapse = " ")
    expect_match(banner, "SYNTHETIC")
    expect_match(banner, "NOT REAL DATA")
    ch2 <- output$chi_tbl
    expect_match(ch2, "X2")
  })
})

## ------------------------------------- dataset-state regression tests
test_that("switching datasets resets selectors and never reuses an old column", {
  skip_if_not_installed("shiny")
  skip_if_not_installed("bslib")
  skip_if_not_installed("DT")
  old <- setwd(ROOT); on.exit(setwd(old), add = TRUE)
  app <- source(file.path(ROOT, "app.R"))$value
  testServer(app, {
    session$setInputs(src = "bundled", load = 1)
    session$setInputs(col4 = "SP.POP.TOTL", alpha = 0.05, sub_var4 = "none")
    c1 <- output$chi_tbl
    expect_match(c1, "SP.POP.TOTL")

    # Switch dataset while deliberately leaving col4 at the old value.  The
    # readiness guard must choose the first column of the NEW dataset.
    session$setInputs(src = "synthetic", load = 1)
    c2 <- output$chi_tbl
    expect_false(grepl("SP.POP.TOTL", c2))
    expect_match(c2, "SYN.GDP")

    # The MAD table used to error because min_n_all_ge1 was misnamed.
    expect_type(output$mad_tbl, "character")

    # The subset selector must expose real columns, not just "none".
    ui <- paste(as.character(output$sub_ui4), collapse = " ")
    expect_match(ui, "region")
    expect_match(ui, "year")
  })
})

## --------------------------------- transaction review screening tests
test_that("transaction screening is one-sided and explainable", {
  set.seed(21)
  n <- 200L
  d <- data.frame(
    transaction_key = paste0("T", seq_len(n)),
    award_id = paste0("A", seq_len(n)),
    modification = "0", transaction_no = "0",
    amount = 10^stats::runif(n, 3, 6),
    action_date = as.Date("2024-01-01") + seq_len(n),
    agency = "Agency A", naics = "123456",
    recipient = paste0("Recipient ", seq_len(n)),
    stringsAsFactors = FALSE)
  d$amount[1] <- 1e9       # clearly large peer outlier
  d$amount[2] <- 0.01      # tiny amount must NOT become a review candidate
  d$amount[3] <- NA_real_  # missing amount
  d$amount[4] <- 0         # zero amount
  d$amount[5] <- -5000     # negative amount (de-obligation)

  s <- screen_usaspending_transactions(d, min_group = 30)
  expect_equal(nrow(s), n)
  expect_true(s$review_candidate[1])
  expect_match(s$reasons[1], "robust SDs")
  expect_false(s$review_candidate[2])
  expect_true(s$missing_amount[3])
  expect_true(s$zero_amount[4])
  expect_true(s$negative_amount[5])
  expect_true(all(c("reasons", "explanation", "severity", "score") %in% names(s)))
  expect_false(any(grepl("fraud detected|is fraud|proven fraud",
                         s$explanation[s$review_candidate], ignore.case = TRUE)))

  # Duplicate transaction keys are detected as a data-quality review rule.
  d2 <- rbind(d, d[1, , drop = FALSE])
  s2 <- screen_usaspending_transactions(d2, min_group = 30)
  expect_true(any(s2$duplicate_key))
  expect_true(any(s2$review_candidate[s2$duplicate_key]))

  sm <- review_summary(s)
  expect_equal(sm$rows_scanned, n)
  expect_equal(sm$review_candidates, sum(s$review_candidate))
})

test_that("the cached USAspending transaction extract has verified fields", {
  raw <- file.path(ROOT, "data", "raw", "usaspending", "usaspending.csv")
  skip_if_not(file.exists(raw), "raw USAspending file is not present")
  tx <- load_usaspending_transactions(ROOT)
  expect_true(all(c("transaction_key", "amount", "action_date", "agency",
                    "recipient", "naics") %in% names(tx)))
  expect_gt(nrow(tx), 1000)
  expect_true(is.numeric(tx$amount))
  expect_true(inherits(tx$action_date, "Date"))
  expect_true(any(tx$amount < 0, na.rm = TRUE))
})
