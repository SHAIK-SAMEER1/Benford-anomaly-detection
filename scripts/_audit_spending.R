library(data.table)
f <- "data/raw/PrimeTransactions_2026-10-19_H05M29S23704379/Contracts_PrimeTransactions_2026-10-19_H05M30S19_1.csv"
sel <- c("contract_transaction_unique_key","contract_award_unique_key","award_id_piid",
         "modification_number","federal_action_obligation","total_dollars_obligated",
         "action_date","action_date_fiscal_year","awarding_agency_name",
         "awarding_sub_agency_name","recipient_name","recipient_uei","award_type",
         "transaction_description","naics_code","naics_description",
         "product_or_service_code","primary_place_of_performance_state_name","transaction_number")
d <- fread(f, select = sel, showProgress = FALSE)
cat("rows", nrow(d), "cols", ncol(d), "\n")
print(sapply(d, function(x) sum(is.na(x))))
cat("FY:\n"); print(table(d$action_date_fiscal_year, useNA = "ifany"))
cat("amount summary:\n"); print(summary(d$federal_action_obligation))
cat("neg", sum(d$federal_action_obligation < 0, na.rm = TRUE),
    "zero", sum(d$federal_action_obligation == 0, na.rm = TRUE), "\n")
cat("agencies:\n"); print(head(sort(table(d$awarding_agency_name), decreasing = TRUE), 15))
cat("award types:\n"); print(table(d$award_type, useNA = "ifany"))
cat("dates", as.character(min(d$action_date)), as.character(max(d$action_date)), "\n")
cat("dup txn keys", sum(duplicated(d$contract_transaction_unique_key)),
    "dup award", sum(duplicated(d$contract_award_unique_key)), "\n")
cat("NAICS missing", sum(is.na(d$naics_code) | d$naics_code == ""), "\n")
cat("recipients", length(unique(d$recipient_name)), "\n")
