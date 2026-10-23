## ==========================================================================
## prediction sample shared by the labelled-model builders
## ==========================================================================
prediction_sample <- function(y, p_log, p_rf, Xs, coef, meta, id_field,
                              n_pos = 120, n_neg = 180, seed = 2025) {
  set.seed(seed)
  pos <- which(y == 1); neg <- which(y == 0)
  take <- function(v, n) if (length(v) <= n) v else sample(v, n)
  sel <- c(take(pos, n_pos), take(neg, n_neg))
  set.seed(seed)
  sel <- sample(sel)
  lapply(sel, function(i) {
    contrib <- coef[-1] * Xs[i, ]
    ord <- order(abs(contrib), decreasing = TRUE)[1:3]
    list(
      row = as.integer(i),
      ref = as.character(meta[[id_field]][i]),
      trueLabel = as.integer(y[i]),
      pLogistic = r6(p_log[i]),
      pForest = r6(p_rf[i]),
      amount = if ("amount" %in% names(meta)) r6(meta$amount[i]) else NA,
      date = if ("date" %in% names(meta)) as.character(meta$date[i]) else "",
      groupLabel = if ("groupLabel" %in% names(meta)) as.character(meta$groupLabel[i]) else "",
      extra = if ("extra" %in% names(meta)) as.character(meta$extra[i]) else "",
      drivers = lapply(ord, function(j) list(
        feature = names(contrib)[j],
        contribution = r6(contrib[j]),
        value = r6(Xs[i, j])
      ))
    )
  })
}

## ==========================================================================
## World Bank WDI panel
## ==========================================================================
build_wdi <- function() {
  f <- file.path(root, "data/processed/wdi_clean.csv")
  if (!file.exists(f)) return(NULL)
  w <- fread(f, showProgress = FALSE)
  w[, year := as.integer(year)]
  w[, value := suppressWarnings(as.numeric(value))]
  w[, log_value := NA_real_]
  w[is.finite(value) & value > 0, log_value := log10(value)]
  w[, indicator_label := as.character(indicator_label)]
  w[, region := as.character(region)]
  w[, country_name := as.character(country_name)]
  pos <- w[is.finite(value) & value > 0]

  bt_first <- benford_values(pos$value, "first")
  bt_first2 <- benford_values(pos$value, "first2")
  bt_second <- benford_values(pos$value, "second")

  fam_ind <- group_tests(pos$value, pos$indicator_label, "first",
                         "Indicator (first digit)", min_n = 110)
  gdp <- pos[indicator_code == "NY.GDP.MKTP.CD"]
  fam_region_gdp <- group_tests(gdp$value, gdp$region, "first",
                                "GDP by region (first digit)", min_n = 110)
  fam_ind2 <- group_tests(pos$value, pos$indicator_label, "first2",
                          "Indicator (first two digits)", min_n = 1150)
  fam_ind_second <- group_tests(pos$value, pos$indicator_label, "second",
                                "Indicator (second digit)", min_n = 110)

  w[, peer := paste(indicator_label, year, sep = " \u00b7 ")]
  st <- w[is.finite(value) & value > 0, .(
    peerN = .N,
    med = median(log_value),
    q1 = as.numeric(quantile(log_value, .25)),
    q3 = as.numeric(quantile(log_value, .75)),
    mad = median(abs(log_value - median(log_value)))), by = peer]
  st[, `:=`(iqr = q3 - q1, lower = q1 - 1.5 * (q3 - q1), upper = q3 + 1.5 * (q3 - q1))]
  w <- merge(w, st, by = "peer", all.x = TRUE, sort = FALSE)
  w[, pctile := frank(log_value, ties.method = "average") / peerN, by = peer]
  w[, z := fifelse(mad > 0, 0.6745 * (log_value - med) / mad, NA_real_)]
  w[, candidate := is.finite(value) & value > 0 & peerN >= 30 &
       ((is.finite(z) & abs(z) >= 3.5) | log_value > upper | log_value < lower)]
  w[, score := pmin(99, round(100 * pmax(
    pmin(1, pmax(0, (abs(z) - 3.5) / 4, na.rm = TRUE)),
    pmin(1, pmax(0, (pmax(log_value - upper, lower - log_value, 0)) /
                   pmax(iqr, 1e-9) / 3, na.rm = TRUE)),
    pmin(1, pmax(0, (pctile - 0.99) / 0.01)), na.rm = TRUE)))]

  cand <- w[candidate == TRUE][order(-score, -value)]
  sample_dt <- head(cand, 220)
  records <- lapply(seq_len(nrow(sample_dt)), function(i) {
    r <- sample_dt[i]
    zz <- character(0)
    if (is.finite(r$z) && abs(r$z) >= 3.5)
      zz <- c(zz, sprintf("Modified Z = %.2f against other countries in %s (%d peers).", r$z, r$year, r$peerN))
    if (is.finite(r$log_value) && (r$log_value > r$upper || r$log_value < r$lower))
      zz <- c(zz, sprintf("Outside the peer IQR fence (%s to %s).", fmt_money(10^r$lower), fmt_money(10^r$upper)))
    list(ref = paste(r$country_code, r$indicator_code, r$year, sep = " / "),
         amount = r6(r$value), date = as.character(r$year),
         agency = r$region, subagency = r$income_group,
         award = r$country_name, recipient = r$country_name,
         naics = r$indicator_code, description = r$indicator_label,
         peer = r$peer, peerLevel = "Indicator \u00b7 year", peerN = r$peerN,
         median = r6(10^r$med), mad = r6(r$mad), z = r6(r$z),
         percentile = r6(100 * r$pctile), trailingZeros = 0L,
         round1k = FALSE, sigCount = 1L, awardAmountCount = 1L,
         score = as.integer(r$score), families = "magnitude", reasons = zz)
  })

  grp <- w[is.finite(value) & value > 0, .(
    n = .N,
    median = r6(10^median(log_value)),
    q1 = r6(10^as.numeric(quantile(log_value, .25))),
    q3 = r6(10^as.numeric(quantile(log_value, .75))),
    mad = r6(median(abs(log_value - median(log_value)))),
    upper = r6(10^upper[1]), lower = r6(10^lower[1]),
    flagged = sum(candidate, na.rm = TRUE)), by = .(label = indicator_label)]
  setorder(grp, -n)
  hist_edges <- seq(floor(min(w$log_value, na.rm = TRUE) * 2) / 2,
                    ceiling(max(w$log_value, na.rm = TRUE) * 2) / 2,
                    length.out = 25)
  hists <- lapply(seq_len(nrow(grp)), function(i) as.numeric(hist(
    w[indicator_label == grp$label[i] & is.finite(value) & value > 0, log_value],
    breaks = hist_edges, plot = FALSE)$counts))
  series <- lapply(seq_len(nrow(grp)), function(i) {
    z <- w[indicator_label == grp$label[i] & is.finite(value) & value > 0,
           .(v = median(value)), by = year][order(year)]
    list(label = grp$label[i], labels = as.character(z$year), values = r6(z$v))
  })
  main <- w[indicator_label == "GDP (current USD)" & is.finite(value) & value > 0,
            .(v = median(value)), by = year][order(year)]

  q <- list(
    rows = nrow(w), cols = ncol(w), cells = nrow(w) * ncol(w),
    missingCells = sum(is.na(w[, .(country_code, country_name, region, indicator_code,
                                   indicator_label, year, value)])),
    missingPct = pct(sum(is.na(w[, .(country_code, country_name, region, indicator_code,
                                     indicator_label, year, value)])), nrow(w) * 7),
    duplicateRows = sum(duplicated(w[, .(country_code, indicator_code, year)])),
    duplicateRowPct = pct(sum(duplicated(w[, .(country_code, indicator_code, year)])), nrow(w)),
    missingAmount = sum(!is.finite(w$value)),
    missingAmountPct = pct(sum(!is.finite(w$value)), nrow(w)),
    zeroAmounts = sum(w$value == 0, na.rm = TRUE),
    negativeAmounts = sum(w$value < 0, na.rm = TRUE),
    invalidAmounts = 0L, missingDates = 0L,
    minDate = "1960", maxDate = "2023",
    idDuplicates = 0L, signatureDuplicates = 0L,
    missingGroups = sum(is.na(w$region) | w$region == ""),
    positiveAmounts = nrow(pos), retained = nrow(pos),
    excluded = nrow(w) - nrow(pos)
  )

  list(
    id = "wdi", name = "World Development Indicators", short = "WDI panel",
    category = "Unlabelled \u00b7 national statistics", kind = "unlabelled",
    source = "World Bank WDI bulk CSV (local copy)",
    url = "https://databank.worldbank.org/source/world-development-indicators",
    file = "wdi_clean.csv", path = "data/processed/wdi_clean.csv",
    sizeBytes = file.info(f)$size, downloaded = "2026-10-01",
    filters = "9 curated indicators \u00b7 country-year panel \u00b7 aggregates removed",
    description = "A general numerical panel: GDP, population, trade, land area, reserves, life expectancy and fertility. Two indicators are deliberate negative controls.",
    caveat = "Unlabelled and not a transaction dataset. Benford screening is applied per indicator; the bounded demographic series are expected to fail and serve as negative controls.",
    rows = nrow(w), cols = ncol(w), mappedCols = ncol(w),
    schema = column_schema(w[, .(country_code, country_name, region, income_group,
                                 indicator_code, indicator_label, indicator_role,
                                 year, value, source, is_synthetic)],
      roles = c(country_code = "identifier", country_name = "group", region = "group",
                income_group = "group", indicator_code = "identifier",
                indicator_label = "group", indicator_role = "text", year = "time",
                value = "measure", source = "text", is_synthetic = "flag"),
      mapped = c(country_code = "country_code", country_name = "country_name",
                 region = "region", income_group = "income_group",
                 indicator_code = "indicator", indicator_label = "indicator_label",
                 year = "year", value = "value")),
    fieldMap = list(list(source = "country_code", internal = "country_code"),
                    list(source = "indicator_code", internal = "indicator"),
                    list(source = "year", internal = "year"),
                    list(source = "value", internal = "value")),
    measure = list(column = "value", label = "Indicator value", currency = NA,
                   n = nrow(pos), note = "Positive values only. Units differ by indicator, so each indicator is tested separately."),
    quality = q,
    suitability = suitability_block(pos$value, "Indicator value (all indicators pooled)"),
    benford = list(first = bt_first, first2 = bt_first2, second = bt_second),
    groups = list(first = c(fam_ind, fam_region_gdp), first2 = fam_ind2, second = fam_ind_second),
    anomalies = list(
      available = TRUE,
      method = "Indicator-year peer comparison: robust Z and log IQR fences",
      eligible = nrow(pos), candidates = sum(w$candidate, na.rm = TRUE),
      highPriority = sum(w$score >= 60, na.rm = TRUE),
      families = list(magnitude = sum(w$candidate, na.rm = TRUE), rounding = 0L,
                      duplication = 0L, context = 0L),
      scoreBins = as.numeric(hist(w[candidate == TRUE, score], breaks = seq(0, 100, by = 10), plot = FALSE)$counts),
      peerLevels = c(nrow(pos), 0, 0, 0),
      peerLevelLabels = c("Indicator \u00b7 year", "", "", ""),
      sample = records,
      thresholds = list(z = 3.5, iqr = 1.5, minPeer = 30, roundShare = NA)
    ),
    peers = list(
      levels = "Indicator", levelCounts = list(Indicator = nrow(pos)),
      groups = lapply(seq_len(nrow(grp)), function(i) c(as.list(grp[i]), list(hist = hists[[i]]))),
      histEdges = r6(hist_edges),
      trend = list(labels = as.character(main$year), count = NULL,
                   value = r6(main$v), flagged = NULL,
                   label = "Median GDP (current USD)", unit = "USD"),
      series = series
    ),
    model = NULL,
    available = c("benford", "anomaly", "peers", "quality")
  )
}
