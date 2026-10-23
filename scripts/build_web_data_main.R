## ==========================================================================
## assembly
## ==========================================================================
source(file.path(root, "scripts", "build_web_data_wdi.R"))
source(file.path(root, "scripts", "build_web_data_labelled.R"))
source(file.path(root, "scripts", "build_web_data_retail.R"))

log_msg <- function(...) cat(format(Sys.time(), "%H:%M:%S"), " ", ..., "\n", sep = "")

build_one <- function(id, fn) {
  log_msg("building ", id, " ...")
  t0 <- Sys.time()
  out <- tryCatch(fn(), error = function(e) {
    log_msg("FAILED ", id, ": ", conditionMessage(e))
    structure(list(error = conditionMessage(e)), class = "build_error")
  })
  if (inherits(out, "build_error")) return(out)
  log_msg("  done in ", round(difftime(Sys.time(), t0, units = "secs"), 1), " s")
  out
}

datasets <- list()
if (want("usaspending")) datasets$usaspending <- build_one("usaspending", build_usaspending)
if (want("creditcard")) datasets$creditcard <- build_one("creditcard", build_creditcard)
if (want("paysim")) datasets$paysim <- build_one("paysim", build_paysim)
if (want("retail")) datasets$retail <- build_one("retail", build_retail)
if (want("wdi")) datasets$wdi <- build_one("wdi", build_wdi)

if (file.exists(file.path(root, "web/assets/js/data.js")) && length(only)) {
  log_msg("partial run requested; existing data.js is left untouched.")
}

if (!length(only)) {
  failed <- vapply(datasets, inherits, logical(1), what = "build_error")
  if (any(failed)) {
    stop("One or more dataset builders failed: ", paste(names(datasets)[failed], collapse = ", "))
  }

  ## ---- registry ----------------------------------------------------------
  registry <- lapply(datasets, function(d) {
    list(
      id = d$id, name = d$name, short = d$short, category = d$category,
      kind = d$kind, source = d$source, url = d$url, file = d$file,
      path = d$path, rows = d$rows, cols = d$cols, mappedCols = d$mappedCols,
      sizeBytes = d$sizeBytes, downloaded = d$downloaded, filters = d$filters,
      description = d$description, caveat = d$caveat,
      measure = d$measure$label,
      label = if (d$kind == "labelled") d$model$target else NA_character_,
      positiveClass = if (d$kind == "labelled") d$model$positiveClass else NA_character_,
      available = d$available
    )
  })
  registry_dt <- rbindlist(lapply(registry, function(z) as.data.table(z)), fill = TRUE)
  fwrite(registry_dt, file.path(web_dir, "downloads", "dataset_registry.csv"))

  ## ---- model metrics -----------------------------------------------------
  metric_rows <- list()
  for (d in datasets) {
    if (is.null(d$model) || !isTRUE(d$model$available)) next
    for (mname in names(d$model$models)) {
      m <- d$model$models[[mname]]
      metric_rows[[length(metric_rows) + 1]] <- data.table(
        dataset = d$id, model = m$name, threshold = m$threshold,
        test_n = m$metrics$n, test_fraud = d$model$split$testFraud,
        prevalence = d$model$split$testPrevalence,
        tp = m$metrics$tp, fp = m$metrics$fp, tn = m$metrics$tn, fn = m$metrics$fn,
        precision = m$metrics$precision, recall = m$metrics$recall, f1 = m$metrics$f1,
        specificity = m$metrics$specificity, accuracy = m$metrics$accuracy,
        roc_auc = m$metrics$roc_auc, pr_auc = m$metrics$pr_auc
      )
    }
  }
  if (length(metric_rows)) fwrite(rbindlist(metric_rows), file.path(web_dir, "downloads", "model_metrics.csv"))

  ## ---- combined group tables --------------------------------------------
  group_rows <- list()
  for (d in datasets) {
    for (kind in c("first", "first2", "second")) {
      z <- d$groups[[kind]]
      if (!length(z)) next
      for (g in z) {
        group_rows[[length(group_rows) + 1]] <- data.table(
          dataset = d$id, dataset_name = d$name, digit_class = kind,
          family = g$family, group = g$group, n = g$n, chi2 = g$chi2,
          df = g$df, p_raw = g$p, mad = g$mad, band = g$band,
          tier = g$tier, min_E = g$min_E, cohen_w = g$cohen_w, flag = g$flag
        )
      }
    }
  }
  if (length(group_rows)) fwrite(rbindlist(group_rows, fill = TRUE),
                                 file.path(web_dir, "downloads", "benford_groups_all.csv"))

  ## ---- review samples as downloads --------------------------------------
  for (d in datasets) {
    if (is.null(d$anomalies) || !length(d$anomalies$sample)) next
    smp <- rbindlist(lapply(d$anomalies$sample, function(r) as.data.table(r)), fill = TRUE)
    smp[, reasons := vapply(reasons, function(z) paste(z, collapse = " | "), character(1))]
    fwrite(smp, file.path(web_dir, "downloads", paste0("review_candidates_", d$id, ".csv")))
  }

  ## ---- experiment --------------------------------------------------------
  experiment <- build_experiment()

  ## ---- audit / provenance ------------------------------------------------
  raw_files <- list.files(file.path(root, "data/raw"), recursive = TRUE,
                          full.names = TRUE, all.files = FALSE)
  raw_files <- raw_files[file.info(raw_files)$isdir == FALSE]
  raw_files <- raw_files[!grepl("desktop.ini|\\.lnk$", raw_files, ignore.case = TRUE)]
  raw_info <- data.table(
    path = sub(paste0(root, "[/\\\\]"), "", raw_files),
    bytes = file.info(raw_files)$size,
    modified = format(file.info(raw_files)$mtime, "%Y-%m-%d %H:%M")
  )
  setorder(raw_info, -bytes)
  fwrite(raw_info, file.path(web_dir, "downloads", "raw_file_inventory.csv"))

  missing_expected <- data.table(
    dataset = "BankSim",
    expected_file = "data/raw/banksim/bs140513_032310.csv",
    status = "not found",
    note = "Expected target column fraud; no file is present, so no BankSim model was trained."
  )
  fwrite(missing_expected, file.path(web_dir, "downloads", "missing_datasets.csv"))

  audit <- list(
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    rVersion = R.version.string,
    packages = list(
      data.table = as.character(packageVersion("data.table")),
      jsonlite = as.character(packageVersion("jsonlite")),
      ranger = as.character(packageVersion("ranger")),
      readxl = as.character(packageVersion("readxl")),
      readr = as.character(packageVersion("readr"))
    ),
    rawFiles = lapply(seq_len(nrow(raw_info)), function(i) as.list(raw_info[i])),
    missing = list(as.list(missing_expected)),
    datasetChecks = lapply(datasets, function(d) list(
      id = d$id, rows = d$rows, cols = d$cols, mapped = d$mappedCols,
      file = d$file, size = d$sizeBytes, label = if (d$kind == "labelled") d$model$target else "none",
      candidates = if (!is.null(d$anomalies)) d$anomalies$candidates else NA,
      model = if (!is.null(d$model)) "trained" else "not applicable"
    )),
    notes = c(
      "Original raw files are never modified by this build.",
      "Every Benford p-value is computed only when the expected-count validity condition is met.",
      "Unlabelled datasets receive no fabricated fraud labels.",
      "Review candidates are statistical screening prompts, not fraud determinations."
    )
  )
  write_json(audit, file.path(web_dir, "downloads", "audit_summary.json"),
             auto_unbox = TRUE, pretty = TRUE, digits = 8)

  ## ---- payload -----------------------------------------------------------
  ds_named <- setNames(datasets, vapply(datasets, `[[`, "", "id"))
  payload <- list(
    generated = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
    title = "The Benford Field Kit",
    subtitle = "Explainable anomaly detection in transaction data",
    defaultDataset = "usaspending",
    datasets = ds_named,
    registry = registry,
    experiment = experiment,
    audit = audit,
    method = list(
      alpha = 0.05,
      zThreshold = 3.5,
      iqrMultiplier = 1.5,
      minPeer = 30,
      minNFirst = 110,
      minNFirst2 = 1150,
      boundary = "A review candidate is not proof of fraud. Statistical deviation is a screening signal that requires human investigation and corroborating evidence."
    )
  )
  js <- paste0(
    "/* Generated by scripts/build_web_data.R. Do not edit by hand. */\n",
    "window.BENFORD_DATA = ",
    jsonlite::toJSON(payload, auto_unbox = TRUE, digits = 8, na = "null", null = "null"),
    ";\n"
  )
  writeLines(js, file.path(web_dir, "assets", "js", "data.js"), useBytes = TRUE)
  log_msg("wrote web/assets/js/data.js (",
          round(file.info(file.path(web_dir, "assets", "js", "data.js"))$size / 1e6, 2),
          " MB)")

  cat("\nDataset summary\n")
  for (d in datasets) {
    cat(sprintf("  %-12s rows=%-9s cols=%-4s label=%-8s candidates=%-6s model=%s\n",
                d$id, format(d$rows, big.mark = ","), d$cols, d$kind,
                if (!is.null(d$anomalies)) d$anomalies$candidates else "-",
                if (!is.null(d$model)) "trained" else "-"))
  }
  cat("Done. Open web/index.html in a browser.\n")
}
