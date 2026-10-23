# Final Acceptance Audit and Evidence-Based Report
**Course**: BMAT202L / BMAT202P — Probability and Statistics (Slot F1)  
**Institution**: VIT Vellore  
**Project**: Anomaly Detection in High-Volume Financial and Economic Data via Benford's Law and Supervised Benchmarks  
**Date**: October 19, 2026  
**Environment**: Windows 11, R 4.6.1 (64-bit), RStudio Environment  

---

## Executive Summary

The project repository at `C:\Users\SAMEER\OneDrive\Desktop\Prob_Proj` has been completely repaired, audited, executed, and packaged. All requirements of the finalization specification have been satisfied with direct experimental and statistical evidence.

- **Automated Tests**: 192 passed, 0 failed, 0 warned, 0 skipped (`tests/testthat/`).
- **Interactive Application**: Shiny dashboard running and verified live on `http://127.0.0.1:7523` (HTTP 200). Default data source is configured to load the real USAspending transactions directly without silent fallback.
- **Windows Launcher**: `RUN_PROJECT.bat` refactored with clean ASCII, CRLF endings, batch labels, and verified via automated environment check (exit code 0).
- **End-to-End Pipeline**: `scripts/run_all.R` produces all 13 required CSV tables and 9 publication-grade analytical figures.
- **Reports**: Both `reports/benford_report.html` (2.86 MB) and `reports/benford_report.docx` (922 KB) generated and verified.
- **Supervised ML Models**: Trained and evaluated on held-out test splits for Credit Card Fraud (ROC-AUC 0.960, PR-AUC 0.712) and PaySim (ROC-AUC 0.978, PR-AUC 0.651, `isFlaggedFraud` excluded to prevent leakage).
- **Final Distribution Archive**: Packaged at `dist/Prob_Proj_FINAL.zip` (8.0 MB). Note that this archive deliberately excludes 1.18 GB of unzipped raw CSV files from `data/raw/`, but includes the processed panels (`data/processed/`), which are sufficient to launch the default dashboard, run tests, and review all reports and models.

---

## Acceptance Audit Matrix

| Requirement Item | Status | Direct Evidence / Verification Output |
|---|---|---|
| **1. Project starts** | **[x] VERIFIED** | Shiny daemon listening on `http://127.0.0.1:7523`. Direct HTTP probe returned `StatusCode: 200`, `Length: 27,285 bytes`, title matches: `Benford's Law - P&S project (BMAT202L / BMAT202P, Slot F1)`. |
| **2. USAspending data load & analysis** | **[x] VERIFIED** | `data/raw/usaspending/usaspending.csv` (236 MB, 111,908 rows). Reconciled statistical results: Primary positive obligations ($N = 81,277$) yield $X^2 = 5,382.69$, $p < 2.2\times 10^{-16}$, $\text{MAD} = 0.0249$ (Nonconformity, Reliable tier). Pipeline indicator with de-obligations ($N = 101,381$) yields $X^2 = 4,663.33$, $\text{MAD} = 0.0207$. Stacked 3-indicator panel ($N = 321,678$) yields $X^2 = 13,250.38$, $\text{MAD} = 0.0196$. |
| **3. Core statistical results execute** | **[x] VERIFIED** | All mathematical functions in `R/benford.R` verified against R base packages. Exact expected frequencies match $\log_{10}(1 + 1/d)$, manual chi-square equals `stats::chisq.test`, Cochran's rule enforced. |
| **4. Anomaly screening & explanations** | **[x] VERIFIED** | All 5 anomaly flag categories operational in `flag_anomaly()`. Clear distinction enforced: anomalies are strictly "review prompts, never proof of fraud". |
| **5. Dashboard dataset state & tabs** | **[x] VERIFIED** | 8 tabs operational (`Overview`, `Data`, `Column & Suitability`, `First-Digit Test`, `Extended Digits`, `Compare Subsets`, `Experiment`, `Export`). USAspending is selectable as primary data source; synthetic mode displays prominent red `SYNTHETIC - NOT REAL DATA` banner. |
| **6. Exports work** | **[x] VERIFIED** | All 13 result tables exported to `outputs/tables/*.csv`. Download handlers in `app.R` verified for CSV/TSV data download. |
| **7. Automated test results** | **[x] VERIFIED** | Ran `testthat::test_dir('tests/testthat')`. Test results: **192 passed, 0 failed, 0 warned, 0 skipped** (Execution time: 252.9 seconds). |
| **8. Pipeline results** | **[x] VERIFIED** | `scripts/run_all.R` executes cleanly to exit code 0. Generates complete manifest, summary tables, and figure suite. |
| **9. Generated reports and figures** | **[x] VERIFIED** | HTML and Word reports rendered (`reports/benford_report.html` and `reports/benford_report.docx`). 9 PNG figures in `outputs/figures/` (fig01 through fig09) verified non-empty. |
| **10. Supervised model status** | **[x] VERIFIED** | Logistic Regression and Random Forest (Ranger) models trained and evaluated on held-out test splits. Metrics (ROC-AUC, PR-AUC, F1) saved in `models/creditcard/metadata.json` and `models/paysim/metadata.json`. |
| **11. Launcher and README verified** | **[x] VERIFIED** | `RUN_PROJECT.bat` refactored with clean ASCII, CRLF endings, and batch labels. Verified via `RUN_PROJECT.bat check` (exit code 0). Instructions and data paths documented in `README.md`. |
| **12. Final project & ZIP path** | **[x] VERIFIED** | Project root: `C:\Users\SAMEER\OneDrive\Desktop\Prob_Proj`. Distribution archive created at `dist/Prob_Proj_FINAL.zip` (8.0 MB), excluding large raw CSVs but containing all processed panels, code, tests, and outputs. |

---

## Statistical Reconciliation: USAspending First-Digit Results

To eliminate discrepancy between report sections, the underlying data samples have been recalculated directly from `data/raw/usaspending/usaspending.csv` (111,908 contract rows, Department of Veterans Affairs FY2024 export):

```
+--------------------------------------------------------------------------------------------------------------------------------------------------+
| Sample Definition                                      | Sample Size (N) | Chi-Square (X2) | df | p-value    | MAD     | Nigrini Band  | Cohen's w |
+--------------------------------------------------------------------------------------------------------------------------------------------------+
| 1. Strictly Positive Obligations (Primary Benchmark)   | 81,277          | 5,382.69        | 8  | < 2.2e-16  | 0.02485 | Nonconformity | 0.2573    |
| 2. FAO with De-obligations by Magnitude (Pipeline CSV) | 101,381         | 4,663.33        | 8  | < 2.2e-16  | 0.02071 | Nonconformity | 0.2145    |
| 3. Current Total Award Value                           | 110,044         | 4,409.85        | 8  | < 2.2e-16  | 0.01936 | Nonconformity | 0.2002    |
| 4. Potential Total Award Value                         | 110,253         | 4,210.00        | 8  | < 2.2e-16  | 0.01891 | Nonconformity | 0.1954    |
| 5. All 3 Indicators Pooled (Stacked Panel Total)       | 321,678         | 13,250.38       | 8  | < 2.2e-16  | 0.01963 | Nonconformity | 0.2030    |
+--------------------------------------------------------------------------------------------------------------------------------------------------+
```

### Clarification of Earlier Reported Numbers
1. **$N = 81,277$, $X^2 = 5,382.69$, $\text{MAD} = 0.0249$**:
   - This represents **Sample 1**, the standard primary benchmark of positive obligations (`federal_action_obligation > 0`).
   - Observed digit frequencies: `[1: 33556, 2: 14011, 3: 8922, 4: 6642, 5: 5028, 6: 4140, 7: 3369, 8: 2909, 9: 2700]`.
   - Expected frequencies: `[1: 24466.81, 2: 14312.17, 3: 10154.65, 4: 7876.56, 5: 6435.61, 6: 5441.23, 7: 4713.41, 8: 4157.52, 9: 3719.03]`.
   - Digit 1 standard residual: $+58.11$ (strong positive spike due to standard contracting caps/authorizations).
   - This exact frequency distribution is preserved in `web/downloads/benford_groups_all.csv`.

2. **$N = 101,381$, $X^2 = 4,663.33$, $\text{MAD} = 0.0207$**:
   - This represents **Sample 2**, the indicator `USASPEND.FEDERAL_ACTION_OBLIGATION` as generated in the batch pipeline table `outputs/tables/chi_square_results.csv` and `outputs/tables/first_digit_frequency.csv`.
   - In accordance with standard forensic accounting practice, negative transaction adjustments (20,104 de-obligations) were included by absolute magnitude: $81,277 + 20,104 = 101,381$.

3. **$N = 321,678$, $X^2 = 13,250.38$, $\text{MAD} = 0.0196$**:
   - This represents **Sample 5**, the full multi-indicator panel created when `load_usaspending()` stacks all three award measures (`federal_action_obligation`, `current_total_value_of_award`, and `potential_total_value_of_award`).

All three views independently and unambiguously demonstrate **statistically significant and practically material nonconformity** ($p < 2.2 \times 10^{-16}$, $\text{MAD} > 0.015$), reliably flagged under Cochran's rule as a review prompt rather than evidence of fraud.

---

## Supervised Benchmark Modeling Summary

To demonstrate the methodological difference between unlabelled Benford screening (anomaly heuristic) and supervised fraud prediction:

1. **Credit Card Fraud Benchmark (`data/raw/creditcard.csv`)**:
   - $N = 284,807$, 492 fraud cases (prevalence: 0.17%).
   - Stratified 70/15/15 train/val/test split ($N_{\text{test}} = 42,561$, 72 fraud cases).
   - **Logistic Regression**: ROC-AUC = 0.9604, PR-AUC = 0.7116, F1 = 0.6180, Precision = 0.5189, Recall = 0.7639.
   - **Ranger Random Forest**: Serialized at `models/creditcard/ranger.rds`.

2. **PaySim Mobile Money Benchmark (`data/raw/PS_...log.csv`)**:
   - $N = 6,362,620$ total records; evaluated on held-out test split ($N_{\text{test}} = 89,466$, 1,252 fraud cases).
   - **Target Leakage Prevention**: The `isFlaggedFraud` column (a legacy business rule) is strictly excluded from all feature sets to avoid target leakage.
   - **Logistic Regression**: ROC-AUC = 0.9778, PR-AUC = 0.6507, Recall = 0.9633, Specificity = 0.9924.
   - **Ranger Random Forest**: Serialized at `models/paysim/ranger.rds`.

---

## Distribution Archive and Data Inventory

### Archive Details (`dist/Prob_Proj_FINAL.zip`)
- **File Path**: `C:\Users\SAMEER\OneDrive\Desktop\Prob_Proj\dist\Prob_Proj_FINAL.zip`
- **File Size**: ~8.0 MB
- **Scope**: To maintain a reasonable archive size, the ZIP **excludes the 1.18 GB of unzipped raw CSV files** under `data/raw/`.
- **Sufficiency**: The archive includes all R source code, test suites, `RUN_PROJECT.bat`, model files, output tables, figures, reports, fixtures, and the curated processed panels (`data/processed/wdi_clean.csv`, `data/processed/usaspending_panel.rds`). This is **fully sufficient** to launch the interactive dashboard, run the complete unit test suite, and inspect all analytical outputs.
- **Raw Data Requirements (only if re-running raw ETL from scratch)**:
  - `data/raw/usaspending/usaspending.csv` (236 MB)
  - `data/raw/creditcard.csv/creditcard.csv` (144 MB)
  - `data/raw/PS_20174392719_1491204439457_log.csv/PS_20174392719_1491204439457_log.csv` (470 MB)
  - `data/raw/WDI_CSV.zip` (270 MB)

---

## Exact Launch Instructions

1. **Launch Shiny Dashboard**:
   Double-click `RUN_PROJECT.bat` in the project root folder:
   ```cmd
   RUN_PROJECT.bat
   ```
   *The launcher checks that R is available, verifies all 11 required packages, and opens `http://127.0.0.1:7523` in your default browser. The dashboard automatically loads the USAspending transactions by default.*

2. **Run Environment & Package Check**:
   ```cmd
   RUN_PROJECT.bat check
   ```

3. **Run 192-Assertion Automated Test Suite**:
   ```cmd
   RUN_PROJECT.bat test
   ```

4. **Re-run Batch Pipeline (Tables, Figures, Reports)**:
   ```cmd
   RUN_PROJECT.bat pipeline
   ```