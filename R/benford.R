###############################################################################
##  R/benford.R -- single core module for the Benford's Law project
##  BMAT202L Probability and Statistics + BMAT202P Probability and Statistics Lab
##  VIT Vellore, Slot F1 (Faculty: Dr. Tharasi Dilleswar)
##
##  Part A  first / second significant digit extraction
##  Part B  Benford reference distributions and expected counts
##  Part C  numeric cleaning and descriptive statistics
##  Part D  suitability screening for Benford analysis
##  Part E  chi-square goodness-of-fit, MAD, residuals, effect size, flags
##  Part F  multiple-testing adjustment helpers
##  Part G  controlled synthetic manipulation experiment
##  Part H  supplementary ANOVA / regression on the experiment output
##  Part I  World Bank WDI import (fast line filter + tidy pivot), synthetic
##          fallback, optional USASpending import
##
##  Conventions
##   * every function is pure: no global state, no printing, no plotting;
##   * every function that consumes random numbers restores the caller's RNG
##     state, so results never depend on run order;
##   * dependencies: base R, stats, readr, tidyr (referenced with :: inside the
##     functions, so sourcing this file only needs base R).
##
##  IMPORTANT INTERPRETATION BOUNDARY (project-wide, never to be removed):
##   A statistically significant deviation from Benford's Law is NOT proof of
##   fraud, fabrication or manipulation. It is a diagnostic flag for further
##   review. Legitimate explanations - constrained ranges, psychological price
##   thresholds, caps, rounding, non-multiplicative processes - must be
##   considered.
###############################################################################


## ===========================================================================
## Part A -- significant digits
## ===========================================================================

# Internal helper: the 15 significant digits of |x| as a bare digit string
# (sprintf avoids the floating point errors of log10/floor at powers of ten).
mantissa_digits <- function(x) {
  s <- sprintf("%.14e", abs(x))
  gsub("[^0-9]", "", sub("e.*$", "", s))
}

# First n significant digits of x (n = 1 -> 1..9, n = 2 -> 10..99).
# Zero, NA, NaN, Inf and non-numeric input return NA.
first_digit <- function(x, n = 1) {
  if (length(x) == 0) return(numeric(0))
  if (!is.numeric(x)) x <- suppressWarnings(as.numeric(x))
  if (length(x) == 0) return(numeric(0))
  n <- suppressWarnings(as.integer(n))
  if (length(n) != 1L || is.na(n) || n < 1L || n > 15L)
    stop("'n' must be a single integer between 1 and 15")
  out <- rep(NA_real_, length(x))
  ok <- is.finite(x) & x != 0
  if (any(ok)) out[ok] <- as.numeric(substr(mantissa_digits(x[ok]), 1L, n))
  out
}

# Second significant digit of x (0..9); invalid input returns NA.
second_digit <- function(x) {
  if (length(x) == 0) return(numeric(0))
  if (!is.numeric(x)) x <- suppressWarnings(as.numeric(x))
  if (length(x) == 0) return(numeric(0))
  out <- rep(NA_real_, length(x))
  ok <- is.finite(x) & x != 0
  if (any(ok)) out[ok] <- as.numeric(substr(mantissa_digits(x[ok]), 2L, 2L))
  out
}


## ===========================================================================
## Part B -- Benford reference distributions
## ===========================================================================

# First-digit probabilities P(d) = log10(1 + 1/d), d = 1..9 (sums to 1).
benford_first_probs <- function() {
  d <- 1:9
  p <- log10(1 + 1 / d)
  names(p) <- as.character(d)
  p
}

# First-two-digit probabilities P(d1d2) = log10(1 + 1/n), n = 10..99 (sums to 1).
benford_first2_probs <- function() {
  v <- 10:99
  p <- log10(1 + 1 / v)
  names(p) <- sprintf("%02d", v)
  p
}

# Second-digit probabilities P2(j) = sum_k log10(1 + 1/(10k + j)), j = 0..9.
benford_second_probs <- function() {
  j <- 0:9
  p <- vapply(j, function(jj) sum(log10(1 + 1 / (10 * (1:9) + jj))), numeric(1))
  names(p) <- as.character(j)
  p
}

# Expected counts E = N * P for any Benford probability vector.
benford_expected_counts <- function(probs, n) {
  e <- as.numeric(n) * as.numeric(probs)
  names(e) <- names(probs)
  e
}

# Data frame of all three theoretical distributions (long format, for export).
benford_probability_table <- function() {
  f1 <- benford_first_probs()
  f2 <- benford_first2_probs()
  s2 <- benford_second_probs()
  rbind(
    data.frame(kind = "first_digit", digit = names(f1), probability = as.numeric(f1),
               formula = "log10(1 + 1/d)", stringsAsFactors = FALSE),
    data.frame(kind = "first_two_digits", digit = names(f2), probability = as.numeric(f2),
               formula = "log10(1 + 1/(10*d1+d2))", stringsAsFactors = FALSE),
    data.frame(kind = "second_digit", digit = names(s2), probability = as.numeric(s2),
               formula = "sum_k log10(1 + 1/(10*k+j))", stringsAsFactors = FALSE))
}


## ===========================================================================
## Part C -- cleaning and descriptive statistics
## ===========================================================================

# Clean a numeric-ish vector and classify every value.  Blank strings and the
# usual missing-value markers ("", NA, NaN, N/A, na, null, ".", "..", "-") are
# classified as missing; any other non-numeric text is classified as invalid.
# Returns the eligible magnitudes plus a per-category exclusion count table.
clean_numeric <- function(x, use_magnitude = TRUE) {
  if (is.factor(x)) x <- as.character(x)
  n_total <- length(x)
  missing_markers <- c("", "na", "nan", "n/a", "null", ".", "..", "-")
  was_missing <- is.na(x)
  if (!is.numeric(x)) {
    xs <- trimws(as.character(x))
    was_missing <- was_missing | (!is.na(xs) & tolower(xs) %in% missing_markers)
  }
  xn <- suppressWarnings(as.numeric(x))
  is_missing  <- is.na(xn) & was_missing       # NA / NaN
  is_invalid  <- is.na(xn) & !was_missing      # non-numeric text ("n/a", "..", "abc")
  is_infinite <- !is.na(xn) & is.infinite(xn)  # Inf / -Inf
  is_zero     <- !is.na(xn) & !is.infinite(xn) & xn == 0
  is_negative <- !is.na(xn) & !is.infinite(xn) & xn < 0
  keep <- !is.na(xn) & !is.infinite(xn) & xn != 0
  if (!use_magnitude) keep <- keep & !is_negative
  values <- if (use_magnitude) abs(xn[keep]) else xn[keep]
  counts <- data.frame(
    category = c("total_values", "missing_NA_NaN", "non_finite_Inf",
                 "invalid_non_numeric", "zero_excluded", "negative_used_as_magnitude",
                 "negative_excluded", "eligible_values"),
    n = as.integer(c(n_total, sum(is_missing), sum(is_infinite), sum(is_invalid),
                     sum(is_zero),
                     if (use_magnitude) sum(is_negative) else 0L,
                     if (use_magnitude) 0L else sum(is_negative),
                     length(values))),
    stringsAsFactors = FALSE)
  list(eligible = values, n_eligible = length(values),
       n_negative = as.integer(sum(is_negative)), counts = counts)
}

# Moment coefficient of skewness (base R only, no package).
moment_skewness <- function(v) {
  v <- v[is.finite(v)]
  m <- mean(v)
  m2 <- mean((v - m)^2)
  if (length(v) < 3L || !is.finite(m2) || m2 <= 0) return(NA_real_)
  mean((v - m)^3) / m2^1.5
}

# One-row descriptive summary of a numeric-ish vector (non-finite values counted as missing).
describe_numeric <- function(x) {
  xn <- suppressWarnings(as.numeric(x))
  v  <- xn[is.finite(xn)]
  n  <- length(v)
  if (n == 0L) {
    return(list(n = 0L, missing = length(xn), min = NA_real_, max = NA_real_,
                mean = NA_real_, median = NA_real_, sd = NA_real_, q1 = NA_real_,
                q3 = NA_real_, skewness = NA_real_, range_orders = NA_real_,
                pct_unique = NA_real_))
  }
  mn <- min(v)
  mx <- max(v)
  list(n = n,
       missing = sum(!is.finite(xn)),
       min = mn,
       max = mx,
       mean = mean(v),
       median = stats::median(v),
       sd = if (n > 1L) stats::sd(v) else NA_real_,
       q1 = as.numeric(stats::quantile(v, 0.25, names = FALSE)),
       q3 = as.numeric(stats::quantile(v, 0.75, names = FALSE)),
       skewness = moment_skewness(v),
       range_orders = if (mn > 0) log10(mx / mn) else NA_real_,
       pct_unique = length(unique(v)) / n)
}


## ===========================================================================
## Part D -- suitability screening
## ===========================================================================

# Screen a column for Benford suitability.
# Returns list(score, max_score, reasons, verdict) with
# verdict in {"Suitable", "Use with caution", "Unsuitable"}.
suitability <- function(x, name = "") {
  if (is.null(name) || length(name) == 0L || is.na(name[1])) name <- ""
  name <- as.character(name)[1]
  cl <- clean_numeric(x)
  v  <- cl$eligible
  n  <- length(v)
  a  <- abs(v)
  reasons <- character(0)
  hard    <- character(0)
  pts     <- 0

  ## sample size -------------------------------------------------------------
  if (n >= 110L) {
    pts <- pts + 2
    reasons <- c(reasons, sprintf("large sample (N = %d, enough for all expected counts >= 5)", n))
  } else if (n >= 50L) {
    pts <- pts + 1
    reasons <- c(reasons, sprintf("moderate sample (N = %d); first-digit test usable, flagged as caution", n))
  } else {
    reasons <- c(reasons, sprintf("very small sample (N = %d, below the minimum of 50)", n))
    hard <- c(hard, "fewer than 50 eligible values")
  }

  ## dynamic range -----------------------------------------------------------
  rng <- if (n > 0L && min(a) > 0) log10(max(a) / min(a)) else NA_real_
  if (is.finite(rng)) {
    if (rng >= 3) {
      pts <- pts + 2
      reasons <- c(reasons, sprintf("spans %.2f orders of magnitude (3 or more is ideal)", rng))
    } else if (rng >= 2) {
      pts <- pts + 1
      reasons <- c(reasons, sprintf("spans %.2f orders of magnitude (limited, 2-3)", rng))
    } else {
      reasons <- c(reasons, sprintf("spans only %.2f orders of magnitude (fewer than 2)", rng))
      hard <- c(hard, "range spans fewer than 2 orders of magnitude")
    }
  }

  ## positive skew -----------------------------------------------------------
  if (n > 0L) {
    m <- mean(v); md <- stats::median(v)
    if (is.finite(m) && is.finite(md) && m > md) {
      pts <- pts + 1
      reasons <- c(reasons, "right-skewed (mean > median), as Benford-conforming data usually is")
    } else {
      reasons <- c(reasons, "not right-skewed (mean <= median); Benford is a poor reference")
    }
  }

  ## uniqueness --------------------------------------------------------------
  pct_unique <- if (n > 0L) length(unique(v)) / n else NA_real_
  if (is.finite(pct_unique)) {
    if (pct_unique >= 0.9) {
      pts <- pts + 1
      reasons <- c(reasons, sprintf("%.0f%% unique values", 100 * pct_unique))
    } else {
      reasons <- c(reasons, sprintf("only %.0f%% unique values (many ties)", 100 * pct_unique))
    }
  }
  is_integer_like <- n > 0L && all(abs(v - round(v)) < 1e-9)
  n_unique <- length(unique(v))
  if (is_integer_like && n_unique <= 20L) {
    reasons <- c(reasons, sprintf("integer-valued with only %d distinct values (code / ID / rank like)", n_unique))
    hard <- c(hard, "few distinct integer values (code, ID or rank like)")
  }
  if (is_integer_like && n_unique > 1L) {
    step <- min(diff(sort(unique(v))))
    if (is.finite(step) && step == 1 && (max(v) - min(v)) < 5000) {
      reasons <- c(reasons, "integer values form a consecutive run (row index / serial number like)")
      hard <- c(hard, "consecutive integer sequence (row index or serial number like)")
    }
  }

  ## bounded / percentage-like ----------------------------------------------
  bounded <- n > 0L && (max(a) <= 100 + 1e-9 || max(a) <= 1 + 1e-9)
  if (bounded) {
    reasons <- c(reasons, sprintf("bounded values (maximum %.4g): percentage-like or capped scale", max(a)))
    hard <- c(hard, "bounded range (percentage-like or capped)")
  } else {
    pts <- pts + 1
    reasons <- c(reasons, "unbounded above, so several orders of magnitude are possible")
  }

  ## hard cap / ceiling ------------------------------------------------------
  prop_max <- if (n > 0L) mean(a == max(a)) else NA_real_
  if (is.finite(prop_max) && prop_max >= 0.05) {
    reasons <- c(reasons, sprintf("hard ceiling: %.1f%% of values equal the maximum", 100 * prop_max))
    hard <- c(hard, "hard ceiling (at least 5% of values sit exactly at the maximum)")
  } else {
    pts <- pts + 1
    reasons <- c(reasons, "no hard ceiling detected")
  }

  ## heavy rounding ----------------------------------------------------------
  share_round <- if (n > 0L) mean((a >= 1000) & (a %% 1000 == 0)) else NA_real_
  if (is.finite(share_round) && share_round > 0.5) {
    reasons <- c(reasons, sprintf("heavy rounding: %.0f%% of values are multiples of 1000", 100 * share_round))
  } else {
    pts <- pts + 1
    reasons <- c(reasons, "no heavy rounding detected")
  }

  ## suspicious column name --------------------------------------------------
  id_pattern <- "(^|_|[[:space:]])(id|code|zip|postal|phone|year|date|index|rank|serial)(_|[[:space:]]|$)"
  if (nzchar(name) && grepl(id_pattern, tolower(name))) {
    reasons <- c(reasons, sprintf("column name '%s' looks like an identifier or a year/date field", name))
    hard <- c(hard, "column name looks like an identifier, year or date field")
  }

  if (n < 110L) reasons <- c(reasons,
    "sample size is below the 110 values needed for every expected count to reach 5, so the verdict is capped at 'Use with caution'")

  verdict <- if (length(hard) > 0L) "Unsuitable"
             else if (pts >= 6 && n >= 110L) "Suitable"
             else if (pts >= 3) "Use with caution"
             else "Unsuitable"

  list(score = pts, max_score = 9L, reasons = reasons, hard_failures = hard,
       verdict = verdict, n_eligible = n, range_orders = rng,
       pct_unique = pct_unique)
}


## ===========================================================================
## Part E -- chi-square goodness-of-fit, residuals, MAD, flags
## ===========================================================================

# Observed digit counts for a chosen digit class, aligned to the class labels.
digit_counts <- function(values, kind = c("first", "first2", "second")) {
  kind <- match.arg(kind)
  if (identical(kind, "first")) {
    d <- first_digit(values, n = 1); labs <- as.character(1:9)
  } else if (identical(kind, "first2")) {
    d <- first_digit(values, n = 2); labs <- sprintf("%02d", 10:99)
  } else {
    d <- second_digit(values); labs <- as.character(0:9)
  }
  d <- d[!is.na(d)]
  cnt <- as.numeric(table(factor(as.character(d), levels = labs)))
  data.frame(digit = labs, count = cnt,
             proportion = if (length(d) > 0) cnt / length(d) else rep(NA_real_, length(labs)),
             stringsAsFactors = FALSE)
}

# Standardised (Pearson) residuals (O - E) / sqrt(E).
pearson_residuals <- function(observed, expected) {
  ifelse(expected > 0, (observed - expected) / sqrt(expected), NA_real_)
}

# Mean absolute deviation between observed and expected proportions.
benford_mad <- function(observed_prop, expected_prop) {
  if (length(observed_prop) == 0) return(NA_real_)
  mean(abs(as.numeric(observed_prop) - as.numeric(expected_prop)))
}

# Nigrini first-digit MAD bands (first digit only -- not for first-two or second digit).
nigrini_band <- function(mad) {
  if (length(mad) != 1L || is.na(mad)) return(NA_character_)
  if (mad <= 0.006) "Close conformity"
  else if (mad <= 0.012) "Acceptable conformity"
  else if (mad <= 0.015) "Marginal conformity"
  else "Nonconformity"
}

# Cohen's w effect size for a chi-square goodness-of-fit test.
cohens_w <- function(x2, n) if (is.na(x2) || is.na(n) || n <= 0) NA_real_ else sqrt(x2 / n)

# Minimum sample size for a "reliable" test (all expected counts >= 5) and for
# any expected count >= 1, both computed from the probability vector itself.
min_sample_reliable  <- function(probs) as.integer(ceiling(5 / min(as.numeric(probs))))
min_sample_all_ge_1  <- function(probs) as.integer(ceiling(1 / min(as.numeric(probs))))

# Pearson chi-square goodness-of-fit against a Benford probability vector.
# The statistic is computed manually; stats::chisq.test is only used by the
# test-suite to cross-check it.  Returns every quantity the project reports.
chisq_benford <- function(counts, probs, alpha = 0.05,
                          kind = "first", min_n = 50L) {
  counts <- as.numeric(counts)
  probs  <- as.numeric(probs)
  if (length(counts) != length(probs))
    stop("counts and probs must have the same length")
  if (any(probs <= 0)) stop("all probabilities must be positive")
  N  <- sum(counts)
  E  <- N * probs
  df <- length(probs) - 1L
  pct_below5 <- mean(E < 5)
  x2 <- if (N > 0) sum((counts - E)^2 / E) else NA_real_
  p  <- stats::pchisq(x2, df, lower.tail = FALSE)

  ## validity tier -----------------------------------------------------------
  if (N < min_n) {
    tier <- "Not run"
    note <- sprintf("N = %d is below the minimum of %d, so no valid chi-square p-value is reported.", N, min_n)
    x2 <- NA_real_; p <- NA_real_
  } else if (any(E < 1)) {
    tier <- "Not run"
    note <- sprintf("The smallest expected count is %.2f (< 1). At least N = %d is needed for this digit class.",
                    min(E), min_sample_all_ge_1(probs))
    x2 <- NA_real_; p <- NA_real_
  } else if (all(E >= 5)) {
    tier <- "Reliable"
    note <- "Every expected count is at least 5 (validity condition satisfied)."
  } else if (pct_below5 <= 0.2) {
    tier <- "Caution"
    note <- sprintf("%.0f%% of the cells have an expected count below 5 (Cochran's rule is met, result is usable with caution).",
                    100 * pct_below5)
  } else {
    tier <- "Not run"
    note <- sprintf("%.0f%% of the cells have an expected count below 5, which is more than the 20%% allowed by Cochran's rule.",
                    100 * pct_below5)
    x2 <- NA_real_; p <- NA_real_
  }

  ## decision in plain language (never alleges wrongdoing) -------------------
  decision <- if (is.na(p)) {
    "Not run: no valid p-value for this sample size."
  } else if (p < alpha) {
    sprintf("Reject H0 (p = %.4g < alpha = %.3g): the observed digit distribution differs significantly from Benford's Law.", p, alpha)
  } else {
    sprintf("Fail to reject H0 (p = %.4g >= alpha = %.3g): no significant difference from Benford's Law was detected.", p, alpha)
  }

  obs_prop <- if (N > 0) counts / N else rep(NA_real_, length(counts))
  exp_prop <- probs
  resid    <- pearson_residuals(counts, E)
  mad      <- benford_mad(obs_prop, exp_prop)

  list(kind = kind, N = N, df = df, x2 = x2, p = p, E = E,
       observed = counts, observed_prop = obs_prop, expected_prop = exp_prop,
       residuals = resid, notable = abs(resid) > 1.96,
       pct_cells_E_lt5 = pct_below5, min_E = min(E),
       tier = tier, note = note, decision = decision,
       mad = mad, band = if (identical(kind, "first")) nigrini_band(mad) else NA_character_,
       cohen_w = cohens_w(x2, N),
       min_n_reliable = min_sample_reliable(probs),
       min_n_all_ge1 = min_sample_all_ge_1(probs),
       alpha = alpha)
}

# Convenience wrapper: run the whole first / first-two / second digit test on
# a vector of values.
benford_test_values <- function(values, kind = c("first", "first2", "second"),
                                alpha = 0.05, min_n = 50L) {
  kind <- match.arg(kind)
  probs <- switch(kind,
                  first  = benford_first_probs(),
                  first2 = benford_first2_probs(),
                  second = benford_second_probs())
  freq <- digit_counts(values, kind)
  res  <- chisq_benford(freq$count, probs, alpha = alpha, kind = kind, min_n = min_n)
  res$frequency <- freq
  res
}

# Bootstrap confidence interval for the first-digit MAD (B resamples, fixed seed).
bootstrap_mad_ci <- function(values, kind = "first", B = 1000, seed = 2025L, conf = 0.95) {
  kind  <- match.arg(kind, c("first", "first2", "second"))
  probs <- switch(kind, first = benford_first_probs(), first2 = benford_first2_probs(),
                  second = benford_second_probs())
  exp_prop <- as.numeric(probs)
  d <- switch(kind,
              first  = first_digit(values, n = 1),
              first2 = first_digit(values, n = 2),
              second = second_digit(values))
  d <- d[!is.na(d)]
  n <- length(d)
  if (n < 2L || B < 2L) return(c(lower = NA_real_, upper = NA_real_, B = 0))
  labs <- switch(kind, first = as.character(1:9), first2 = sprintf("%02d", 10:99),
                 second = as.character(0:9))
  stat <- function(idx) {
    cnt <- as.numeric(table(factor(as.character(d[idx]), levels = labs))) / length(idx)
    mean(abs(cnt - exp_prop))
  }
  vals <- with_seed(seed, vapply(seq_len(B), function(i) stat(sample.int(n, n, replace = TRUE)), numeric(1)))
  a <- (1 - conf) / 2
  c(lower = as.numeric(stats::quantile(vals, a, names = FALSE)),
    upper = as.numeric(stats::quantile(vals, 1 - a, names = FALSE)), B = B)
}

# Evaluate the RNG state around an expression (keeps seeded calls reproducible
# without disturbing the caller's random stream).
with_seed <- function(seed, expr) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had_seed) old <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit({
    if (had_seed) assign(".Random.seed", old, envir = globalenv())
    else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE))
      rm(".Random.seed", envir = globalenv())
  }, add = TRUE)
  set.seed(seed)
  force(expr)
}

# Anomaly flag: exactly one of five categories, always with a review-not-fraud
# interpretation sentence.
flag_anomaly <- function(suitable = TRUE, n_eligible = NA_integer_, p_adjusted = NA_real_,
                         mad = NA_real_, alpha = 0.05, kind = "first") {
  boundary <- "Deviation from Benford's Law is a diagnostic flag for further review, not evidence of fraud or fabrication."
  if (!isTRUE(suitable)) {
    return(list(flag = "Not assessed - unsuitable data",
                interpretation = paste("The suitability screening rejected this column, so no Benford test was applied.",
                                       boundary)))
  }
  if (is.na(p_adjusted)) {
    return(list(flag = "Not assessed - insufficient sample",
                interpretation = paste("Too few eligible values (or expected counts below 1) for a valid chi-square test, so no flag was issued.",
                                       boundary)))
  }
  material <- is.finite(mad) && mad > 0.006
  if (p_adjusted < alpha && material) {
    list(flag = "Statistical deviation: significant AND practically material",
         interpretation = paste(sprintf("The adjusted p-value (%.4g) is below alpha = %.3g and the mean absolute deviation (%.4f) exceeds the 0.006 close-conformity band: the first-digit pattern is unusual and worth reviewing.",
                                        p_adjusted, alpha, mad), boundary))
  } else if (p_adjusted < alpha) {
    list(flag = "Statistically significant but small deviation",
         interpretation = paste(sprintf("The adjusted p-value (%.4g) is below alpha = %.3g, but the mean absolute deviation (%.4f) is inside the 0.006 close-conformity band, which is typical for very large N.",
                                        p_adjusted, alpha, mad), boundary))
  } else {
    list(flag = "No significant deviation detected",
         interpretation = paste(sprintf("The adjusted p-value (%.4g) is not below alpha = %.3g, so the first-digit pattern is consistent with Benford's Law.",
                                        p_adjusted, alpha), boundary))
  }
}


## ===========================================================================
## Part F -- multiple testing
## ===========================================================================

# Raw, Holm and Benjamini-Hochberg adjusted p-values for one family of tests.
adjust_family <- function(p, family_name = "family") {
  p <- as.numeric(p)
  out <- data.frame(p_raw = p,
                    p_holm = stats::p.adjust(p, method = "holm"),
                    p_bh   = stats::p.adjust(p, method = "BH"),
                    family = family_name,
                    family_size = sum(!is.na(p)),
                    stringsAsFactors = FALSE)
  out
}


## ===========================================================================
## Part G -- controlled synthetic manipulation experiment
## ===========================================================================

manipulation_types <- function() c("round_number", "leading_digit_bias", "partial_alteration")

manipulation_labels <- function() {
  c(round_number        = "Round-number substitution",
    leading_digit_bias  = "Leading-digit bias (digits 5-9)",
    partial_alteration  = "Partial value alteration (x0.8-1.2)")
}

# Base (control) sample: N values from 10^U(0, 6), which conforms to Benford's Law.
synthetic_benford_base <- function(n = 2000L, seed = 2025L) {
  with_seed(seed, 10^stats::runif(n, 0, 6))
}

# Apply one manipulation to a COPY of x.  The control vector is never mutated.
# Returns list(data, altered_index, n_altered).
manipulate_vector <- function(x, type = c("round_number", "leading_digit_bias",
                                          "partial_alteration"),
                              rate = 0, seed = 1L) {
  type <- match.arg(type)
  x <- as.numeric(x)
  if (!is.finite(rate) || rate < 0 || rate > 1) stop("'rate' must be between 0 and 1")
  n <- length(x)
  k <- floor(rate * n)
  if (k < 1L) return(list(data = x, altered_index = integer(0), n_altered = 0L))

  out <- with_seed(seed, {
    idx <- sample.int(n, k, replace = FALSE)
    if (identical(type, "round_number")) {
      # round business-style numbers (1000, 5000, 10000, 25000, 50000) scaled so
      # that they sit at the magnitude of the data being studied
      pool <- c(1000, 5000, 10000, 25000, 50000)
      nz <- abs(x[x != 0])
      med <- if (length(nz)) stats::median(nz) else 1
      sc <- 10^max(0, floor(log10(med)) - 3)
      vals <- sample(pool * sc, k, replace = TRUE) * ifelse(x[idx] < 0, -1, 1)
    } else if (identical(type, "leading_digit_bias")) {
      d  <- sample(5:9, k, replace = TRUE)                   # first digit forced to 5..9
      o  <- 10^floor(log10(abs(x[idx])))                     # keep the magnitude
      vals <- sign(x[idx]) * o * (d + stats::runif(k, 0, 0.999))
    } else {
      vals <- x[idx] * stats::runif(k, 0.8, 1.2)             # deliberately hard to detect
    }
    list(idx = idx, vals = vals)
  })
  y <- x
  y[out$idx] <- out$vals
  list(data = y, altered_index = out$idx, n_altered = length(out$idx))
}

# Replicate seeds are derived deterministically from (type, level, replicate),
# so results never depend on the order in which the grid is traversed.
experiment_seed <- function(seed, type_index, level_index, replicate) {
  uid <- (as.integer(type_index) * 10L + as.integer(level_index)) * 1000L + as.integer(replicate)
  as.integer((seed + 7919L * uid) %% 2147483647L)
}

# Full controlled experiment: R replicates per (manipulation type x alteration level).
run_experiment <- function(n = 2000L,
                           levels = c(0, 0.05, 0.10, 0.20, 0.30, 0.50),
                           types = manipulation_types(),
                           R = 200L, base_values = NULL, seed = 2025L,
                           alpha = 0.05, progress = NULL) {
  used_synthetic_base <- is.null(base_values)
  if (used_synthetic_base) base_values <- synthetic_benford_base(n, seed)
  base_values <- as.numeric(base_values)
  base_values <- base_values[is.finite(base_values) & base_values != 0]

  rows <- vector("list", length(types) * length(levels) * R)
  i <- 0L
  for (ti in seq_along(types)) {
    for (li in seq_along(levels)) {
      for (r in seq_len(R)) {
        s <- experiment_seed(seed, ti, li, r)
        manip <- manipulate_vector(base_values, type = types[ti],
                                   rate = levels[li], seed = s)
        res <- benford_test_values(manip$data, kind = "first", alpha = alpha)
        i <- i + 1L
        rows[[i]] <- data.frame(
          manipulation = types[ti],
          true_alteration_rate = levels[li],
          replicate = r,
          seed = s,
          n_values = res$N,
          n_altered = manip$n_altered,
          observed_alteration_rate = manip$n_altered / length(base_values),
          x2 = res$x2, df = res$df, p = res$p,
          validity_tier = res$tier,
          mad = res$mad,
          nigrini_band = res$band,
          cohen_w = res$cohen_w,
          flagged = as.integer(!is.na(res$p) & res$p < alpha),
          stringsAsFactors = FALSE)
      }
      if (is.function(progress)) progress(i, length(types) * length(levels) * R)
    }
  }
  replicates <- do.call(rbind, rows)
  replicates$base_source <- if (used_synthetic_base) "SYNTHETIC log-uniform 10^U(0,6)" else "supplied data"

  summary <- do.call(rbind, lapply(split(replicates, list(replicates$manipulation,
                                                           replicates$true_alteration_rate),
                                        drop = TRUE), function(d) {
    p_hat <- mean(d$flagged)
    data.frame(manipulation = d$manipulation[1],
               true_alteration_rate = d$true_alteration_rate[1],
               n_replicates = nrow(d),
               mean_mad = mean(d$mad, na.rm = TRUE),
               median_mad = stats::median(d$mad, na.rm = TRUE),
               mean_x2 = mean(d$x2, na.rm = TRUE),
               mean_p = mean(d$p, na.rm = TRUE),
               detection_rate = p_hat,
               detection_se = sqrt(p_hat * (1 - p_hat) / nrow(d)),
               stringsAsFactors = FALSE)
  }))
  summary <- summary[order(summary$manipulation, summary$true_alteration_rate), ]
  rownames(summary) <- NULL
  list(replicates = replicates, summary = summary,
       alpha = alpha, R = R, levels = levels, types = types, seed = seed,
       base_n = length(base_values))
}


## ===========================================================================
## Part H -- supplementary syllabus experiments (ANOVA, regression)
## ===========================================================================

# One-way ANOVA of MAD on the alteration level, separately per manipulation type,
# with assumption checks and a non-parametric fallback + post-hoc tests.
experiment_anova <- function(replicates, alpha = 0.05) {
  out <- list()
  for (tp in unique(replicates$manipulation)) {
    d <- replicates[replicates$manipulation == tp, ]
    d$level_f <- factor(d$true_alteration_rate)
    fit <- stats::aov(mad ~ level_f, data = d)
    s   <- summary(fit)[[1]]
    sw  <- stats::shapiro.test(stats::residuals(fit))
    bt  <- try(stats::bartlett.test(mad ~ level_f, data = d), silent = TRUE)
    kw  <- stats::kruskal.test(mad ~ level_f, data = d)
    out[[length(out) + 1L]] <- data.frame(
      manipulation = tp, test = "one-way ANOVA (MAD ~ alteration level)",
      term = "level", statistic = s[["F value"]][1], df = s[["Df"]][1],
      df2 = s[["Df"]][2], p_value = s[["Pr(>F)"]][1],
      note = "completely randomised design, one factor", stringsAsFactors = FALSE)
    out[[length(out) + 1L]] <- data.frame(
      manipulation = tp, test = "Shapiro-Wilk normality of ANOVA residuals",
      term = "residuals", statistic = sw$statistic, df = NA_real_, df2 = NA_real_,
      p_value = sw$p.value,
      note = "tests normality of residuals; very sensitive for large samples",
      stringsAsFactors = FALSE)
    out[[length(out) + 1L]] <- data.frame(
      manipulation = tp, test = "Bartlett test of equal variances",
      term = "level", statistic = if (inherits(bt, "try-error")) NA_real_ else bt$statistic,
      df = if (inherits(bt, "try-error")) NA_real_ else length(unique(d$level_f)) - 1L,
      df2 = NA_real_,
      p_value = if (inherits(bt, "try-error")) NA_real_ else bt$p.value,
      note = "homogeneity of variance across alteration levels", stringsAsFactors = FALSE)
    out[[length(out) + 1L]] <- data.frame(
      manipulation = tp, test = "Kruskal-Wallis rank test (non-parametric alternative)",
      term = "level", statistic = kw$statistic, df = kw$parameter,
      df2 = NA_real_, p_value = kw$p.value,
      note = "used when the ANOVA assumptions are clearly violated",
      stringsAsFactors = FALSE)

    assumptions_ok <- (sw$p.value >= alpha) &&
      !inherits(bt, "try-error") && (bt$p.value >= alpha)
    if (assumptions_ok) {
      tk <- stats::TukeyHSD(fit, "level_f")$level_f
      out[[length(out) + 1L]] <- data.frame(
        manipulation = tp, test = "Tukey HSD post-hoc",
        term = rownames(tk), statistic = tk[, "diff"], df = NA_real_, df2 = NA_real_,
        p_value = tk[, "p adj"],
        note = "pairwise differences in mean MAD between alteration levels",
        stringsAsFactors = FALSE)
    } else {
      pw <- stats::pairwise.wilcox.test(d$mad, d$level_f, p.adjust.method = "holm")
      pwdf <- as.data.frame(as.table(pw$p.value))
      pwdf <- pwdf[!is.na(pwdf$Freq), , drop = FALSE]
      out[[length(out) + 1L]] <- data.frame(
        manipulation = tp, test = "Pairwise Wilcoxon post-hoc (Holm adjusted)",
        term = paste(pwdf$Var1, "vs", pwdf$Var2), statistic = NA_real_,
        df = NA_real_, df2 = NA_real_, p_value = pwdf$Freq,
        note = "non-parametric post-hoc because ANOVA assumptions were violated",
        stringsAsFactors = FALSE)
    }
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}

# Simple linear regression and Pearson correlation of MAD on the true alteration rate.
experiment_regression <- function(replicates) {
  out <- list()
  for (tp in unique(replicates$manipulation)) {
    d <- replicates[replicates$manipulation == tp, ]
    fit <- stats::lm(mad ~ true_alteration_rate, data = d)
    cf  <- summary(fit)$coefficients
    ct  <- stats::cor.test(d$mad, d$true_alteration_rate)
    out[[length(out) + 1L]] <- data.frame(
      manipulation = tp,
      n = nrow(d),
      intercept = cf["(Intercept)", "Estimate"],
      slope = cf["true_alteration_rate", "Estimate"],
      slope_se = cf["true_alteration_rate", "Std. Error"],
      r_squared = summary(fit)$r.squared,
      f_statistic = summary(fit)$fstatistic[1],
      df = summary(fit)$fstatistic[2],
      df2 = summary(fit)$fstatistic[3],
      p_value = cf["true_alteration_rate", "Pr(>|t|)"],
      pearson_r = unname(ct$estimate),
      pearson_p = ct$p.value,
      stringsAsFactors = FALSE)
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res
}


## ===========================================================================
## Part I -- data import (WDI, synthetic fallback, optional USASpending)
## ===========================================================================

# The curated indicator panel.  "benford-plausible" indicators are positive,
# multiplicative and span several orders of magnitude; the two negative controls
# are bounded or narrow-range and are EXPECTED to deviate (they show that a flag
# means "unusual pattern", not "fraud").
wdi_indicator_panel <- function() {
  data.frame(
    indicator_code = c("NY.GDP.MKTP.CD", "SP.POP.TOTL", "NE.EXP.GNFS.CD",
                       "NE.IMP.GNFS.CD", "AG.LND.TOTL.K2", "FI.RES.TOTL.CD",
                       "NY.GNP.MKTP.CD", "SP.DYN.LE00.IN", "SP.DYN.TFRT.IN"),
    indicator_label = c("GDP (current USD)", "Population, total",
                        "Exports of goods and services (current USD)",
                        "Imports of goods and services (current USD)",
                        "Land area (sq. km)",
                        "Total reserves incl. gold (current USD)",
                        "GNI (current USD)", "Life expectancy at birth (years)",
                        "Fertility rate, total (births per woman)"),
    role = c(rep("benford-plausible", 7), "negative control", "negative control"),
    stringsAsFactors = FALSE)
}

# CSV file holding the essential metadata of the panel and the analysis.
wdi_panel_file <- function(root = ".") file.path(root, "data", "processed", "wdi_clean.csv")

# Coerce a user supplied --data argument or automatic search into usable paths.
# Accepts: a directory, the main CSV, or the bulk ZIP.
resolve_wdi_paths <- function(data_arg = NULL, root = ".") {
  pick <- function(main, country, how) {
    if (is.null(main) || !file.exists(main)) return(NULL)
    if (is.null(country) || !file.exists(country)) country <- NA_character_
    list(main = main, country = country, how = how)
  }
  find_country_file <- function(d) {
    f <- list.files(d, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
    if (!length(f)) return(NA_character_)
    b <- basename(f)
    keep <- grepl("^WDICountry", b, ignore.case = TRUE) & !grepl("series", b, ignore.case = TRUE)
    if (!any(keep)) return(NA_character_)
    f[keep][1]
  }
  find_in_dir <- function(d, how) {
    if (is.null(d) || !dir.exists(d)) return(NULL)
    f <- list.files(d, pattern = "^WDICSV.*\\.csv$", full.names = TRUE, ignore.case = TRUE)
    if (!length(f)) f <- list.files(d, pattern = "^WDI.*\\.csv$", full.names = TRUE, ignore.case = TRUE)
    if (!length(f)) return(NULL)
    f <- f[order(nchar(f))][1]
    pick(f, find_country_file(d), how)
  }

  if (!is.null(data_arg) && nzchar(data_arg)) {
    if (dir.exists(data_arg)) {
      r <- find_in_dir(data_arg, "user supplied directory")
      if (!is.null(r)) return(r)
    } else if (file.exists(data_arg)) {
      if (grepl("\\.zip$", data_arg, ignore.case = TRUE)) {
        ex <- file.path(root, "data", "raw", "wdi")
        dir.create(ex, recursive = TRUE, showWarnings = FALSE)
        utils::unzip(data_arg, exdir = ex)
        r <- find_in_dir(ex, "user supplied zip")
        if (!is.null(r)) return(r)
      } else {
        cty <- list.files(dirname(data_arg), pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
        cty <- cty[grepl("^WDICountry", basename(cty), ignore.case = TRUE) &
                     !grepl("series", basename(cty), ignore.case = TRUE)][1]
        r <- pick(data_arg, cty, "user supplied CSV")
        if (!is.null(r)) return(r)
      }
    }
    warning(sprintf("--data='%s' could not be used; falling back to the automatic search.", data_arg))
  }

  ## 1. already extracted into the project
  r <- find_in_dir(file.path(root, "data", "raw", "wdi"), "data/raw/wdi");  if (!is.null(r)) return(r)
  ## 2. bulk ZIP placed by the student
  zip <- file.path(root, "data", "raw", "WDI_CSV.zip")
  if (file.exists(zip)) {
    ex <- file.path(root, "data", "raw", "wdi")
    dir.create(ex, recursive = TRUE, showWarnings = FALSE)
    utils::unzip(zip, exdir = ex)
    r <- find_in_dir(ex, "data/raw/WDI_CSV.zip"); if (!is.null(r)) return(r)
  }
  ## 3. anything that looks like an unzipped WDI folder elsewhere in the project
  dirs <- list.dirs(root, recursive = TRUE, full.names = TRUE)
  dirs <- dirs[!grepl("(^|/)(outputs|archive|data/processed|data/fixtures|\\.git)", dirs)]
  for (d in dirs) {
    r <- find_in_dir(d, paste0("auto-detected folder: ", basename(d)))
    if (!is.null(r)) return(r)
  }
  NULL
}

# Fast reader for the (large) wide WDI main file: the raw lines are filtered
# first, so only the curated indicator rows are ever parsed.
read_wdi_wide <- function(main_path, codes) {
  ln <- readr::read_lines(main_path)
  pats <- paste0(',"', codes, '",')
  keep <- Reduce(`|`, lapply(pats, function(p) grepl(p, ln, fixed = TRUE)))
  if (!any(keep)) {
    # some exports leave the code field unquoted
    pats2 <- paste0(",", codes, ",")
    keep <- Reduce(`|`, lapply(pats2, function(p) grepl(p, ln, fixed = TRUE)))
  }
  keep[1] <- TRUE
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp), add = TRUE)
  writeLines(ln[keep], tmp)
  x <- readr::read_csv(tmp, show_col_types = FALSE, progress = FALSE, col_types = readr::cols(.default = readr::col_character()))
  if (ncol(x) < 5) stop("the WDI main file does not look like the expected wide format")
  names(x)[1:4] <- c("country_name", "country_code", "indicator_name", "indicator_code")
  x$country_name <- sub("^\ufeff", "", x$country_name)
  x
}

# Country metadata (Region / Income Group) used to drop aggregates.
read_wdi_country <- function(country_path) {
  cty <- readr::read_csv(country_path, show_col_types = FALSE, progress = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))
  names(cty)[1] <- sub("^\ufeff", "", names(cty)[1])
  pick_col <- function(df, wanted, pos) {
    nm <- names(df)
    hit <- which(tolower(nm) == tolower(wanted))
    if (length(hit)) return(nm[hit[1]])
    if (ncol(df) >= pos) return(nm[pos])
    NA_character_
  }
  get_col <- function(df, wanted, pos) {
    cl <- pick_col(df, wanted, pos)
    if (is.na(cl)) rep(NA_character_, nrow(df)) else as.character(df[[cl]])
  }
  data.frame(country_code = get_col(cty, "Country Code", 1),
             region = get_col(cty, "Region", 8),
             income_group = get_col(cty, "Income Group", 9),
             stringsAsFactors = FALSE)
}

# Wide WDI table + country metadata -> tidy long panel with aggregates removed.
prepare_wdi_panel <- function(wide, country, codes) {
  year_cols <- grep("^[0-9]{4}$", names(wide), value = TRUE)
  if (!length(year_cols)) stop("no year columns found in the WDI main file")
  wide <- wide[wide$indicator_code %in% codes, , drop = FALSE]
  rows_before <- nrow(wide) * length(year_cols)
  long <- tidyr::pivot_longer(wide, cols = tidyr::all_of(year_cols),
                              names_to = "year", values_to = "value")
  long <- as.data.frame(long, stringsAsFactors = FALSE)
  long$year  <- suppressWarnings(as.integer(long$year))
  long$value <- suppressWarnings(as.numeric(long$value))
  long <- long[!is.na(long$value), , drop = FALSE]
  long <- merge(long, country, by = "country_code", all.x = TRUE, sort = FALSE)
  long <- long[!is.na(long$region) & nzchar(long$region), , drop = FALSE]
  lab <- wdi_indicator_panel()
  long$indicator_label <- lab$indicator_label[match(long$indicator_code, lab$indicator_code)]
  long$indicator_role  <- lab$role[match(long$indicator_code, lab$indicator_code)]
  long$source <- "World Bank WDI"
  long$is_synthetic <- FALSE
  long <- long[, c("country_code", "country_name", "region", "income_group",
                   "indicator_code", "indicator_label", "indicator_role",
                   "year", "value", "source", "is_synthetic")]
  long <- long[order(long$indicator_code, long$country_code, long$year), ]
  rownames(long) <- NULL
  attr(long, "rows_before_cleaning") <- rows_before
  long
}

# Load the WDI panel from disk if available; returns NULL when nothing is found.
load_wdi_panel <- function(root = ".", data_arg = NULL, codes = wdi_indicator_panel()$indicator_code) {
  src <- resolve_wdi_paths(data_arg, root)
  if (is.null(src)) return(NULL)
  wide <- read_wdi_wide(src$main, codes)
  found <- intersect(codes, unique(wide$indicator_code))
  if (!length(found)) return(NULL)
  cty <- if (!is.na(src$country)) read_wdi_country(src$country) else
    data.frame(country_code = character(0), region = character(0), income_group = character(0))
  if (!nrow(cty)) {
    # no metadata file: keep every code but mark the region as unknown
    wide$country_code_keep <- TRUE
    panel <- prepare_wdi_panel_nometa(wide, found)
  } else {
    panel <- prepare_wdi_panel(wide, cty, found)
  }
  attr(panel, "source_file") <- src$main
  attr(panel, "source_how")  <- src$how
  attr(panel, "country_file") <- src$country
  attr(panel, "codes_available") <- found
  attr(panel, "codes_missing") <- setdiff(codes, found)
  panel
}

# Fallback used only if the country metadata file is absent (region unknown).
prepare_wdi_panel_nometa <- function(wide, codes) {
  wide <- wide[wide$indicator_code %in% codes, , drop = FALSE]
  year_cols <- grep("^[0-9]{4}$", names(wide), value = TRUE)
  long <- as.data.frame(tidyr::pivot_longer(wide, cols = tidyr::all_of(year_cols),
                                            names_to = "year", values_to = "value"))
  long$year  <- suppressWarnings(as.integer(long$year))
  long$value <- suppressWarnings(as.numeric(long$value))
  long <- long[!is.na(long$value), , drop = FALSE]
  long$region <- "Unknown (no country metadata)"
  long$income_group <- NA_character_
  lab <- wdi_indicator_panel()
  long$indicator_label <- lab$indicator_label[match(long$indicator_code, lab$indicator_code)]
  long$indicator_role  <- lab$role[match(long$indicator_code, lab$indicator_code)]
  long$source <- "World Bank WDI"
  long$is_synthetic <- FALSE
  long[, c("country_code", "country_name", "region", "income_group",
           "indicator_code", "indicator_label", "indicator_role",
           "year", "value", "source", "is_synthetic")]
}

# Clearly labelled synthetic fallback panel (used only when no real data exists
# and as a test fixture).  Never to be described as a real-world finding.
synthetic_panel <- function(n_countries = 60L, years = 2015:2024, seed = 2025L) {
  set.seed(seed)
  cc <- sprintf("SYN%03d", seq_len(n_countries))
  regions <- rep(c("SYNTHETIC Region A", "SYNTHETIC Region B", "SYNTHETIC Region C"),
                 length.out = n_countries)
  specs <- data.frame(
    code = c("SYN.GDP", "SYN.POP", "SYN.EXP", "SYN.RES", "SYN.LE", "SYN.TFR"),
    label = c("SYNTHETIC - NOT REAL DATA: GDP", "SYNTHETIC - NOT REAL DATA: population",
              "SYNTHETIC - NOT REAL DATA: exports", "SYNTHETIC - NOT REAL DATA: reserves",
              "SYNTHETIC - NOT REAL DATA: life expectancy (bounded)",
              "SYNTHETIC - NOT REAL DATA: fertility rate (bounded)"),
    role = c(rep("benford-plausible", 4), "negative control", "negative control"),
    stringsAsFactors = FALSE)
  out <- list()
  for (i in seq_len(nrow(specs))) {
    for (k in seq_along(cc)) {
      nn <- length(years)
      vals <- if (specs$role[i] == "benford-plausible") {
        10^(stats::runif(nn, 4, 11))
      } else if (grepl("life expectancy", specs$label[i])) {
        stats::runif(nn, 50, 85)
      } else {
        stats::runif(nn, 1, 7)
      }
      out[[length(out) + 1L]] <- data.frame(
        country_code = cc[k], country_name = paste("SYNTHETIC country", k),
        region = regions[k], income_group = "SYNTHETIC income group",
        indicator_code = specs$code[i], indicator_label = specs$label[i],
        indicator_role = specs$role[i], year = as.integer(years), value = vals,
        source = "SYNTHETIC - NOT REAL DATA", is_synthetic = TRUE,
        stringsAsFactors = FALSE)
    }
  }
  panel <- do.call(rbind, out)
  attr(panel, "rows_before_cleaning") <- NA_integer_
  panel
}

# Curated panel actually used by the pipeline: real WDI if present, else synthetic.
# Returns list(panel, is_synthetic, source_label, notes).
load_curated_panel <- function(root = ".", data_arg = NULL) {
  real <- try(load_wdi_panel(root = root, data_arg = data_arg), silent = TRUE)
  if (inherits(real, "try-error")) {
    warning("WDI import failed: ", conditionMessage(attr(real, "condition")))
    real <- NULL
  }
  if (!is.null(real) && nrow(real) > 0) {
    return(list(panel = real, is_synthetic = FALSE,
                source_label = paste0("World Bank WDI (", attr(real, "source_how"), ")"),
                source_file = attr(real, "source_file"),
                country_file = attr(real, "country_file"),
                codes_available = attr(real, "codes_available"),
                codes_missing = attr(real, "codes_missing"),
                rows_before = attr(real, "rows_before_cleaning"),
                notes = character(0)))
  }
  syn <- synthetic_panel()
  list(panel = syn, is_synthetic = TRUE,
       source_label = "SYNTHETIC - NOT REAL DATA (fallback panel)",
       source_file = NA_character_, country_file = NA_character_,
       codes_available = unique(syn$indicator_code), codes_missing = character(0),
       rows_before = NA_integer_,
       notes = "No World Bank WDI file was found, so the pipeline fell back to the labelled synthetic panel.")
}

# Generic CSV import for the dashboard and for optional secondary datasets.
read_any_csv <- function(path, max_rows = 200000L) {
  if (is.list(path) && !is.null(path$datapath)) path <- path$datapath
  if (!file.exists(path)) stop("file does not exist: ", path)
  x <- readr::read_csv(path, show_col_types = FALSE, progress = FALSE, n_max = max_rows)
  names(x) <- sub("^\ufeff", "", names(x))
  as.data.frame(x, stringsAsFactors = FALSE)
}

# Optional secondary dataset: any CSV the student places in data/raw/usaspending/.
# Amount columns are detected by name, negative values are treated as
# de-obligations and analysed by magnitude.
usaspending_amount_columns <- function(df) {
  cand <- c("federal_action_obligation", "total_obligated_amount",
            "current_total_value_of_award", "total_outlayed_amount",
            "potential_total_value_of_award", "award_amount", "obligated_amount")
  nm <- tolower(names(df))
  hit <- nm[nm %in% cand]
  if (!length(hit)) {
    num <- names(df)[vapply(df, function(z) is.numeric(z) && sum(z != 0, na.rm = TRUE) > 50, logical(1))]
    hit <- num
  }
  names(df)[nm %in% hit]
}

load_usaspending <- function(dir = file.path("data", "raw", "usaspending")) {
  if (!dir.exists(dir)) return(NULL)
  files <- list.files(dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
  if (!length(files)) return(NULL)
  out <- list()
  for (f in files) {
    df <- try(read_any_csv(f), silent = TRUE)
    if (inherits(df, "try-error")) next
    cols <- usaspending_amount_columns(df)
    yc <- grep("fiscal_year|action_date|year", names(df), ignore.case = TRUE, value = TRUE)[1]
    year <- if (length(yc) && !is.na(yc)) suppressWarnings(as.integer(substr(as.character(df[[yc]]), 1, 4))) else NA_integer_
    region <- if ("awarding_agency_name" %in% names(df)) df[["awarding_agency_name"]] else "All awards"
    for (cl in cols) {
      out[[length(out) + 1L]] <- data.frame(
        country_code = "US-FED", country_name = "United States federal awards",
        region = region, income_group = NA_character_,
        indicator_code = paste0("USASPEND.", toupper(gsub("[^a-z0-9]", "_", tolower(cl)))),
        indicator_label = paste0("USASpending ", cl, " (", basename(f), ")"),
        indicator_role = "secondary (optional)",
        year = year, value = df[[cl]], source = "USASpending.gov",
        is_synthetic = FALSE, stringsAsFactors = FALSE)
    }
  }
  if (!length(out)) return(NULL)
  res <- do.call(rbind, out)
  res <- res[!is.na(res$value), , drop = FALSE]
  res
}


## ===========================================================================
## Part J -- analysis units and result assembly (used by pipeline and app)
## ===========================================================================

# Latest year whose number of reporting countries is within 'coverage' of the
# best covered year: the latest complete cross-section of one indicator.
latest_complete_year <- function(years, coverage = 0.95) {
  tb <- table(years)
  if (!length(tb)) return(NA_integer_)
  mx <- max(tb)
  cand <- suppressWarnings(as.integer(names(tb)))[as.numeric(tb) >= coverage * mx]
  cand <- cand[!is.na(cand)]
  if (!length(cand)) return(NA_integer_)
  max(cand)
}

# Build every analysis unit required by the brief from a tidy long panel:
#   latest_year (a) latest complete year cross-section, one per indicator
#   pooled      (b) all country-years pooled
#   year        (c) one subset per year
#   region      (d) one subset per region
# Units with fewer than 'min_n' eligible values carry skipped = TRUE and are
# never tested (minimum-sample guard).
analysis_units <- function(panel, min_n = 110L, coverage = 0.95) {
  panel <- as.data.frame(panel, stringsAsFactors = FALSE)
  out <- list()
  add <- function(ut, ul, code, label, role, vals, grp_var = NA_character_, grp_val = NA_character_) {
    cl <- clean_numeric(vals)
    out[[length(out) + 1L]] <<- list(
      unit_type = ut, unit_label = ul,
      indicator_code = code, indicator_label = label, indicator_role = role,
      group_var = grp_var, group_value = grp_val,
      n_raw = length(vals), n_eligible = cl$n_eligible,
      skipped = cl$n_eligible < min_n, values = cl$eligible)
  }
  for (code in unique(panel$indicator_code)) {
    d <- panel[panel$indicator_code == code, , drop = FALSE]
    label <- d$indicator_label[1]
    role  <- d$indicator_role[1]
    add("pooled", paste0(label, " | all country-years pooled"), code, label, role, d$value)
    yr <- latest_complete_year(d$year, coverage)
    if (!is.na(yr)) {
      add("latest_year", paste0(label, " | latest complete year ", yr), code, label, role,
          d$value[d$year == yr], "year", as.character(yr))
    }
    for (y in sort(unique(d$year))) {
      add("year", paste0(label, " | year ", y), code, label, role,
          d$value[d$year == y], "year", as.character(y))
    }
    for (rg in sort(unique(d$region))) {
      add("region", paste0(label, " | region ", rg), code, label, role,
          d$value[d$region == rg], "region", rg)
    }
  }
  out
}

# Readable p-value for reports and console output.
format_p <- function(p, digits = 4) {
  if (length(p) != 1L || is.na(p)) return("NA")
  if (p < 1e-4) return(formatC(p, format = "e", digits = 2))
  formatC(p, format = "f", digits = digits)
}

# Family definition used for the multiple-testing adjustment.
unit_family <- function(unit_type) {
  switch(unit_type,
         latest_year = "family 1: latest complete year cross-section (all indicators)",
         pooled      = "family 2: pooled country-years (all indicators)",
         year        = "family 3: per-year subsets (all indicators x years)",
         region      = "family 4: per-region subsets (all indicators x regions)",
         "family 0: unspecified")
}

# Run the complete first-digit / first-two-digit / second-digit analysis over
# every analysis unit and return the tidy result tables used by the pipeline,
# the report and the dashboard.
run_benford_analysis <- function(panel, alpha = 0.05, min_n = 110L, extended = TRUE,
                                 bootstrap = FALSE, B = 1000L, seed = 2025L,
                                 verbose = FALSE) {
  units <- analysis_units(panel, min_n = min_n)
  freq_rows <- list(); chi_rows <- list(); two_rows <- list()
  desc_rows <- list(); clean_rows <- list(); suit_rows <- list(); skip_rows <- list()
  verdicts <- list()

  for (u in units) {
    if (isTRUE(u$skipped)) {
      skip_rows[[length(skip_rows) + 1L]] <- data.frame(
        unit_type = u$unit_type, unit_label = u$unit_label,
        indicator_code = u$indicator_code, n_eligible = u$n_eligible,
        reason = sprintf("only %d eligible values (below the minimum of %d): test not run",
                         u$n_eligible, min_n), stringsAsFactors = FALSE)
      next
    }
    d  <- describe_numeric(u$values)
    desc_rows[[length(desc_rows) + 1L]] <- data.frame(
      indicator_code = u$indicator_code, indicator_label = u$indicator_label,
      indicator_role = u$indicator_role, unit_type = u$unit_type, unit_label = u$unit_label,
      n = d$n, missing = d$missing, min = d$min, max = d$max, mean = d$mean,
      median = d$median, sd = d$sd, q1 = d$q1, q3 = d$q3, skewness = d$skewness,
      range_orders = d$range_orders, pct_unique = d$pct_unique,
      stringsAsFactors = FALSE)

    if (u$unit_type %in% c("pooled", "latest_year")) {
      cl <- clean_numeric(u$values)
      cc <- cl$counts
      clean_rows[[length(clean_rows) + 1L]] <- data.frame(
        indicator_code = u$indicator_code, unit_type = u$unit_type, unit_label = u$unit_label,
        t(stats::setNames(cc$n, cc$category)), check.names = FALSE, stringsAsFactors = FALSE)
    }
    s <- suitability(u$values, name = u$indicator_label)
    verdicts[[u$unit_label]] <- s$verdict
    suit_rows[[length(suit_rows) + 1L]] <- data.frame(
      indicator_code = u$indicator_code, indicator_label = u$indicator_label,
      indicator_role = u$indicator_role, unit_type = u$unit_type, unit_label = u$unit_label,
      n_eligible = s$n_eligible, range_orders = s$range_orders,
      pct_unique = s$pct_unique, score = s$score, max_score = s$max_score,
      verdict = s$verdict,
      hard_failures = if (length(s$hard_failures)) paste(s$hard_failures, collapse = "; ") else "none",
      reasons = paste(s$reasons, collapse = " | "), stringsAsFactors = FALSE)

    r1 <- benford_test_values(u$values, "first", alpha = alpha)
    freq_rows[[length(freq_rows) + 1L]] <- data.frame(
      indicator_code = u$indicator_code, indicator_label = u$indicator_label,
      indicator_role = u$indicator_role, unit_type = u$unit_type, unit_label = u$unit_label,
      digit = r1$frequency$digit, observed_count = r1$frequency$count,
      observed_proportion = r1$frequency$proportion,
      expected_proportion = as.numeric(r1$expected_prop),
      expected_count = as.numeric(r1$E),
      difference = r1$frequency$proportion - as.numeric(r1$expected_prop),
      pearson_residual = as.numeric(r1$residuals),
      notable_residual = as.integer(abs(r1$residuals) > 1.96),
      stringsAsFactors = FALSE)

    chi_rows[[length(chi_rows) + 1L]] <- data.frame(
      indicator_code = u$indicator_code, indicator_label = u$indicator_label,
      indicator_role = u$indicator_role, unit_type = u$unit_type, unit_label = u$unit_label,
      group_var = u$group_var, group_value = u$group_value,
      n = r1$N, df = r1$df, x2 = r1$x2, p_raw = r1$p,
      validity_tier = r1$tier, validity_note = r1$note, decision = r1$decision,
      min_expected_count = r1$min_E, pct_cells_expected_lt5 = r1$pct_cells_E_lt5,
      mad = r1$mad, nigrini_band = r1$band, cohens_w = r1$cohen_w,
      min_n_reliable = r1$min_n_reliable, min_n_all_expected_ge1 = r1$min_n_all_ge1,
      mad_ci_lower = NA_real_, mad_ci_upper = NA_real_, mad_ci_B = 0L,
      alpha = alpha, stringsAsFactors = FALSE)

    if (isTRUE(extended)) {
      for (kd in c("first2", "second")) {
        rk <- benford_test_values(u$values, kd, alpha = alpha)
        two_rows[[length(two_rows) + 1L]] <- data.frame(
          indicator_code = u$indicator_code, indicator_label = u$indicator_label,
          indicator_role = u$indicator_role, unit_type = u$unit_type, unit_label = u$unit_label,
          digit_kind = kd, n = rk$N, df = rk$df, x2 = rk$x2, p_raw = rk$p,
          validity_tier = rk$tier, validity_note = rk$note, decision = rk$decision,
          min_expected_count = rk$min_E, min_n_reliable = rk$min_n_reliable,
          mad = rk$mad, cohens_w = rk$cohen_w, alpha = alpha, stringsAsFactors = FALSE)
      }
    }
    if (isTRUE(bootstrap) && identical(u$unit_type, "pooled")) {
      ci <- bootstrap_mad_ci(u$values, "first", B = B, seed = seed)
      chi_rows[[length(chi_rows)]]$mad_ci_lower <- ci[["lower"]]
      chi_rows[[length(chi_rows)]]$mad_ci_upper <- ci[["upper"]]
      chi_rows[[length(chi_rows)]]$mad_ci_B <- ci[["B"]]
    }
    if (verbose) cat(sprintf("  %-70s N = %5d\n", substr(u$unit_label, 1, 70), r1$N))
  }

  chi <- do.call(rbind, chi_rows)
  fam <- vapply(chi$unit_type, unit_family, character(1))
  adj <- adjust_family(chi$p_raw, family_name = fam)
  chi <- cbind(chi, adj[, c("p_holm", "p_bh", "family", "family_size")])
  chi$p_flag <- chi$p_bh
  flags <- do.call(rbind, lapply(seq_len(nrow(chi)), function(i) {
    vd <- verdicts[[chi$unit_label[i]]]
    f <- flag_anomaly(suitable = !identical(vd, "Unsuitable"), n_eligible = chi$n[i],
                      p_adjusted = chi$p_bh[i], mad = chi$mad[i], alpha = alpha)
    data.frame(flag = f$flag, interpretation = f$interpretation, stringsAsFactors = FALSE)
  }))
  chi <- cbind(chi, flags)

  list(units = units,
       descriptive = do.call(rbind, desc_rows),
       cleaning = do.call(rbind, clean_rows),
       suitability = do.call(rbind, suit_rows),
       first_digit_frequency = do.call(rbind, freq_rows),
       chi_square = chi,
       two_digit = if (length(two_rows)) do.call(rbind, two_rows) else NULL,
       skipped = if (length(skip_rows)) do.call(rbind, skip_rows) else NULL,
       verdicts = verdicts, alpha = alpha, min_n = min_n)
}


## ===========================================================================
## Part K -- explainable transaction-level review screening (USAspending)
## ===========================================================================

# Verified column mapping for the raw USAspending contract-transaction export
# used by this project.  The raw file is never modified.
usaspending_transaction_fields <- function() {
  c(transaction_key = "contract_transaction_unique_key",
    award_key       = "contract_award_unique_key",
    award_id        = "award_id_piid",
    modification    = "modification_number",
    transaction_no  = "transaction_number",
    amount          = "federal_action_obligation",
    total_obligated = "total_dollars_obligated",
    action_date     = "action_date",
    agency          = "awarding_agency_name",
    sub_agency      = "awarding_sub_agency_name",
    recipient       = "recipient_name",
    description     = "transaction_description",
    award_type      = "award_type",
    naics           = "naics_code")
}

# Parse money that may contain $, thousands separators or parentheses negatives.
parse_money <- function(x) {
  x <- trimws(as.character(x))
  neg <- grepl("^\\(.*\\)$", x)
  x <- gsub("[^0-9eE+.-]", "", x)
  v <- suppressWarnings(as.numeric(x))
  ifelse(neg, -abs(v), v)
}

# Parse dates from Date/POSIXct or the common export formats.
parse_action_date <- function(x) {
  if (inherits(x, "Date")) return(x)
  if (inherits(x, "POSIXt")) return(as.Date(x))
  x <- trimws(as.character(x))
  out <- suppressWarnings(as.Date(x))
  if (all(is.na(out))) {
    for (fmt in c("%m/%d/%Y", "%d/%m/%Y", "%Y%m%d", "%m-%d-%Y", "%d-%m-%Y")) {
      cand <- suppressWarnings(as.Date(x, format = fmt))
      if (any(!is.na(cand))) { out <- cand; break }
    }
  }
  out
}

# Load only the verified transaction fields, caching the extract in
# data/processed/.  The cache is rebuilt when the raw file is newer.
load_usaspending_transactions <- function(root = ".", refresh = FALSE, max_rows = Inf) {
  raw <- file.path(root, "data", "raw", "usaspending", "usaspending.csv")
  if (!file.exists(raw))
    stop("USAspending raw file not found: ", raw)
  cache <- file.path(root, "data", "processed", "usaspending_transactions.rds")
  if (!isTRUE(refresh) && file.exists(cache) && file.mtime(cache) >= file.mtime(raw)) {
    cached <- try(readRDS(cache), silent = TRUE)
    if (!inherits(cached, "try-error") && is.data.frame(cached) && nrow(cached) > 0)
      return(cached)
  }

  fields <- usaspending_transaction_fields()
  wanted <- unname(fields)
  tx <- readr::read_csv(raw, col_select = tidyselect::all_of(wanted),
                        show_col_types = FALSE, progress = FALSE, n_max = max_rows)
  names(tx) <- names(fields)[match(names(tx), wanted)]
  for (nm in names(fields)) if (!nm %in% names(tx)) tx[[nm]] <- NA

  out <- data.frame(
    transaction_key = as.character(tx$transaction_key),
    award_key       = as.character(tx$award_key),
    award_id        = as.character(tx$award_id),
    modification    = as.character(tx$modification),
    transaction_no  = as.character(tx$transaction_no),
    amount          = parse_money(tx$amount),
    total_obligated = parse_money(tx$total_obligated),
    action_date     = parse_action_date(tx$action_date),
    agency          = as.character(tx$agency),
    sub_agency      = as.character(tx$sub_agency),
    recipient       = as.character(tx$recipient),
    description     = as.character(tx$description),
    award_type      = as.character(tx$award_type),
    naics           = as.character(tx$naics),
    stringsAsFactors = FALSE)
  out$transaction_key[is.na(out$transaction_key) | !nzchar(out$transaction_key)] <-
    paste(out$award_id[is.na(out$transaction_key) | !nzchar(out$transaction_key)],
          out$modification[is.na(out$transaction_key) | !nzchar(out$transaction_key)],
          out$transaction_no[is.na(out$transaction_key) | !nzchar(out$transaction_key)],
          sep = "-")

  if (is.infinite(max_rows)) {
    dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)
    saveRDS(out, cache)
  }
  out
}

# Screen transaction rows with explicit, explainable rules.  The scoring is
# deliberately independent of the population-level Benford test: a Benford
# deviation is never used as evidence that a particular row is fraudulent.
#
# Strong review rules:
#   * robust amount outlier within an awarding-agency peer group
#     (log10 magnitude, median/MAD, |robust z| >= z_review; MAD = 0 guarded),
#   * amount beyond 3 IQR of the peer group on the log10 scale,
#   * duplicate transaction key,
#   * repeated amount/date/recipient signature (3 or more rows).
# Data-quality checks (missing/zero/negative amount, missing date/agency/
# recipient) and round-number amounts are reported but do not by themselves
# turn a row into a review candidate.
screen_usaspending_transactions <- function(tx, min_group = 30L,
                                            z_review = 3.5, z_high = 7,
                                            max_rows = Inf) {
  if (!is.data.frame(tx) || !nrow(tx)) stop("No transaction rows to screen.")
  required <- c("amount", "agency", "recipient", "action_date", "award_id")
  if (!all(required %in% names(tx))) stop("Transaction table is missing required fields.")
  if (is.finite(max_rows) && nrow(tx) > max_rows) tx <- tx[seq_len(max_rows), , drop = FALSE]

  n <- nrow(tx)
  amt <- suppressWarnings(as.numeric(tx$amount))
  mag <- abs(amt)
  finite_amt <- is.finite(amt)
  logx <- ifelse(finite_amt & mag > 0, log10(pmax(mag, 1e-12)), NA_real_)
  agency <- trimws(as.character(tx$agency))
  agency[is.na(agency) | !nzchar(agency)] <- "Unknown agency"
  ## Agency alone can be a single group in a one-agency export, so peer groups
  ## use awarding agency + NAICS category. Small groups fall back to the file.
  naics <- trimws(as.character(tx$naics))
  naics[is.na(naics) | !nzchar(naics)] <- "Unknown NAICS"
  peer_group <- paste(agency, naics, sep = " | ")
  min_group <- max(2L, as.integer(min_group))

  safe_med <- function(z) if (any(is.finite(z))) stats::median(z, na.rm = TRUE) else NA_real_
  safe_mad <- function(z) if (sum(is.finite(z)) >= 2L) stats::mad(z, na.rm = TRUE) else NA_real_
  safe_q <- function(z, p) if (sum(is.finite(z)) >= 2L)
    as.numeric(stats::quantile(z, p, na.rm = TRUE, names = FALSE)) else NA_real_

  peer_n   <- stats::ave(logx, peer_group, FUN = function(z) sum(is.finite(z)))
  peer_med <- stats::ave(logx, peer_group, FUN = safe_med)
  peer_mad <- stats::ave(logx, peer_group, FUN = safe_mad)
  peer_q1  <- stats::ave(logx, peer_group, FUN = function(z) safe_q(z, 0.25))
  peer_q3  <- stats::ave(logx, peer_group, FUN = function(z) safe_q(z, 0.75))
  overall_med <- safe_med(logx)
  overall_mad <- safe_mad(logx)
  overall_q1  <- safe_q(logx, 0.25)
  overall_q3  <- safe_q(logx, 0.75)

  use_peer <- peer_n >= min_group & is.finite(peer_mad) & peer_mad > 0
  med <- ifelse(use_peer, peer_med, overall_med)
  mad <- ifelse(use_peer, peer_mad, overall_mad)
  q1  <- ifelse(use_peer, peer_q1, overall_q1)
  q3  <- ifelse(use_peer, peer_q3, overall_q3)
  z <- ifelse(is.finite(mad) & mad > 0, (logx - med) / mad, NA_real_)

  iqr <- q3 - q1
  iqr_lo <- q1 - 3 * iqr
  iqr_hi <- q3 + 3 * iqr
  ## Review is one-sided: unusually LARGE obligations are the screening target.
  ## Tiny cents-level rows are data noise, not fraud candidates.
  amount_outlier <- is.finite(z) & z >= z_review
  iqr_outlier <- is.finite(logx) & is.finite(iqr_hi) & logx > iqr_hi

  missing_amount <- !finite_amt
  zero_amount <- finite_amt & amt == 0
  negative_amount <- finite_amt & amt < 0
  missing_date <- is.na(tx$action_date)
  missing_agency <- is.na(tx$agency) | !nzchar(trimws(as.character(tx$agency)))
  missing_recipient <- is.na(tx$recipient) | !nzchar(trimws(as.character(tx$recipient)))

  key <- as.character(tx$transaction_key)
  key <- ifelse(is.na(key) | !nzchar(key),
                paste(tx$award_id, tx$modification, tx$transaction_no, sep = "-"), key)
  dup_key <- nzchar(key) & (duplicated(key) | duplicated(key, fromLast = TRUE))

  sig <- paste(as.character(tx$award_id), amt, as.character(tx$action_date),
               as.character(tx$recipient), sep = "|")
  sig_ok <- !is.na(tx$award_id) & nzchar(as.character(tx$award_id)) & is.finite(amt)
  sig_count <- stats::ave(seq_len(n), sig, FUN = length)
  repeated_sig <- sig_ok & sig_count >= 3L
  round_amount <- finite_amt & mag >= 1000 & abs(mag / 1000 - round(mag / 1000)) < 1e-9

  reasons <- vapply(seq_len(n), function(i) {
    r <- character(0)
    if (isTRUE(amount_outlier[i]))
      r <- c(r, sprintf("Amount is %.1f robust SDs from its agency/NAICS peer group (log10 scale).", abs(z[i])))
    if (isTRUE(iqr_outlier[i]) && !isTRUE(amount_outlier[i]))
      r <- c(r, "Amount lies beyond 3 IQR of its agency/NAICS peer group (log10 scale).")
    if (isTRUE(dup_key[i]))
      r <- c(r, "Duplicate transaction key (data-quality check).")
    if (isTRUE(repeated_sig[i]))
      r <- c(r, "Amount/date/recipient signature repeated 3+ times (may be legitimate instalments).")
    if (isTRUE(negative_amount[i]))
      r <- c(r, "Negative amount (de-obligation); magnitude used for screening.")
    if (isTRUE(zero_amount[i])) r <- c(r, "Zero amount (data-quality check).")
    if (isTRUE(missing_amount[i])) r <- c(r, "Missing or non-numeric amount (data-quality check).")
    if (isTRUE(missing_date[i])) r <- c(r, "Missing action date (data-quality check).")
    if (isTRUE(missing_agency[i])) r <- c(r, "Missing awarding agency (data-quality check).")
    if (isTRUE(missing_recipient[i])) r <- c(r, "Missing recipient name (data-quality check).")
    if (isTRUE(round_amount[i]) && !isTRUE(amount_outlier[i]) && !isTRUE(iqr_outlier[i]))
      r <- c(r, "Round-number amount (weak signal only).")
    if (!length(r)) r <- "No review rule triggered."
    paste(r, collapse = "; ")
  }, character(1))

  review_candidate <- amount_outlier | iqr_outlier | dup_key | repeated_sig
  severity <- ifelse(review_candidate & amount_outlier & z >= z_high, "High",
              ifelse(review_candidate & (amount_outlier | iqr_outlier | dup_key), "Medium",
              ifelse(review_candidate, "Low",
              ifelse(missing_amount | zero_amount | missing_date | missing_agency |
                       missing_recipient | negative_amount, "Info", "None"))))
  score <- ifelse(is.finite(z), abs(z), NA_real_)

  out <- data.frame(
    transaction_key = key,
    award_id = as.character(tx$award_id),
    action_date = tx$action_date,
    agency = as.character(tx$agency),
    naics = as.character(tx$naics),
    peer_group = peer_group,
    recipient = as.character(tx$recipient),
    amount = amt,
    severity = severity,
    score = score,
    review_candidate = review_candidate,
    amount_outlier = amount_outlier,
    iqr_outlier = iqr_outlier,
    duplicate_key = dup_key,
    repeated_signature = repeated_sig,
    missing_amount = missing_amount,
    zero_amount = zero_amount,
    negative_amount = negative_amount,
    round_amount = round_amount,
    reasons = reasons,
    stringsAsFactors = FALSE)
  out$explanation <- ifelse(out$review_candidate,
    paste0("Review candidate: ", out$reasons,
           " A flag is a reason for review, not proof of fraud."),
    ifelse(out$severity == "Info",
      paste0("Data-quality note: ", out$reasons),
      "No row-level review rule triggered."))
  attr(out, "screening") <- list(min_group = min_group, z_review = z_review,
                                  z_high = z_high, rows = n,
                                  peer_groups = length(unique(peer_group)),
                                  note = paste("Log10 amount; robust z uses median/MAD within awarding-agency",
                                               "+ NAICS peer groups with at least", min_group, "finite values; otherwise the whole file.",
                                               "A Benford population result is not used as a row-level fraud rule."))
  out
}

# Compact summary used by the dashboard and the export.
review_summary <- function(screened) {
  if (is.null(screened) || !nrow(screened)) return(NULL)
  data.frame(
    rows_scanned = nrow(screened),
    review_candidates = sum(screened$review_candidate, na.rm = TRUE),
    high_severity = sum(screened$severity == "High", na.rm = TRUE),
    medium_severity = sum(screened$severity == "Medium", na.rm = TRUE),
    low_severity = sum(screened$severity == "Low", na.rm = TRUE),
    amount_outliers = sum(screened$amount_outlier, na.rm = TRUE),
    iqr_outliers = sum(screened$iqr_outlier, na.rm = TRUE),
    duplicate_keys = sum(screened$duplicate_key, na.rm = TRUE),
    repeated_signatures = sum(screened$repeated_signature, na.rm = TRUE),
    missing_amount = sum(screened$missing_amount, na.rm = TRUE),
    zero_amount = sum(screened$zero_amount, na.rm = TRUE),
    negative_amount = sum(screened$negative_amount, na.rm = TRUE),
    stringsAsFactors = FALSE)
}
