## ==========================================================================
## unlabelled retail transactions
## ==========================================================================
build_retail <- function() {
  f <- file.path(root, "data/raw/online+retail/Online Retail.xlsx")
  if (!file.exists(f)) return(NULL)
  suppressPackageStartupMessages(library(readxl))
  raw <- readxl::read_excel(f, col_types = c(
    "text", "text", "text", "numeric", "date", "numeric", "numeric", "text"))
  d <- as.data.table(raw)
  setnames(d, c("invoice", "stock", "description", "quantity", "invoice_date",
                "unit_price", "customer_id", "country"))
  d[, invoice := as.character(invoice)]
  d[, stock := as.character(stock)]
  d[, country := as.character(country)]
  d[, cancellation := grepl("^C", invoice)]
  d[, revenue := quantity * unit_price]
  d[, row_id := .I]
  pos <- d[is.finite(revenue) & revenue > 0 & quantity > 0 & unit_price > 0]
  bt_first <- benford_values(pos$revenue, "first")
  bt_first2 <- benford_values(pos$revenue, "first2")
  bt_second <- benford_values(pos$revenue, "second")

  fam_country <- group_tests(pos$revenue, pos$country, "first",
                             "Country (first digit)", min_n = 110)
  fam_country2 <- group_tests(pos$revenue, pos$country, "first2",
                              "Country (first two digits)", min_n = 1150)
  fam_country_second <- group_tests(pos$revenue, pos$country, "second",
                                    "Country (second digit)", min_n = 110)
  fam_month <- group_tests(pos$revenue, format(pos$invoice_date, "%Y-%m"), "first",
                           "Month (first digit)", min_n = 110)

  ## peer screening within country
  pos[, log_revenue := log10(revenue)]
  pos[, peer := country]
  st <- pos[, .(
    peerN = .N,
    med = median(log_revenue),
    q1 = as.numeric(quantile(log_revenue, .25)),
    q3 = as.numeric(quantile(log_revenue, .75)),
    mad = median(abs(log_revenue - median(log_revenue)))), by = peer]
  st[, `:=`(iqr = q3 - q1, lower = q1 - 1.5 * (q3 - q1), upper = q3 + 1.5 * (q3 - q1))]
  pos <- merge(pos, st, by = "peer", all.x = TRUE, sort = FALSE)
  pos[, pctile := frank(log_revenue, ties.method = "average") / peerN, by = peer]
  pos[, z := fifelse(mad > 0, 0.6745 * (log_revenue - med) / mad, NA_real_)]
  pos[, whole_dollar := abs(unit_price - round(unit_price)) < 1e-9]
  pos[, peer_whole_share := mean(whole_dollar, na.rm = TRUE), by = peer]
  pos[, iqr_flag := log_revenue > upper | log_revenue < lower]
  pos[, z_flag := is.finite(z) & abs(z) >= 3.5]
  pos[, round_flag := whole_dollar & peerN >= 30 & peer_whole_share <= 0.15 & revenue >= 100]
  pos[, sig := paste(invoice, stock, quantity, sprintf("%.2f", unit_price), sep = "|")]
  pos[, sig_count := .N, by = sig]
  pos[, cust_invoice_count := .N, by = .(customer_id, invoice)]
  pos[, dup_flag := sig_count > 1]
  pos[, magnitude_family := iqr_flag | z_flag]
  pos[, rounding_family := round_flag]
  pos[, duplication_family := dup_flag]
  pos[, quality_family := is.na(customer_id)]
  pos[, z_sev := pmin(1, pmax(0, (abs(z) - 3.5) / 4))]
  pos[, iqr_sev := pmin(1, pmax(0, (pmax(log_revenue - upper, lower - log_revenue, 0)) /
                                 pmax(iqr, 1e-9) / 3))]
  pos[, pct_sev := pmin(1, pmax(0, (pctile - 0.99) / 0.01))]
  pos[, mag_sev := pmax(z_sev, iqr_sev, pct_sev, na.rm = TRUE)]
  pos[, round_sev := fifelse(round_flag, 0.55, 0)]
  pos[, dup_sev := fifelse(dup_flag, 0.65, 0)]
  pos[, n_families := as.integer(magnitude_family) + as.integer(rounding_family) +
                      as.integer(duplication_family) + as.integer(quality_family)]
  pos[, score := pmin(99, round(100 * pmax(mag_sev, round_sev, dup_sev, na.rm = TRUE) +
                                 4 * pmax(0, n_families - 1)))]
  pos[, candidate := magnitude_family | rounding_family | duplication_family]

  cand <- pos[candidate == TRUE][order(-score, -revenue)]
  sample_dt <- head(cand, 300)
  records <- lapply(seq_len(nrow(sample_dt)), function(i) {
    r <- sample_dt[i]
    zz <- character(0)
    if (isTRUE(r$z_flag)) zz <- c(zz, sprintf("Modified Z = %.2f on log line revenue; peer median is %s.", r$z, fmt_money(10^r$med)))
    if (isTRUE(r$iqr_flag)) zz <- c(zz, sprintf("Outside the country's 1.5\u00d7IQR fence (%s to %s).", fmt_money(10^r$lower), fmt_money(10^r$upper)))
    if (isTRUE(r$round_flag)) zz <- c(zz, sprintf("Whole-dollar unit price while only %.0f%% of this country's prices are whole dollars.", 100 * r$peer_whole_share))
    if (isTRUE(r$dup_flag)) zz <- c(zz, sprintf("Repeated invoice-line signature across %d lines.", r$sig_count))
    if (isTRUE(r$quality_family)) zz <- c(zz, "Customer identifier is missing; grouping is limited to country.")
    list(ref = sprintf("OR-%07d", r$row_id), amount = r6(r$revenue),
         date = format(r$invoice_date, "%Y-%m-%d"), agency = r$country,
         subagency = r$stock, award = r$invoice, recipient = ifelse(is.na(r$customer_id), "\u2014", as.character(r$customer_id)),
         naics = r$stock, description = clip_chr(r$description, 90),
         peer = r$peer, peerLevel = "Country", peerN = r$peerN,
         median = r6(10^r$med), mad = r6(r$mad), z = r6(r$z),
         percentile = r6(100 * r$pctile), trailingZeros = 0L,
         round1k = isTRUE(r$round_flag), sigCount = as.integer(r$sig_count),
         awardAmountCount = as.integer(r$cust_invoice_count),
         score = as.integer(r$score), families = c(
           if (isTRUE(r$magnitude_family)) "magnitude",
           if (isTRUE(r$rounding_family)) "rounding",
           if (isTRUE(r$duplication_family)) "duplication",
           if (isTRUE(r$quality_family)) "quality"), reasons = zz)
  })

  grp <- pos[, .(
    n = .N, median = r6(10^median(log_revenue)),
    q1 = r6(10^as.numeric(quantile(log_revenue, .25))),
    q3 = r6(10^as.numeric(quantile(log_revenue, .75))),
    mad = r6(median(abs(log_revenue - median(log_revenue)))),
    upper = r6(10^upper[1]), lower = r6(10^lower[1]),
    flagged = sum(candidate, na.rm = TRUE)), by = .(label = country)]
  setorder(grp, -n)
  grp <- head(grp, 30)
  hist_edges <- seq(floor(min(pos$log_revenue, na.rm = TRUE) * 2) / 2,
                    ceiling(max(pos$log_revenue, na.rm = TRUE) * 2) / 2,
                    length.out = 25)
  hists <- lapply(seq_len(nrow(grp)), function(i) as.numeric(hist(
    pos[country == grp$label[i], log_revenue], breaks = hist_edges, plot = FALSE)$counts))

  monthly <- d[, .(count = .N, revenue = sum(revenue, na.rm = TRUE),
                   cancellations = sum(cancellation, na.rm = TRUE),
                   negative = sum(quantity < 0, na.rm = TRUE)),
               by = .(month = format(invoice_date, "%Y-%m"))]
  setorder(monthly, month)

  q <- quality_block(d[, .(invoice, stock, quantity, unit_price, customer_id, country)],
                     amount = NULL, date = "invoice_date", id = "invoice", group = "country")
  q$rows <- nrow(d); q$cols <- ncol(d); q$cells <- nrow(d) * ncol(d)
  q$missingCells <- sum(is.na(d))
  q$missingPct <- pct(q$missingCells, q$cells)
  q$missingAmount <- sum(!is.finite(d$revenue))
  q$missingAmountPct <- pct(q$missingAmount, nrow(d))
  q$zeroAmounts <- sum(d$revenue == 0, na.rm = TRUE)
  q$negativeAmounts <- sum(d$revenue < 0, na.rm = TRUE)
  q$invalidAmounts <- 0L
  q$duplicateRows <- sum(duplicated(d[, .(invoice, stock, quantity, unit_price, customer_id)]))
  q$duplicateRowPct <- pct(q$duplicateRows, nrow(d))
  q$missingDates <- sum(is.na(d$invoice_date))
  q$minDate <- format(min(d$invoice_date, na.rm = TRUE), "%Y-%m-%d")
  q$maxDate <- format(max(d$invoice_date, na.rm = TRUE), "%Y-%m-%d")
  q$idDuplicates <- 0L
  q$signatureDuplicates <- sum(duplicated(pos$sig))
  q$missingGroups <- sum(is.na(d$country) | d$country == "")
  q$negativeLines <- sum(d$quantity < 0, na.rm = TRUE)
  q$cancellations <- sum(d$cancellation, na.rm = TRUE)
  q$missingCustomers <- sum(is.na(d$customer_id))
  q$missingCustomersPct <- pct(q$missingCustomers, nrow(d))
  q$zeroPrices <- sum(d$unit_price <= 0, na.rm = TRUE)
  q$positiveLines <- nrow(pos)
  q$retained <- nrow(pos)
  q$excluded <- nrow(d) - nrow(pos)

  schema <- column_schema(d[, .(invoice, stock, description, quantity, invoice_date,
                                unit_price, customer_id, country)],
    roles = c(invoice = "identifier", stock = "group", description = "text",
              quantity = "numeric", invoice_date = "date", unit_price = "measure",
              customer_id = "identifier", country = "group"),
    mapped = c(invoice = "invoice_id", stock = "stock_code", quantity = "quantity",
               invoice_date = "invoice_date", unit_price = "unit_price",
               customer_id = "customer_id", country = "country"))

  list(
    id = "retail", name = "Online Retail Transactions", short = "Online retail",
    category = "Unlabelled \u00b7 retail", kind = "unlabelled",
    source = "UCI Online Retail II workbook",
    url = "https://archive.ics.uci.edu/dataset/502/online+retail+ii",
    file = "Online Retail.xlsx", path = "data/raw/online+retail/Online Retail.xlsx",
    sizeBytes = file.info(f)$size, downloaded = "2026-10-19",
    filters = "541,909 invoice lines from a UK online retailer, 2010-12 to 2011-12",
    description = "Line-level retail transactions with quantity, unit price, invoice, stock code and country. Revenue is derived; cancellations are marked in the invoice number.",
    caveat = "Unlabelled. Cancellations and negative quantities are accounting events, not fraud labels. Round prices are normal in retail, so rounding evidence is weak context here.",
    rows = nrow(d), cols = ncol(d), mappedCols = 8,
    schema = schema,
    fieldMap = list(list(source = "InvoiceNo", internal = "invoice_id"),
                    list(source = "StockCode", internal = "stock_code"),
                    list(source = "Quantity", internal = "quantity"),
                    list(source = "UnitPrice", internal = "unit_price"),
                    list(source = "InvoiceDate", internal = "invoice_date"),
                    list(source = "Country", internal = "country")),
    measure = list(column = "Revenue (Quantity \u00d7 UnitPrice)", label = "Line revenue",
                   currency = "GBP", n = nrow(pos),
                   note = "Positive quantity and positive unit price only; cancellations and returns are counted and excluded."),
    quality = q,
    suitability = suitability_block(pos$revenue, "Line revenue (positive)"),
    benford = list(first = bt_first, first2 = bt_first2, second = bt_second),
    groups = list(first = c(fam_country, fam_month), first2 = fam_country2, second = fam_country_second),
    anomalies = list(
      available = TRUE,
      method = "Country peer comparison on log line revenue + duplicate invoice lines",
      eligible = nrow(pos), candidates = sum(pos$candidate, na.rm = TRUE),
      highPriority = sum(pos$score >= 60, na.rm = TRUE),
      families = list(magnitude = sum(pos$magnitude_family, na.rm = TRUE),
                      rounding = sum(pos$rounding_family, na.rm = TRUE),
                      duplication = sum(pos$duplication_family, na.rm = TRUE),
                      context = sum(pos$quality_family, na.rm = TRUE)),
      scoreBins = as.numeric(hist(pos[candidate == TRUE, score], breaks = seq(0, 100, by = 10), plot = FALSE)$counts),
      peerLevels = c(nrow(pos), 0, 0, 0),
      peerLevelLabels = c("Country", "", "", ""),
      sample = records,
      thresholds = list(z = 3.5, iqr = 1.5, minPeer = 30, roundShare = 0.15)
    ),
    peers = list(
      levels = "Country", levelCounts = list(Country = nrow(pos)),
      groups = lapply(seq_len(nrow(grp)), function(i) c(as.list(grp[i]), list(hist = hists[[i]]))),
      histEdges = r6(hist_edges),
      trend = list(labels = monthly$month, count = as.numeric(monthly$count),
                   value = r6(monthly$revenue), flagged = as.numeric(monthly$cancellations),
                   label = "Monthly revenue", unit = "GBP")
    ),
    model = NULL,
    available = c("benford", "anomaly", "peers", "quality")
  )
}

## ==========================================================================
## validation experiment (existing controlled simulation results)
## ==========================================================================
build_experiment <- function() {
  sfile <- file.path(root, "outputs/tables/experiment_summary.csv")
  rfile <- file.path(root, "outputs/tables/experiment_replicates.csv")
  afile <- file.path(root, "outputs/tables/anova_results.csv")
  gfile <- file.path(root, "outputs/tables/regression_results.csv")
  if (!file.exists(sfile)) return(NULL)
  s <- fread(sfile)
  reps <- if (file.exists(rfile)) fread(rfile) else NULL
  a <- if (file.exists(afile)) fread(afile) else NULL
  g <- if (file.exists(gfile)) fread(gfile) else NULL
  mechanisms <- unique(s$manipulation)
  curve <- lapply(mechanisms, function(m) {
    z <- s[manipulation == m][order(true_alteration_rate)]
    list(manipulation = m, levels = as.numeric(z$true_alteration_rate),
         detection = as.numeric(z$detection_rate), mad = r6(z$mean_mad),
         x2 = r6(z$mean_x2), p = r6(z$mean_p))
  })
  reps_summary <- if (!is.null(reps)) {
    z <- reps[, .(n = .N, mean_mad = mean(mad, na.rm = TRUE),
                  sd_mad = sd(mad, na.rm = TRUE),
                  min_mad = min(mad, na.rm = TRUE),
                  max_mad = max(mad, na.rm = TRUE)),
              by = .(manipulation, true_alteration_rate)]
    lapply(seq_len(nrow(z)), function(i) as.list(z[i]))
  } else list()
  list(
    available = TRUE,
    seed = 2025,
    base = "SYNTHETIC log-uniform 10^U(0,6), 2,000 values per replicate",
    replicates = if (!is.null(reps)) nrow(reps) else 0,
    curve = curve,
    summary = lapply(seq_len(nrow(s)), function(i) as.list(s[i])),
    anova = if (!is.null(a)) lapply(seq_len(nrow(a)), function(i) as.list(a[i])) else list(),
    regression = if (!is.null(g)) lapply(seq_len(nrow(g)), function(i) as.list(g[i])) else list(),
    replicateSummary = reps_summary,
    note = "Detection is the share of replicates whose Benford chi-square is significant at alpha = 0.05. False positives are the detection rate in the unaltered control (rate 0). Synthetic results do not prove real-world fraud accuracy."
  )
}
