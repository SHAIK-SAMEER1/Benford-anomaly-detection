library(data.table)
cc <- fread("data/raw/creditcard.csv/creditcard.csv", showProgress = FALSE)
cat("credit rows", nrow(cc), "cols", ncol(cc), "\n")
print(table(cc$Class, useNA = "ifany"))
cat("amount summary\n"); print(summary(cc$Amount))
cat("zeros", sum(cc$Amount == 0), "neg", sum(cc$Amount < 0), "NA", sum(is.na(cc$Amount)), "\n")
cat("duplicates", sum(duplicated(cc)), "\n")

ps <- fread("data/raw/PS_20174392719_1491204439457_log.csv/PS_20174392719_1491204439457_log.csv",
            select = c("step","type","amount","nameOrig","nameDest","isFraud","isFlaggedFraud"),
            showProgress = FALSE)
cat("paysim rows", nrow(ps), "cols", ncol(ps), "\n")
print(table(ps$type, ps$isFraud, useNA = "ifany"))
cat("amount summary\n"); print(summary(ps$amount))
cat("steps", min(ps$step), max(ps$step), "\n")
cat("duplicates", sum(duplicated(ps)), "\n")
cat("flagged", sum(ps$isFlaggedFraud), "fraud", sum(ps$isFraud), "\n")
