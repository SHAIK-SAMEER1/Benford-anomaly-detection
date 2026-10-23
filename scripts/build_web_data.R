#!/usr/bin/env Rscript
###############################################################################
##  scripts/build_web_data.R
##
##  Rebuilds the data payload used by the static "Benford Field Kit" web app.
##  Every number written to web/assets/js/data.js is computed here from the
##  files in data/raw/ (or from the existing processed WDI panel).  Nothing is
##  typed into the front end by hand.
##
##  Run:
##    "C:/Program Files/R/R-4.6.1/bin/Rscript.exe" scripts/build_web_data.R
##    ... --only=usaspending
##    ... --skip-models
##
##  Outputs (web/):
##    assets/js/data.js                     compact JSON payload
##    downloads/*.csv                       full result tables
##    downloads/dataset_registry.csv
##    downloads/model_metrics.csv
##    downloads/audit_summary.json
###############################################################################

root <- normalizePath(getwd())
if (!file.exists(file.path(root, "R", "benford.R"))) {
  stop("Run this script from the project root (R/benford.R not found).")
}
source(file.path(root, "R", "benford.R"))
suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
  library(ranger)
})

args <- commandArgs(trailingOnly = TRUE)
only_arg <- sub("^--only=", "", grep("^--only=", args, value = TRUE))
only <- if (length(only_arg)) strsplit(only_arg[1], ",")[[1]] else NULL
skip_models <- any(args == "--skip-models")
want <- function(id) is.null(only) || id %in% only

web_dir <- file.path(root, "web")
dir.create(file.path(web_dir, "assets", "js"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(web_dir, "downloads"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root, "models"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root, "data", "processed"), recursive = TRUE, showWarnings = FALSE)

set.seed(2025)
first_probs <- as.numeric(benford_first_probs())
first2_probs <- as.numeric(benford_first2_probs())
second_probs <- as.numeric(benford_second_probs())
first_labs <- as.character(1:9)
first2_labs <- sprintf("%02d", 10:99)
second_labs <- as.character(0:9)

r6 <- function(x) {
  x <- suppressWarnings(as.numeric(x))
  x[!is.finite(x)] <- NA_real_
  round(x, 6)
}
scalar <- function(x, d = 6) {
  if (length(x) == 0 || is.null(x)) return(NA)
  x <- x[1]
  if (is.numeric(x)) return(if (is.finite(x)) round(x, d) else NA)
  as.character(x)
}
pct <- function(a, b) if (is.na(b) || b == 0) NA_real_ else round(100 * a / b, 2)
clip_chr <- function(x, n = 60) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  ifelse(nchar(x) > n, paste0(substr(x, 1, n - 1), "\u2026"), x)
}
fmt_money <- function(x) {
  if (is.na(x)) return("")
  if (abs(x) >= 1e9) return(paste0("$", formatC(x / 1e9, 2, format = "f"), "B"))
  if (abs(x) >= 1e6) return(paste0("$", formatC(x / 1e6, 2, format = "f"), "M"))
  if (abs(x) >= 1e3) return(paste0("$", formatC(x / 1e3, 1, format = "f"), "K"))
  paste0("$", formatC(x, 2, format = "f", big.mark = ","))
}

## --------------------------------------------------------------------------
## digit counting (chunked so a 6.3-million-row file does not build one huge
## character vector at once)
## --------------------------------------------------------------------------
digit_counts_fast <- function(x, kind = c("first", "first2", "second"), chunk = 1e6) {
  kind <- match.arg(kind)
  labs <- switch(kind, first = first_labs, first2 = first2_labs, second = second_labs)
  n <- length(x)
  out <- numeric(length(labs))
  if (!n) return(data.frame(digit = labs, count = out, stringsAsFactors = FALSE))
  ends <- unique(c(seq.int(1L, n, by = chunk) - 1L, n))
  for (i in seq_len(length(ends) - 1L)) {
    v <- x[(ends[i] + 1L):ends[i + 1L]]
    d <- switch(kind,
      first  = first_digit(v, n = 1),
      first2 = first_digit(v, n = 2),
      second = second_digit(v))
    d <- d[!is.na(d)]
    idx <- match(as.character(d), labs)
    if (length(idx)) out <- out + tabulate(idx, nbins = length(labs))
  }
  data.frame(digit = labs, count = as.numeric(out), stringsAsFactors = FALSE)
}

benford_from_counts <- function(counts, kind, alpha = 0.05, min_n = NULL) {
  probs <- switch(kind, first = first_probs, first2 = first2_probs, second = second_probs)
  if (is.null(min_n)) {
    min_n <- switch(kind, first = 110L, first2 = 1150L, second = 110L)
  }
  bt <- chisq_benford(counts, probs, alpha = alpha, kind = kind, min_n = min_n)
  list(
    kind = kind,
    N = bt$N,
    df = bt$df,
    chi2 = r6(bt$x2),
    p = r6(bt$p),
    mad = r6(bt$mad),
    band = if (identical(kind, "first")) bt$band else NA_character_,
    tier = bt$tier,
    note = bt$note,
    cohen_w = r6(bt$cohen_w),
    min_E = r6(bt$min_E),
    pct_E_lt5 = r6(bt$pct_cells_E_lt5),
    counts = as.numeric(counts),
    probs = r6(probs),
    expected = r6(bt$E),
    residuals = r6(bt$residuals),
    decision = bt$decision,
    min_n = min_n
  )
}

benford_values <- function(values, kind) {
  values <- values[is.finite(values) & values > 0]
  cnt <- digit_counts_fast(values, kind)
  benford_from_counts(cnt$count, kind)
}

group_tests <- function(values, groups, kind, family, min_n = NULL, keep_counts = TRUE) {
  keep <- is.finite(values) & values > 0 & !is.na(groups) & nzchar(as.character(groups))
  values <- values[keep]; groups <- as.character(groups)[keep]
  if (!length(values)) return(list())
  probs <- switch(kind, first = first_probs, first2 = first2_probs, second = second_probs)
  if (is.null(min_n)) min_n <- switch(kind, first = 110L, first2 = 1150L, second = 110L)
  ug <- unique(groups)
  out <- vector("list", length(ug))
  for (i in seq_along(ug)) {
    v <- values[groups == ug[i]]
    cnt <- digit_counts_fast(v, kind)
    bt <- chisq_benford(cnt$count, probs, alpha = 0.05, kind = kind, min_n = min_n)
    flag <- flag_anomaly(
      suitable = bt$N >= min_n,
      n_eligible = bt$N,
      p_adjusted = bt$p,
      mad = bt$mad,
      kind = kind
    )
    out[[i]] <- list(
      family = family,
      group = ug[i],
      n = bt$N,
      chi2 = r6(bt$x2),
      p = r6(bt$p),
      df = bt$df,
      mad = r6(bt$mad),
      band = if (identical(kind, "first")) bt$band else NA_character_,
      tier = bt$tier,
      min_E = r6(bt$min_E),
      pct_E_lt5 = r6(bt$pct_cells_E_lt5),
      cohen_w = r6(bt$cohen_w),
      flag = flag$flag,
      counts = if (keep_counts) as.numeric(cnt$count) else NULL,
      residuals = if (keep_counts) r6(bt$residuals) else NULL
    )
  }
  out[order(vapply(out, function(z) z$n, numeric(1)), decreasing = TRUE)]
}

## --------------------------------------------------------------------------
## schema / quality helpers
## --------------------------------------------------------------------------
is_date_name <- function(nm) grepl("date|_dt$|timestamp|period_of_performance", nm, ignore.case = TRUE)
is_id_name <- function(nm) grepl("(^|_)(id|key|uei|duns|code|zip|fips|number|no)($|_)|piid|identifier|unique_key", nm, ignore.case = TRUE)
is_amount_name <- function(nm) grepl("amount|obligation|revenue|price|balance|value|total|unitprice|quantity", nm, ignore.case = TRUE)

column_schema <- function(dt, roles = NULL, mapped = NULL, max_sample = 1) {
  out <- lapply(names(dt), function(nm) {
    x <- dt[[nm]]
    u <- length(unique(x[!is.na(x)]))
    role <- if (!is.null(roles) && !is.na(roles[nm])) roles[[nm]] else {
      if (is_id_name(nm)) "identifier"
      else if (is_date_name(nm)) "date"
      else if (is.numeric(x) && u > 30) "numeric"
      else if (is.numeric(x)) "categorical"
      else if (u <= 30) "categorical"
      else "text"
    }
    list(
      name = nm,
      mapped = if (!is.null(mapped) && !is.na(mapped[nm])) mapped[[nm]] else "",
      role = role,
      type = if (inherits(x, "Date")) "date" else if (is.numeric(x)) "numeric" else if (is.logical(x)) "boolean" else "text",
      missing = sum(is.na(x)),
      missingPct = pct(sum(is.na(x)), length(x)),
      unique = u,
      sample = clip_chr(x[!is.na(x)][1], 42)
    )
  })
  out
}

quality_block <- function(dt, amount = NULL, date = NULL, id = NULL,
                          group = NULL, signature = NULL) {
  n <- nrow(dt)
  cells <- n * ncol(dt)
  miss <- sum(is.na(dt))
  amount_na <- if (!is.null(amount)) sum(is.na(dt[[amount]])) else NA_integer_
  amt <- if (!is.null(amount)) suppressWarnings(as.numeric(dt[[amount]])) else NULL
  dup_rows <- sum(duplicated(dt))
  id_dup <- if (!is.null(id)) sum(duplicated(dt[[id]])) else NA_integer_
  sig_dup <- if (!is.null(signature)) sum(duplicated(dt[[signature]])) else NA_integer_
  grp_missing <- if (!is.null(group)) sum(is.na(dt[[group]]) | !nzchar(as.character(dt[[group]]))) else NA_integer_
  dts <- if (!is.null(date)) suppressWarnings(as.Date(dt[[date]])) else NULL
  list(
    rows = n,
    cols = ncol(dt),
    cells = cells,
    missingCells = miss,
    missingPct = pct(miss, cells),
    duplicateRows = dup_rows,
    duplicateRowPct = pct(dup_rows, n),
    missingAmount = amount_na,
    missingAmountPct = pct(amount_na, n),
    zeroAmounts = if (!is.null(amt)) sum(amt == 0, na.rm = TRUE) else NA_integer_,
    negativeAmounts = if (!is.null(amt)) sum(amt < 0, na.rm = TRUE) else NA_integer_,
    invalidAmounts = if (!is.null(amt)) sum(is.na(amt) & !is.na(dt[[amount]])) else NA_integer_,
    missingDates = if (!is.null(dts)) sum(is.na(dts)) else NA_integer_,
    minDate = if (!is.null(dts)) as.character(min(dts, na.rm = TRUE)) else NA_character_,
    maxDate = if (!is.null(dts)) as.character(max(dts, na.rm = TRUE)) else NA_character_,
    idDuplicates = id_dup,
    signatureDuplicates = sig_dup,
    missingGroups = grp_missing
  )
}

suitability_block <- function(values, label) {
  v <- values[is.finite(values) & values > 0]
  n <- length(v)
  rng <- if (n > 0) log10(max(v) / min(v)) else NA_real_
  uniq <- if (n > 0) length(unique(v)) / n else NA_real_
  skew <- if (n > 2) moment_skewness(v) else NA_real_
  round_share <- if (n > 0) mean(v >= 1000 & v %% 1000 == 0) else NA_real_
  checks <- list()
  add <- function(key, ok, detail) checks[[length(checks) + 1]] <<- list(key = key, ok = ok, detail = detail)
  add("Sample size", n >= 110, sprintf("N = %s eligible positive values (minimum 110 for all first-digit expected counts to reach 5).", format(n, big.mark = ",")))
  add("Dynamic range", is.finite(rng) && rng >= 2, ifelse(is.finite(rng), sprintf("%.2f orders of magnitude between the smallest and largest value (>= 2 preferred).", rng), "Range not computable."))
  add("Right skew", is.finite(skew) && skew > 0, ifelse(is.finite(skew), sprintf("Moment skewness %.2f. Benford is a better reference for right-skewed, multiplicative data.", skew), "Skewness not computable."))
  add("Uniqueness", is.finite(uniq) && uniq >= 0.5, ifelse(is.finite(uniq), sprintf("%.0f%% of values are distinct; heavy ties often indicate codes or capped values.", 100 * uniq), "Uniqueness not computable."))
  add("No hard ceiling", !(is.finite(round_share) && round_share > 0.5), ifelse(is.finite(round_share), sprintf("%.1f%% of values are exact multiples of 1,000.", 100 * round_share), "Rounding share not computable."))
  hard <- sum(!vapply(checks, function(c) isTRUE(c$ok), logical(1)))
  verdict <- if (n < 110) "Insufficient" else if (hard >= 3) "Unsuitable" else if (hard >= 1) "Use with caution" else "Suitable"
  list(label = label, n = n, rangeOrders = r6(rng), skewness = r6(skew),
       uniqueShare = r6(uniq), roundShare = r6(round_share),
       checks = checks, verdict = verdict)
}

## ==========================================================================
## USAspending / federal contract transactions
## ==========================================================================
build_usaspending <- function() {
  f <- file.path(root, "data/raw/PrimeTransactions_2026-10-19_H05M29S23704379/Contracts_PrimeTransactions_2026-10-19_H05M30S19_1.csv")
  if (!file.exists(f)) return(NULL)
  sel <- c("contract_transaction_unique_key", "contract_award_unique_key",
           "award_id_piid", "modification_number", "transaction_number",
           "federal_action_obligation", "total_dollars_obligated",
           "action_date", "action_date_fiscal_year", "awarding_agency_name",
           "awarding_sub_agency_name", "recipient_name", "recipient_uei",
           "award_type", "transaction_description", "naics_code",
           "naics_description", "product_or_service_code",
           "primary_place_of_performance_state_name")
  d <- fread(f, select = sel, showProgress = FALSE, colClasses = list(character = c(
    "contract_transaction_unique_key", "contract_award_unique_key", "award_id_piid",
    "modification_number", "transaction_number", "action_date",
    "awarding_agency_name", "awarding_sub_agency_name", "recipient_name",
    "recipient_uei", "award_type", "transaction_description", "naics_code",
    "naics_description", "product_or_service_code",
    "primary_place_of_performance_state_name"
  )))
  setnames(d, c(
    "transaction_key", "award_key", "award_id", "modification", "transaction_no",
    "amount", "total_obligated", "date", "fiscal_year", "agency", "subagency",
    "recipient", "recipient_uei", "award_type", "description", "naics",
    "naics_description", "psc", "state"
  ))
  d[, date := as.Date(date)]
  d[, `:=`(agency = as.character(agency), subagency = as.character(subagency),
           recipient = as.character(recipient), award_type = as.character(award_type),
           description = as.character(description), naics = as.character(naics),
           naics_description = as.character(naics_description),
           state = as.character(state), award_id = as.character(award_id),
           recipient_uei = as.character(recipient_uei))]
  d[, naics2 := substr(gsub("[^0-9]", "", naics), 1, 2)]
  d[nchar(naics2) < 2, naics2 := "NA"]
  d[, month := format(date, "%Y-%m")]
  d[, positive := is.finite(amount) & amount > 0]
  d[, log_amount := NA_real_]
  d[positive == TRUE, log_amount := log10(amount)]

  ## ---- peer group ladder -------------------------------------------------
  d[, `:=`(
    peer1 = paste(subagency, award_type, naics2, sep = " | "),
    peer2 = paste(subagency, award_type, sep = " | "),
    peer3 = paste(award_type, sep = " | "),
    peer4 = "All positive transactions"
  )]
  levels <- c("Subagency \u00b7 award type \u00b7 NAICS sector",
              "Subagency \u00b7 award type", "Award type", "All transactions")
  pos <- d[positive == TRUE]
  counts <- rbindlist(lapply(1:4, function(i) {
    pos[, .N, by = .(key = get(paste0("peer", i)))][, level := levels[i]]
  }))
  setnames(counts, "N", "n")
  counts[, levelIdx := match(level, levels)]
  ## for each row choose the narrowest level whose group has n >= 30
  cnt1 <- counts[levelIdx == 1, .(peer1 = key, n1 = n)]
  cnt2 <- counts[levelIdx == 2, .(peer2 = key, n2 = n)]
  cnt3 <- counts[levelIdx == 3, .(peer3 = key, n3 = n)]
  d <- merge(d, cnt1, by = "peer1", all.x = TRUE, sort = FALSE)
  d <- merge(d, cnt2, by = "peer2", all.x = TRUE, sort = FALSE)
  d <- merge(d, cnt3, by = "peer3", all.x = TRUE, sort = FALSE)
  d[is.na(n1), n1 := 0L]; d[is.na(n2), n2 := 0L]; d[is.na(n3), n3 := 0L]
  d[, levelIdx := fifelse(positive & n1 >= 30, 1L,
                    fifelse(positive & n2 >= 30, 2L,
                      fifelse(positive & n3 >= 30, 3L, 4L)))]
  d[, peerLabel := fifelse(levelIdx == 1, peer1,
                     fifelse(levelIdx == 2, peer2,
                       fifelse(levelIdx == 3, peer3, peer4)))]
  d[, peerLevel := levels[levelIdx]]
  ## recompute the selected group's size and stats
  stats <- d[positive == TRUE, .(
    peerN = .N,
    med = median(log_amount, na.rm = TRUE),
    q1 = as.numeric(quantile(log_amount, .25, na.rm = TRUE)),
    q3 = as.numeric(quantile(log_amount, .75, na.rm = TRUE)),
    mad = median(abs(log_amount - median(log_amount, na.rm = TRUE)), na.rm = TRUE)
  ), by = peerLabel]
  stats[, `:=`(iqr = q3 - q1, lower = q1 - 1.5 * (q3 - q1), upper = q3 + 1.5 * (q3 - q1))]
  d <- merge(d, stats, by = "peerLabel", all.x = TRUE, sort = FALSE)
  d[, pctile := frank(log_amount, ties.method = "average") / peerN, by = peerLabel]
  d[, z := fifelse(mad > 0, 0.6745 * (log_amount - med) / mad, NA_real_)]

  ## ---- rounding ----------------------------------------------------------
  d[, integer_amount := abs(amount - round(amount)) < 1e-9]
  d[, int_str := fifelse(integer_amount, sprintf("%.0f", abs(amount)), "")]
  d[, trailing_zeros := fifelse(integer_amount,
      nchar(int_str) - nchar(sub("0+$", "", int_str)), 0L)]
  d[, round_1k := positive & amount >= 1000 & abs(amount %% 1000) < 1e-9]
  d[, round_100 := positive & amount >= 100 & abs(amount %% 100) < 1e-9]
  d[, peer_round_share := mean(round_1k, na.rm = TRUE), by = peerLabel]

  ## ---- duplication -------------------------------------------------------
  d[, sig := paste(award_id, date, modification, recipient_uei, sprintf("%.2f", amount), sep = "|")]
  d[, sig_count := .N, by = sig]
  d[, award_amount_count := .N, by = .(award_id, amount)]
  d[, txn_dup := duplicated(transaction_key) | duplicated(transaction_key, fromLast = TRUE)]

  ## ---- flags -------------------------------------------------------------
  d[, iqr_flag := positive & (log_amount > upper | log_amount < lower)]
  d[, z_flag := positive & is.finite(z) & abs(z) >= 3.5]
  d[, rounding_flag := positive & round_1k & peer_round_share <= 0.20 & amount >= 1000]
  d[, dup_sig_flag := sig_count > 1]
  d[, dup_amount_flag := award_amount_count >= 5]
  d[, missing_context := is.na(naics) | naics == "" | is.na(recipient) | recipient == ""]
  d[, magnitude_family := iqr_flag | z_flag]
  d[, rounding_family := rounding_flag]
  d[, duplication_family := dup_sig_flag | dup_amount_flag | txn_dup]
  d[, quality_family := missing_context]

  ## transparent review priority: max evidence severity plus a small
  ## multi-family uplift.  It is not a probability of fraud.
  d[, z_sev := pmin(1, pmax(0, (abs(z) - 3.5) / 4))]
  d[, iqr_sev := pmin(1, pmax(0, (pmax(log_amount - upper, lower - log_amount, 0)) /
                               pmax(iqr, 1e-9) / 3))]
  d[, pct_sev := pmin(1, pmax(0, (pctile - 0.99) / 0.01))]
  d[, mag_sev := pmax(z_sev, iqr_sev, pct_sev, na.rm = TRUE)]
  d[, round_sev := fifelse(rounding_flag, 0.62, 0)]
  d[, dup_sev := fifelse(dup_sig_flag, 0.85, fifelse(dup_amount_flag, 0.48, 0))]
  d[, n_families := as.integer(magnitude_family) + as.integer(rounding_family) +
                    as.integer(duplication_family) + as.integer(quality_family)]
  d[, score := pmin(99, round(100 * pmax(mag_sev, round_sev, dup_sev, na.rm = TRUE) +
                               4 * pmax(0, n_families - 1)))]
  d[, candidate := magnitude_family | rounding_family | duplication_family]

  ## reason strings
  d[, reasons := {
    r <- vector("list", .N)
    for (i in seq_len(.N)) {
      zz <- character(0)
      if (isTRUE(z_flag[i])) zz <- c(zz, sprintf("Modified Z = %.2f on log10(amount); peer median is %s.", z[i], fmt_money(10^med[i])))
      if (isTRUE(iqr_flag[i])) zz <- c(zz, sprintf("Outside the 1.5\u00d7IQR fence on the log scale (fence %s to %s).", fmt_money(10^lower[i]), fmt_money(10^upper[i])))
      if (isTRUE(rounding_flag[i])) zz <- c(zz, sprintf("Round-thousand amount while only %.0f%% of this peer group is round-thousand.", 100 * peer_round_share[i]))
      if (isTRUE(dup_sig_flag[i])) zz <- c(zz, sprintf("Repeated transaction signature across %d records (award, date, modification, recipient, amount).", sig_count[i]))
      if (isTRUE(dup_amount_flag[i])) zz <- c(zz, sprintf("The same amount appears %d times on this award.", award_amount_count[i]))
      if (isTRUE(txn_dup[i])) zz <- c(zz, "The transaction identifier itself is repeated.")
      if (isTRUE(missing_context[i])) zz <- c(zz, "Missing NAICS or recipient metadata limits peer interpretation.")
      r[[i]] <- zz
    }
    r
  }]

  flagged <- d[candidate == TRUE | quality_family == TRUE]
  fam_counts <- list(
    magnitude = sum(d$magnitude_family, na.rm = TRUE),
    rounding = sum(d$rounding_family, na.rm = TRUE),
    duplication = sum(d$duplication_family, na.rm = TRUE),
    context = sum(d$quality_family, na.rm = TRUE)
  )
  score_bins <- hist(d[candidate == TRUE, score], breaks = seq(0, 100, by = 10), plot = FALSE)$counts

  ## ---- representative sample for the UI ---------------------------------
  setorder(flagged, -score, -amount, na.last = TRUE)
  sample_dt <- head(flagged, 420)
  records <- lapply(seq_len(nrow(sample_dt)), function(i) {
    r <- sample_dt[i]
    list(
      ref = r$transaction_key,
      amount = r6(r$amount),
      date = as.character(r$date),
      agency = r$agency,
      subagency = r$subagency,
      award = r$award_id,
      recipient = r$recipient,
      naics = r$naics,
      description = clip_chr(r$description, 90),
      peer = r$peerLabel,
      peerLevel = r$peerLevel,
      peerN = r$peerN,
      median = r6(10^r$med),
      mad = r6(r$mad),
      z = r6(r$z),
      percentile = r6(100 * r$pctile),
      trailingZeros = as.integer(r$trailing_zeros),
      round1k = isTRUE(r$round_1k),
      sigCount = as.integer(r$sig_count),
      awardAmountCount = as.integer(r$award_amount_count),
      score = as.integer(r$score),
      families = c(if (isTRUE(r$magnitude_family)) "magnitude",
                   if (isTRUE(r$rounding_family)) "rounding",
                   if (isTRUE(r$duplication_family)) "duplication",
                   if (isTRUE(r$quality_family)) "quality"),
      reasons = as.character(r$reasons[[1]])
    )
  })

  ## ---- peer summaries ----------------------------------------------------
  peer_groups <- d[positive == TRUE, .(
    n = .N,
    median = r6(10^median(log_amount)),
    q1 = r6(10^as.numeric(quantile(log_amount, .25))),
    q3 = r6(10^as.numeric(quantile(log_amount, .75))),
    mad = r6(median(abs(log_amount - median(log_amount)))),
    upper = r6(10^upper[1]),
    lower = r6(10^lower[1]),
    flagged = sum(candidate, na.rm = TRUE)
  ), by = .(label = peerLabel, level = peerLevel)]
  setorder(peer_groups, -n)
  peer_groups <- head(peer_groups, 44)

  ## histograms on a shared log scale
  hist_edges <- seq(floor(min(d$log_amount, na.rm = TRUE) * 2) / 2,
                    ceiling(max(d$log_amount, na.rm = TRUE) * 2) / 2,
                    length.out = 25)
  hists <- lapply(seq_len(nrow(peer_groups)), function(i) {
    v <- d[peerLabel == peer_groups$label[i] & positive == TRUE, log_amount]
    as.numeric(hist(v, breaks = hist_edges, plot = FALSE)$counts)
  })

  ## ---- group Benford tests ----------------------------------------------
  pv <- d[positive == TRUE]
  fam_award <- group_tests(pv$amount, pv$award_type, "first",
                           "Award type (first digit)", min_n = 110)
  fam_sub <- group_tests(pv$amount, pv$subagency, "first",
                         "Subagency (first digit)", min_n = 110)
  fam_naics <- group_tests(pv$amount, pv$naics2, "first",
                           "NAICS sector (first digit)", min_n = 110)
  fam_sub_award <- group_tests(pv$amount, paste(pv$subagency, pv$award_type, sep = " \u00b7 "),
                               "first", "Subagency \u00d7 award type (first digit)", min_n = 110)
  fam_first2 <- group_tests(pv$amount, pv$award_type, "first2",
                            "Award type (first two digits)", min_n = 1150)
  fam_second <- group_tests(pv$amount, pv$award_type, "second",
                            "Award type (second digit)", min_n = 110)

  ## ---- trends ------------------------------------------------------------
  monthly <- d[, .(count = .N, obligated = sum(amount, na.rm = TRUE),
                   flagged = sum(candidate, na.rm = TRUE)), by = month]
  setorder(monthly, month)

  ## ---- full downloads ----------------------------------------------------
  export <- flagged[order(-score, -amount), .(
    transaction_key, award_id, modification, date, fiscal_year, agency, subagency,
    recipient, recipient_uei, naics, award_type, amount, peerLevel, peerLabel, peerN,
    median_amount = 10^med, mad_log = mad, modified_z = z, percentile = 100 * pctile,
    iqr_flag, z_flag, rounding_flag, trailing_zeros, dup_sig_flag, dup_amount_flag,
    quality_flag = missing_context, score,
    magnitude = magnitude_family, rounding = rounding_family,
    duplication = duplication_family,
    reasons = vapply(reasons, function(z) paste(z, collapse = " | "), character(1))
  )]
  fwrite(export, file.path(web_dir, "downloads", "usaspending_review_candidates.csv"))

  groups_export <- rbindlist(c(fam_award, fam_sub, fam_naics, fam_sub_award, fam_first2, fam_second), fill = TRUE)
  fwrite(groups_export[, .(family, group, n, chi2, p, df, mad, band, tier, min_E, cohen_w, flag)],
         file.path(web_dir, "downloads", "usaspending_benford_groups.csv"))

  schema <- column_schema(d[, .(transaction_key, award_id, modification, transaction_no,
                                amount, total_obligated, date, fiscal_year, agency,
                                subagency, recipient, recipient_uei, award_type,
                                description, naics, naics_description, psc, state)],
    roles = c(transaction_key = "identifier", award_id = "identifier",
              modification = "identifier", transaction_no = "identifier",
              amount = "measure", total_obligated = "measure", date = "date",
              fiscal_year = "time", agency = "group", subagency = "group",
              recipient = "group", recipient_uei = "identifier", award_type = "group",
              description = "text", naics = "group", naics_description = "text",
              psc = "group", state = "group"),
    mapped = c(transaction_key = "transaction_id", award_id = "award_id",
               modification = "modification", transaction_no = "transaction_no",
               amount = "amount", total_obligated = "award_total",
               date = "action_date", fiscal_year = "fiscal_year",
               agency = "awarding_agency", subagency = "awarding_subagency",
               recipient = "recipient_name", recipient_uei = "recipient_id",
               award_type = "award_type", description = "description",
               naics = "naics", naics_description = "naics_description",
               psc = "product_service_code", state = "place_of_performance"))

  q <- quality_block(d[, .(transaction_key, award_id, modification, amount, date,
                           subagency, award_type, recipient, naics)],
                     amount = "amount", date = "date", id = "transaction_key",
                     group = "award_type")
  q$zeroAmounts <- sum(d$amount == 0, na.rm = TRUE)
  q$negativeAmounts <- sum(d$amount < 0, na.rm = TRUE)
  q$negativeShare <- pct(q$negativeAmounts, nrow(d))
  q$positiveAmounts <- sum(d$positive, na.rm = TRUE)
  q$retained <- q$positiveAmounts
  q$excluded <- nrow(d) - q$positiveAmounts
  q$idDuplicates <- sum(duplicated(d$transaction_key))
  q$signatureDuplicates <- sum(duplicated(d$sig))
  q$missingGroups <- sum(is.na(d$award_type) | d$award_type == "")
  q$duplicateAwards <- sum(duplicated(d$award_key))

  bt_first <- benford_values(pv$amount, "first")
  bt_first2 <- benford_values(pv$amount, "first2")
  bt_second <- benford_values(pv$amount, "second")

  list(
    id = "usaspending",
    name = "Federal Contract Transactions",
    short = "USAspending",
    category = "Unlabelled \u00b7 federal spending",
    kind = "unlabelled",
    source = "USAspending.gov Advanced Search export",
    url = "https://www.usaspending.gov/search",
    file = basename(f),
    path = "data/raw/PrimeTransactions_2026-10-19_H05M29S23704379/Contracts_PrimeTransactions_2026-10-19_H05M30S19_1.csv",
    sizeBytes = file.info(f)$size,
    downloaded = "2026-10-19",
    filters = "Fiscal year 2024 \u00b7 Contracts \u00b7 Transaction level \u00b7 Department of Veterans Affairs",
    description = "Transaction-level federal prime contract actions for FY2024. Amount is federal_action_obligation; negative values are de-obligations, not fraud labels.",
    caveat = "Unlabelled. A review flag is a screening prompt, not evidence of fraud. The export covers one awarding agency, so agency-level comparison is unavailable.",
    rows = nrow(d),
    cols = 297,
    mappedCols = 18,
    schema = schema,
    fieldMap = list(
      list(source = "contract_transaction_unique_key", internal = "transaction_id"),
      list(source = "award_id_piid", internal = "award_id"),
      list(source = "modification_number", internal = "modification"),
      list(source = "federal_action_obligation", internal = "amount"),
      list(source = "action_date", internal = "action_date"),
      list(source = "action_date_fiscal_year", internal = "fiscal_year"),
      list(source = "awarding_agency_name", internal = "awarding_agency"),
      list(source = "awarding_sub_agency_name", internal = "awarding_subagency"),
      list(source = "recipient_name", internal = "recipient_name"),
      list(source = "recipient_uei", internal = "recipient_id"),
      list(source = "award_type", internal = "award_type"),
      list(source = "transaction_description", internal = "description"),
      list(source = "naics_code", internal = "naics"),
      list(source = "product_or_service_code", internal = "product_service_code")
    ),
    measure = list(column = "federal_action_obligation", label = "Federal action obligation",
                   currency = "USD", n = length(pv$amount), note = "Positive obligations only for digit and peer analysis; 20,104 de-obligations and 10,527 zero actions are retained and counted separately."),
    quality = q,
    suitability = suitability_block(pv$amount, "Federal action obligation (positive)"),
    benford = list(first = bt_first, first2 = bt_first2, second = bt_second),
    groups = list(first = c(fam_award, fam_sub, fam_naics, fam_sub_award),
                  first2 = fam_first2, second = fam_second),
    anomalies = list(
      available = TRUE,
      method = "Log-scale IQR + modified Z + peer percentiles + rounding + duplicate signatures",
      eligible = length(pv$amount),
      candidates = sum(d$candidate, na.rm = TRUE),
      highPriority = sum(d$score >= 60, na.rm = TRUE),
      families = fam_counts,
      scoreBins = as.numeric(score_bins),
      peerLevels = as.numeric(table(factor(d$peerLevel, levels = levels))),
      peerLevelLabels = levels,
      sample = records,
      thresholds = list(z = 3.5, iqr = 1.5, minPeer = 30, roundShare = 0.20)
    ),
    peers = list(
      levels = levels,
      levelCounts = setNames(as.list(as.numeric(table(factor(d$peerLevel, levels = levels)))), levels),
      groups = lapply(seq_len(nrow(peer_groups)), function(i) {
        c(as.list(peer_groups[i]), list(hist = hists[[i]]))
      }),
      histEdges = r6(hist_edges),
      trend = list(labels = monthly$month, count = monthly$count,
                   value = r6(monthly$obligated), flagged = as.numeric(monthly$flagged),
                   label = "Monthly obligated amount", unit = "USD")
    ),
    model = NULL,
    available = c("benford", "anomaly", "peers", "quality")
  )
}


## ==========================================================================
## shared supervised-model helpers
## ==========================================================================
auc_roc <- function(p, y) {
  ok <- is.finite(p) & !is.na(y)
  p <- p[ok]; y <- y[ok]
  n1 <- sum(y == 1); n0 <- sum(y == 0)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(p, ties.method = "average")
  (sum(r[y == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

auc_pr <- function(p, y) {
  ok <- is.finite(p) & !is.na(y)
  p <- p[ok]; y <- y[ok]
  if (sum(y == 1) == 0) return(NA_real_)
  ord <- order(p, decreasing = TRUE)
  y <- y[ord]
  tp <- cumsum(y == 1); fp <- cumsum(y == 0)
  prec <- tp / pmax(tp + fp, 1); rec <- tp / sum(y == 1)
  prec <- c(1, prec); rec <- c(0, rec)
  sum(diff(rec) * (head(prec, -1) + tail(prec, -1)) / 2)
}

eval_at <- function(p, y, thr) {
  pred <- as.integer(p >= thr)
  tp <- sum(pred == 1 & y == 1); fp <- sum(pred == 1 & y == 0)
  tn <- sum(pred == 0 & y == 0); fn <- sum(pred == 0 & y == 1)
  precision <- if (tp + fp) tp / (tp + fp) else NA_real_
  recall <- if (tp + fn) tp / (tp + fn) else NA_real_
  f1 <- if (is.finite(precision) && is.finite(recall) && precision + recall > 0)
    2 * precision * recall / (precision + recall) else 0
  list(threshold = r6(thr), tp = tp, fp = fp, tn = tn, fn = fn,
       precision = r6(precision), recall = r6(recall), f1 = r6(f1),
       specificity = r6(if (tn + fp) tn / (tn + fp) else NA_real_),
       accuracy = r6((tp + tn) / length(y)),
       balancedAccuracy = r6((recall + (if (tn + fp) tn / (tn + fp) else 0)) / 2),
       predictedPositive = tp + fp, n = length(y))
}

tune_threshold <- function(p, y, grid = seq(0.01, 0.99, by = 0.005)) {
  f <- vapply(grid, function(t) {
    m <- eval_at(p, y, t)
    if (!is.finite(m$f1)) 0 else m$f1
  }, numeric(1))
  if (all(!is.finite(f)) || max(f, na.rm = TRUE) <= 0) return(0.5)
  grid[which.max(f)]
}

curve_points <- function(p, y, n = 140) {
  ok <- is.finite(p) & !is.na(y)
  p <- p[ok]; y <- y[ok]
  if (!length(p)) return(list(roc = list(), pr = list()))
  qs <- unique(quantile(p, probs = seq(0, 1, length.out = n), na.rm = TRUE))
  rows <- lapply(qs, function(t) {
    pred <- p >= t
    tp <- sum(pred & y == 1); fp <- sum(pred & y == 0)
    fn <- sum(!pred & y == 1); tn <- sum(!pred & y == 0)
    list(t = t,
         fpr = if (fp + tn) fp / (fp + tn) else 0,
         tpr = if (tp + fn) tp / (tp + fn) else 0,
         precision = if (tp + fp) tp / (tp + fp) else 1,
         recall = if (tp + fn) tp / (tp + fn) else 0)
  })
  list(
    roc = list(fpr = vapply(rows, `[[`, 0, "fpr"),
               tpr = vapply(rows, `[[`, 0, "tpr")),
    pr = list(recall = vapply(rows, `[[`, 0, "recall"),
              precision = vapply(rows, `[[`, 0, "precision"),
              baseline = mean(y))
  )
}

fit_scaler <- function(X) {
  mu <- colMeans(X)
  sdv <- apply(X, 2, stats::sd)
  sdv[!is.finite(sdv) | sdv == 0] <- 1
  list(mean = mu, sd = sdv)
}
scale_with <- function(X, sc) {
  sweep(sweep(X, 2, sc$mean, "-"), 2, sc$sd, "/")
}
fit_logistic <- function(X, y, weights = NULL) {
  X1 <- cbind("(Intercept)" = 1, X)
  fit <- suppressWarnings(stats::glm.fit(X1, y, family = stats::binomial(),
                                         weights = weights))
  coef <- fit$coefficients
  coef[!is.finite(coef)] <- 0
  list(coef = coef, converged = isTRUE(fit$converged), iterations = fit$iter)
}
predict_logistic <- function(m, X) {
  as.numeric(stats::plogis(cbind("(Intercept)" = 1, X) %*% m$coef))
}
fit_forest <- function(X, y, seed = 2025, trees = 200, pos_weight = 20, mtry = NULL) {
  df <- as.data.frame(X)
  if (is.null(mtry)) mtry <- max(2L, floor(sqrt(ncol(X))))
  ranger::ranger(
    x = df, y = factor(y, levels = c(0, 1)),
    num.trees = trees, probability = TRUE,
    seed = seed, num.threads = 4, min.node.size = 10,
    sample.fraction = 0.6, mtry = mtry,
    class.weights = c("0" = 1, "1" = pos_weight),
    respect.unordered.factors = "order"
  )
}
predict_forest <- function(m, X) {
  as.numeric(predict(m, data = as.data.frame(X))$predictions[, "1"])
}
top_importance <- function(named, k = 12) {
  named <- named[is.finite(named)]
  if (!length(named)) return(list())
  named <- sort(abs(named), decreasing = TRUE)
  named <- head(named, k)
  list(name = names(named), value = r6(as.numeric(named)))
}

stratified_split <- function(y, seed = 2025, props = c(0.70, 0.15, 0.15)) {
  set.seed(seed)
  idx1 <- which(y == 1); idx0 <- which(y == 0)
  take <- function(idx) {
    idx <- sample(idx)
    n <- length(idx)
    c1 <- floor(n * props[1]); c2 <- floor(n * props[2])
    list(train = idx[seq_len(c1)],
         val = idx[(c1 + 1):(c1 + c2)],
         test = idx[(c1 + c2 + 1):n])
  }
  a <- take(idx1); b <- take(idx0)
  list(train = c(a$train, b$train), val = c(a$val, b$val), test = c(a$test, b$test))
}

model_block <- function(id, label, target, positive, y, train_idx, val_idx, test_idx,
                        X, Xs, p_log_val, p_rf_val, p_log_test, p_rf_test,
                        log_model, rf_model, features, excluded, split_note,
                        sample_rows, prevalence_all, threshold_note = "") {
  thr_log <- tune_threshold(p_log_val, y[val_idx])
  thr_rf <- tune_threshold(p_rf_val, y[val_idx])
  m_log <- eval_at(p_log_test, y[test_idx], thr_log)
  m_rf <- eval_at(p_rf_test, y[test_idx], thr_rf)
  m_log$roc_auc <- r6(auc_roc(p_log_test, y[test_idx]))
  m_log$pr_auc <- r6(auc_pr(p_log_test, y[test_idx]))
  m_rf$roc_auc <- r6(auc_roc(p_rf_test, y[test_idx]))
  m_rf$pr_auc <- r6(auc_pr(p_rf_test, y[test_idx]))
  curves_log <- curve_points(p_log_test, y[test_idx])
  curves_rf <- curve_points(p_rf_test, y[test_idx])
  imp_log <- top_importance(setNames(log_model$coef[-1], features))
  imp_rf <- top_importance(rf_model$variable.importance)
  list(
    available = TRUE,
    dataset = id,
    label = label,
    target = target,
    positiveClass = positive,
    prevalence = r6(prevalence_all),
    split = list(
      strategy = split_note,
      train = length(train_idx), validation = length(val_idx), test = length(test_idx),
      trainFraud = sum(y[train_idx] == 1), validationFraud = sum(y[val_idx] == 1),
      testFraud = sum(y[test_idx] == 1),
      trainPrevalence = r6(mean(y[train_idx])), testPrevalence = r6(mean(y[test_idx]))
    ),
    features = features,
    excluded = excluded,
    seed = 2025,
    trainedAt = format(Sys.time(), "%Y-%m-%d %H:%M"),
    models = list(
      logistic = list(
        name = "Logistic regression",
        role = "Interpretable baseline",
        threshold = r6(thr_log),
        metrics = m_log,
        curve = curves_log,
        importance = imp_log,
        importanceLabel = "Absolute standardised coefficient",
        note = threshold_note
      ),
      forest = list(
        name = "Random forest (ranger)",
        role = "Non-linear benchmark",
        threshold = r6(thr_rf),
        metrics = m_rf,
        curve = curves_rf,
        importance = imp_rf,
        importanceLabel = "Gini variable importance",
        note = "200 trees, minimum node size 10, class-weighted; threshold tuned on validation only."
      )
    ),
    sample = sample_rows,
    limitations = c(
      "Metrics describe this benchmark's held-out test split, not real-world fraud detection.",
      "The test set is kept at its original prevalence; it is never balanced to improve the reported numbers.",
      "A threshold tuned on validation maximises F1 and is then frozen for the test evaluation.",
      "Identifiers and outcome-derived fields are excluded from the predictors."
    )
  )
}


source(file.path(root, "scripts", "build_web_data_main.R"))
