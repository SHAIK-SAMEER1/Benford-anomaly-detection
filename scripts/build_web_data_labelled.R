## ==========================================================================
## labelled benchmark: credit-card fraud
## ==========================================================================
build_creditcard <- function() {
  f <- file.path(root, "data/raw/creditcard.csv/creditcard.csv")
  if (!file.exists(f)) return(NULL)
  d <- fread(f, showProgress = FALSE)
  d[, row_id := .I]
  y_all <- as.integer(d$Class)
  dm <- unique(d, by = c("Time", paste0("V", 1:28), "Amount", "Class"))
  y <- as.integer(dm$Class)
  feats <- c("Time", paste0("V", 1:28), "Amount")
  X <- as.matrix(dm[, ..feats])
  storage.mode(X) <- "double"
  sc <- fit_scaler(X)
  Xs <- scale_with(X, sc)
  sp <- stratified_split(y, seed = 2025)
  tr <- sp$train; va <- sp$val; te <- sp$test
  n1 <- sum(y[tr] == 1); n0 <- sum(y[tr] == 0)
  w <- ifelse(y[tr] == 1, length(tr) / (2 * n1), length(tr) / (2 * n0))
  log_mod <- fit_logistic(Xs[tr, , drop = FALSE], y[tr], weights = w)
  p_log_va <- predict_logistic(log_mod, Xs[va, , drop = FALSE])
  p_log_te <- predict_logistic(log_mod, Xs[te, , drop = FALSE])
  rf <- fit_forest(Xs[tr, , drop = FALSE], y[tr], seed = 2025, trees = 160,
                   pos_weight = 25, mtry = 6)
  p_rf_va <- predict_forest(rf, Xs[va, , drop = FALSE])
  p_rf_te <- predict_forest(rf, Xs[te, , drop = FALSE])

  meta <- data.table(
    ref = sprintf("CC-%06d", dm$row_id),
    amount = dm$Amount,
    date = sprintf("hour %02d", floor((dm$Time / 3600) %% 24)),
    groupLabel = ifelse(dm$Class == 1, "fraud label", "genuine label"),
    extra = ""
  )
  smp <- prediction_sample(y[te], p_log_te, p_rf_te, Xs[te, , drop = FALSE],
                           log_mod$coef, meta[te], "ref",
                           n_pos = 140, n_neg = 160, seed = 77)

  model <- model_block(
    id = "creditcard", label = "Credit-card fraud benchmark",
    target = "Class", positive = "1 (fraud)",
    y = y, train_idx = tr, val_idx = va, test_idx = te,
    X = X, Xs = Xs,
    p_log_val = p_log_va, p_rf_val = p_rf_va,
    p_log_test = p_log_te, p_rf_test = p_rf_te,
    log_model = log_mod, rf_model = rf,
    features = feats,
    excluded = c("Class (target)", "No identifiers present"),
    split_note = "Stratified 70 / 15 / 15 split, fixed seed 2025; exact duplicate rows removed before splitting.",
    sample_rows = smp, prevalence_all = mean(y_all),
    threshold_note = "Balanced class weights in training only; the test prevalence is unchanged."
  )
  dir.create(file.path(root, "models", "creditcard"), recursive = TRUE, showWarnings = FALSE)
  saveRDS(list(coef = log_mod$coef, scaler = sc, features = feats, seed = 2025),
          file.path(root, "models/creditcard/logistic.rds"))
  saveRDS(rf, file.path(root, "models/creditcard/ranger.rds"))
  write_json(model, file.path(root, "models/creditcard/metadata.json"),
             auto_unbox = TRUE, pretty = TRUE, digits = 8)

  d[, hour_band := sprintf("%02d-%02d", 6 * (floor((Time / 3600) %% 24) %/% 6),
                           6 * (floor((Time / 3600) %% 24) %/% 6) + 5)]
  pos <- d[Amount > 0]
  bt_first <- benford_values(pos$Amount, "first")
  bt_first2 <- benford_values(pos$Amount, "first2")
  bt_second <- benford_values(pos$Amount, "second")
  fam_class <- group_tests(pos$Amount, ifelse(pos$Class == 1, "Fraud label", "Genuine label"),
                           "first", "Amount by outcome class (context only)", min_n = 110)
  fam_hour <- group_tests(pos$Amount, pos$hour_band, "first",
                          "Amount by 6-hour band (first digit)", min_n = 110)
  fam_class2 <- group_tests(pos$Amount, ifelse(pos$Class == 1, "Fraud label", "Genuine label"),
                            "first2", "Amount by outcome class (first two digits)", min_n = 1150)
  fam_class_second <- group_tests(pos$Amount, ifelse(pos$Class == 1, "Fraud label", "Genuine label"),
                                  "second", "Amount by outcome class (second digit)", min_n = 110)

  hourly <- d[, .(count = .N, fraud = sum(Class == 1),
                  volume = sum(Amount, na.rm = TRUE)),
              by = .(hour = as.integer(floor((Time / 3600) %% 24)))]
  setorder(hourly, hour)

  q <- quality_block(d[, .(Time, V1, Amount, Class)],
                     amount = "Amount", id = "row_id", group = "Class")
  q$zeroAmounts <- sum(d$Amount == 0)
  q$negativeAmounts <- sum(d$Amount < 0)
  q$positiveAmounts <- nrow(pos)
  q$retained <- nrow(pos)
  q$excluded <- nrow(d) - nrow(pos)
  q$duplicateRows <- sum(duplicated(d[, .(Time, V1, Amount, Class)]))
  q$duplicateRowPct <- pct(q$duplicateRows, nrow(d))
  q$idDuplicates <- 0L
  q$signatureDuplicates <- 0L
  q$missingGroups <- 0L
  q$missingDates <- 0L
  q$minDate <- "Time 0 s"; q$maxDate <- "Time 172,792 s"

  schema <- column_schema(d[, .(Time, V1, V2, Amount, Class)],
    roles = c(Time = "time", V1 = "numeric", V2 = "numeric",
              Amount = "measure", Class = "label"),
    mapped = c(Amount = "amount", Class = "fraud_label", Time = "elapsed_seconds"))

  list(
    id = "creditcard", name = "Credit-Card Fraud Benchmark", short = "Credit card",
    category = "Labelled \u00b7 benchmark", kind = "labelled",
    source = "ULB Machine Learning Group credit-card fraud dataset",
    url = "https://www.kaggle.com/datasets/mlg-ulb/creditcardfraud",
    file = "creditcard.csv", path = "data/raw/creditcard.csv/creditcard.csv",
    sizeBytes = file.info(f)$size, downloaded = "2026-10-19",
    filters = "284,807 European card transactions over two days; PCA-anonymised predictors",
    description = "A standard imbalanced fraud benchmark with 492 labelled frauds. The 28 V-columns are PCA components, so digit analysis on them is meaningless; Benford is applied only to Amount as context.",
    caveat = "Labels are benchmark labels. A model score here is not a real-world fraud probability, and Benford's Law is not a fraud classifier.",
    rows = nrow(d), cols = ncol(d), mappedCols = 5,
    schema = schema,
    fieldMap = list(list(source = "Amount", internal = "amount"),
                    list(source = "Class", internal = "fraud_label"),
                    list(source = "Time", internal = "elapsed_seconds")),
    measure = list(column = "Amount", label = "Transaction amount", currency = "EUR",
                   n = nrow(pos), note = "Positive amounts only. Zero-amount authorisations are counted and excluded from digit tests."),
    quality = q,
    suitability = suitability_block(pos$Amount, "Transaction amount (positive)"),
    benford = list(first = bt_first, first2 = bt_first2, second = bt_second),
    groups = list(first = c(fam_class, fam_hour), first2 = fam_class2, second = fam_class_second),
    anomalies = list(
      available = FALSE,
      reason = "This dataset has genuine labels. The review page therefore uses supervised model scores and a held-out test set rather than unsupervised anomaly scores.",
      eligible = nrow(pos), candidates = 0L, highPriority = 0L,
      families = list(magnitude = 0L, rounding = 0L, duplication = 0L, context = 0L),
      scoreBins = numeric(0), sample = list()
    ),
    peers = list(
      levels = "Outcome class", levelCounts = list("Outcome class" = nrow(pos)),
      groups = lapply(seq_along(fam_class), function(i) list(
        label = fam_class[[i]]$group, n = fam_class[[i]]$n,
        median = r6(median(pos[ifelse(pos$Class == 1, "Fraud label", "Genuine label") == fam_class[[i]]$group]$Amount)),
        q1 = NA, q3 = NA, mad = NA, upper = NA, lower = NA,
        flagged = 0L, hist = numeric(24))),
      histEdges = numeric(0),
      trend = list(labels = sprintf("%02d", hourly$hour), count = as.numeric(hourly$count),
                   value = r6(hourly$volume), flagged = as.numeric(hourly$fraud),
                   label = "Transactions by hour", unit = "count")
    ),
    model = model,
    available = c("benford", "supervised", "peers", "quality")
  )
}

## ==========================================================================
## labelled benchmark: PaySim
## ==========================================================================
build_paysim <- function() {
  f <- file.path(root, "data/raw/PS_20174392719_1491204439457_log.csv/PS_20174392719_1491204439457_log.csv")
  if (!file.exists(f)) return(NULL)
  d <- fread(f, showProgress = FALSE,
             colClasses = list(character = c("type", "nameOrig", "nameDest")))
  d[, row_id := .I]
  d[, isFraud := as.integer(isFraud)]
  d[, isFlaggedFraud := as.integer(isFlaggedFraud)]
  y <- d$isFraud

  make_X <- function(z) {
    lg <- function(v) log10(pmax(v, 0) + 1)
    x <- cbind(
      amount = lg(z$amount),
      oldBalanceOrig = lg(z$oldbalanceOrg),
      newBalanceOrig = lg(z$newbalanceOrig),
      oldBalanceDest = lg(z$oldbalanceDest),
      newBalanceDest = lg(z$newbalanceDest),
      deltaOrig = lg(pmax(z$oldbalanceOrg - z$newbalanceOrig, 0)),
      deltaDest = lg(pmax(z$newbalanceDest - z$oldbalanceDest, 0)),
      amountToBalance = lg(z$amount / (z$oldbalanceOrg + 1)),
      origZeroed = as.numeric(z$newbalanceOrig == 0),
      destZeroed = as.numeric(z$newbalanceDest == 0),
      hour = as.numeric(z$step %% 24),
      CASH_IN = as.numeric(z$type == "CASH_IN"),
      CASH_OUT = as.numeric(z$type == "CASH_OUT"),
      DEBIT = as.numeric(z$type == "DEBIT"),
      PAYMENT = as.numeric(z$type == "PAYMENT")
    )
    colnames(x) <- c("log_amount", "log_old_balance_origin", "log_new_balance_origin",
                     "log_old_balance_dest", "log_new_balance_dest",
                     "log_origin_decrease", "log_dest_increase", "log_amount_to_balance",
                     "origin_zeroed", "dest_zeroed", "hour_of_day",
                     "type_CASH_IN", "type_CASH_OUT", "type_DEBIT", "type_PAYMENT")
    x
  }

  steps <- sort(unique(d$step))
  q70 <- steps[floor(length(steps) * 0.70)]
  q85 <- steps[floor(length(steps) * 0.85)]
  tr_all <- which(d$step <= q70)
  va <- which(d$step > q70 & d$step <= q85)
  te <- which(d$step > q85)
  set.seed(2025)
  fraud_tr <- tr_all[y[tr_all] == 1]
  genuine_tr <- sample(setdiff(tr_all, fraud_tr), min(200000, length(setdiff(tr_all, fraud_tr))))
  tr <- sort(c(fraud_tr, genuine_tr))
  Xtr <- make_X(d[tr])
  sc <- fit_scaler(Xtr)
  Xtr_s <- scale_with(Xtr, sc)
  Xva <- scale_with(make_X(d[va]), sc)
  Xte <- scale_with(make_X(d[te]), sc)
  n1 <- sum(y[tr] == 1); n0 <- sum(y[tr] == 0)
  w <- ifelse(y[tr] == 1, length(tr) / (2 * n1), length(tr) / (2 * n0))
  log_mod <- fit_logistic(Xtr_s, y[tr], weights = w)
  p_log_va <- predict_logistic(log_mod, Xva)
  p_log_te <- predict_logistic(log_mod, Xte)
  rf <- fit_forest(Xtr_s, y[tr], seed = 2025, trees = 160,
                   pos_weight = 25, mtry = 5)
  p_rf_va <- predict_forest(rf, Xva)
  p_rf_te <- predict_forest(rf, Xte)

  meta <- data.table(
    ref = sprintf("PS-%07d", d$row_id),
    amount = d$amount,
    date = sprintf("step %d (day %d, %02d:00)", d$step, floor(d$step / 24), d$step %% 24),
    groupLabel = ifelse(d$isFraud == 1, "fraud label", "genuine label"),
    extra = d$type
  )
  smp <- prediction_sample(y[te], p_log_te, p_rf_te, Xte, log_mod$coef,
                           meta[te], "ref", n_pos = 140, n_neg = 160, seed = 78)

  model <- model_block(
    id = "paysim", label = "PaySim mobile-money benchmark",
    target = "isFraud", positive = "1 (fraud)",
    y = y, train_idx = tr, val_idx = va, test_idx = te,
    X = NULL, Xs = Xte,
    p_log_val = p_log_va, p_rf_val = p_rf_va,
    p_log_test = p_log_te, p_rf_test = p_rf_te,
    log_model = log_mod, rf_model = rf,
    features = colnames(Xtr),
    excluded = c("isFraud (target)", "isFlaggedFraud (existing rule, leakage)",
                 "nameOrig, nameDest (account identifiers)", "step (used only for the time split)"),
    split_note = "Time-based 70 / 15 / 15 split by step. Training down-samples genuine transactions to 200,000 plus every training fraud; validation and test keep the full population prevalence.",
    sample_rows = smp, prevalence_all = mean(y),
    threshold_note = "Post-transaction balance fields are included; this is post-transaction screening, not prevention."
  )
  dir.create(file.path(root, "models", "paysim"), recursive = TRUE, showWarnings = FALSE)
  saveRDS(list(coef = log_mod$coef, scaler = sc, features = colnames(Xtr), seed = 2025),
          file.path(root, "models/paysim/logistic.rds"))
  saveRDS(rf, file.path(root, "models/paysim/ranger.rds"))
  model$limitations <- c(model$limitations,
    "PaySim is a synthetic generator; near-perfect separation reflects its balance mechanics and post-transaction fields, not real-world fraud skill.",
    "Row counts across the time split differ because transaction volume varies sharply by step."
  )
  write_json(model, file.path(root, "models/paysim/metadata.json"),
             auto_unbox = TRUE, pretty = TRUE, digits = 8)

  pos <- d[amount > 0]
  bt_first <- benford_values(pos$amount, "first")
  bt_first2 <- benford_values(pos$amount, "first2")
  bt_second <- benford_values(pos$amount, "second")
  fam_type <- group_tests(pos$amount, pos$type, "first", "Transaction type (first digit)", min_n = 110)
  fam_type2 <- group_tests(pos$amount, pos$type, "first2", "Transaction type (first two digits)", min_n = 1150)
  fam_type_second <- group_tests(pos$amount, pos$type, "second", "Transaction type (second digit)", min_n = 110)
  fam_class <- group_tests(pos$amount, ifelse(pos$isFraud == 1, "Fraud label", "Genuine label"),
                           "first", "Amount by outcome class (context only)", min_n = 110)

  daily <- d[, .(count = .N, fraud = sum(isFraud == 1), volume = sum(amount, na.rm = TRUE)),
             by = .(day = as.integer(floor(step / 24)))]
  setorder(daily, day)
  by_type <- d[, .(transactions = .N, fraud = sum(isFraud == 1),
                   flagged = sum(isFlaggedFraud == 1)), by = type]
  setorder(by_type, -transactions)
  by_type[, share := r6(100 * transactions / nrow(d))]

  q <- quality_block(d[, .(step, type, amount, oldbalanceOrg, newbalanceOrig,
                           oldbalanceDest, newbalanceDest, isFraud)],
                     amount = "amount", date = "step", id = "row_id", group = "type")
  q$zeroAmounts <- sum(d$amount == 0, na.rm = TRUE)
  q$negativeAmounts <- sum(d$amount < 0, na.rm = TRUE)
  q$positiveAmounts <- nrow(pos); q$retained <- nrow(pos)
  q$excluded <- nrow(d) - nrow(pos)
  q$duplicateRows <- sum(duplicated(d))
  q$duplicateRowPct <- pct(q$duplicateRows, nrow(d))
  q$idDuplicates <- 0L
  q$signatureDuplicates <- 0L
  q$missingGroups <- sum(is.na(d$type))
  q$missingDates <- 0L
  q$minDate <- "step 1"; q$maxDate <- "step 743"

  schema <- column_schema(d[, .(step, type, amount, oldbalanceOrg, newbalanceOrig,
                                oldbalanceDest, newbalanceDest, isFraud, isFlaggedFraud)],
    roles = c(step = "time", type = "group", amount = "measure",
              oldbalanceOrg = "numeric", newbalanceOrig = "numeric",
              oldbalanceDest = "numeric", newbalanceDest = "numeric",
              isFraud = "label", isFlaggedFraud = "flag"),
    mapped = c(step = "hour_index", type = "transaction_type", amount = "amount",
               isFraud = "fraud_label", isFlaggedFraud = "existing_rule_flag"))

  list(
    id = "paysim", name = "PaySim Mobile-Money Benchmark", short = "PaySim",
    category = "Labelled \u00b7 benchmark", kind = "labelled",
    source = "PaySim synthetic mobile-money transaction log",
    url = "https://www.kaggle.com/datasets/ealaxi/paysim1",
    file = basename(f), path = "data/raw/PS_20174392719_1491204439457_log.csv/PS_20174392719_1491204439457_log.csv",
    sizeBytes = file.info(f)$size, downloaded = "2026-10-19",
    filters = "6,362,620 simulated transactions over 743 hours; 5 transaction types",
    description = "A large synthetic mobile-money log with 8,213 frauds. Amount, balances and transaction type support a benchmark model; the existing isFlaggedFraud rule is excluded as leakage.",
    caveat = "Synthetic benchmark labels, not real-world losses. Because post-transaction balances are used, the model is a post-transaction screen, not pre-transaction prevention.",
    rows = nrow(d), cols = ncol(d), mappedCols = 9,
    schema = schema,
    fieldMap = list(list(source = "step", internal = "hour_index"),
                    list(source = "type", internal = "transaction_type"),
                    list(source = "amount", internal = "amount"),
                    list(source = "oldbalanceOrg", internal = "origin_balance_before"),
                    list(source = "newbalanceOrig", internal = "origin_balance_after"),
                    list(source = "isFraud", internal = "fraud_label"),
                    list(source = "isFlaggedFraud", internal = "existing_rule_flag")),
    measure = list(column = "amount", label = "Transaction amount", currency = "USD",
                   n = nrow(pos), note = "Positive amounts only; 16 zero-amount rows are excluded from digit tests."),
    quality = q,
    suitability = suitability_block(pos$amount, "Transaction amount (positive)"),
    benford = list(first = bt_first, first2 = bt_first2, second = bt_second),
    groups = list(first = c(fam_type, fam_class), first2 = fam_type2, second = fam_type_second),
    anomalies = list(
      available = FALSE,
      reason = "Genuine benchmark labels exist, so the review page uses held-out model scores instead of unsupervised anomaly scores.",
      eligible = nrow(pos), candidates = 0L, highPriority = 0L,
      families = list(magnitude = 0L, rounding = 0L, duplication = 0L, context = 0L),
      scoreBins = numeric(0), sample = list(),
      byType = lapply(seq_len(nrow(by_type)), function(i) as.list(by_type[i]))
    ),
    peers = list(
      levels = "Transaction type", levelCounts = list("Transaction type" = nrow(pos)),
      groups = lapply(seq_along(fam_type), function(i) list(
        label = fam_type[[i]]$group, n = fam_type[[i]]$n,
        median = r6(median(pos[type == fam_type[[i]]$group]$amount)),
        q1 = NA, q3 = NA, mad = NA, upper = NA, lower = NA,
        flagged = 0L, hist = numeric(24))),
      histEdges = numeric(0),
      trend = list(labels = as.character(daily$day), count = as.numeric(daily$count),
                   value = r6(daily$volume), flagged = as.numeric(daily$fraud),
                   label = "Transactions by day", unit = "count")
    ),
    model = model,
    available = c("benford", "supervised", "peers", "quality")
  )
}
