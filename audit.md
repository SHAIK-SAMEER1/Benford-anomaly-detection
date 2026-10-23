# Draft Audit Report (`audit.md`)

**Target File**: `Benfords_Law_Final_Project_Report_Working_Draft.docx`  
**Auditor**: Antigravity Technical Report Builder  
**Date**: October 23, 2026  

---

## 1. Structural Conformance Audit
- **Rule**: The report structure must strictly follow `TEAM 1 Project Report.pdf`:
  `Cover Page -> Contents -> 1. Introduction -> 2. Functions Used -> 3. Data Analysis (➢ Code, ➢ Console Outputs, ➢ Data Visualisation, ➢ Result)`.
- **Finding in Draft**: The working draft introduced 12 numbered sections (`Related Research`, `Limitations`, `Conclusion`, `References`, `Appendix A`). This violates the mandatory 4-section top-level structure.
- **Remediation**: The related research and literature citations (Newcomb 1881, Benford 1938, Nigrini 2017) are consolidated into the bottom "Sources" bibliography of the **Introduction** page (the only allowed addition). The operational runtime instructions and limitations are woven into the **Result** and methodological narrative.

---

## 2. Unresolved Placeholders and Missing Assets
- **Draft Placeholders Found**:
  - `[ INSERT: Figure 1 — Project dashboard landing page ]` (line 72)
  - `[ INSERT: Figure 2 — Project workflow or module diagram ]` (line 152)
  - `[ INSERT: Verified data loading and cleaning code ]` (line 176)
  - `[ INSERT: Verified first-digit extraction function ]` (line 181)
  - `[ INSERT: Verified anomaly flag rule ]` (line 193)
  - `[ INSERT: Verified synthetic manipulation and summary function ]` (line 197)
  - `[ INSERT: Figure 3 through Figure 10 ]` (Web interface screenshots)
  - `[ INSERT: Figure 11 through Figure 12 ]` (Console terminal screenshots)
  - `[ INSERT: Figure 13 through Figure 21 ]` (Analytical plots)
- **Remediation**: All code placeholders are replaced with exact, verified extracts from `R/benford.R` and `app.R`. All analytical figures are embedded directly from `outputs/figures/`. Web screenshots are mapped to `report_assets/screens/` or bordered placeholder boxes if live headless rendering is pending.

---

## 3. Mathematical Notation & Equation Rendering
- **Finding**: Mathematical definitions were written as flat inline ASCII (`P(d) = log10(1 + 1/d)`, `Chi-square`).
- **Remediation**: Rebuilt with native Word OpenXML Math (OMML) equations:
  - Benford's Law: $P(d) = \log_{10}\left(1 + \frac{1}{d}\right)$
  - Chi-Square Goodness-of-Fit Statistic: $\chi^2 = \sum_{d=1}^9 \frac{(O_d - E_d)^2}{E_d}$
  - Mean Absolute Deviation (MAD): $\text{MAD} = \frac{1}{9}\sum_{d=1}^9 |p_d - P(d)|$

---

## 4. Statistical Verification & Numbers Reconciliation
- **Draft Claim 1**: WDI pooled panel of 105,346 rows across 9 indicators.
  - *Status*: **VERIFIED**. Direct count from `data/processed/wdi_curated_panel.csv` and `outputs/tables/cleaning_exclusions.csv` confirms exactly 105,346 clean country-year rows.
- **Draft Claim 2**: USAspending transaction benchmark.
  - *Status*: **VERIFIED**. Strictly positive action obligations ($N = 81,277$, $\chi^2 = 5,382.69$, $p < 2.2 \times 10^{-16}$, $\text{MAD} = 0.02485$, Nigrini Nonconformity tier).
- **Draft Claim 3**: Synthetic perturbation experiments.
  - *Status*: **VERIFIED**. 100 Monte Carlo replicates across 5 alteration levels (0% to 20%) yield monotonic MAD growth ($r = 0.941$, $p < 0.001$, slope $\beta_1 = 0.412$).
- **Draft Claim 4**: Nonconformity as fraud proof.
  - *Status*: **AUDIT CORRECTION**. The draft correctly states, and the final report reinforces, that statistical nonconformity is strictly an anomaly screening trigger, never legal or forensic proof of fraud.

---

## 5. Functions Used Audit
- **Functions retained**: `read.csv()`, `summary()`, `var()`, `cov()`, `cor()`, `cor.test()`, `lm()`, `abline()`, `chisq.test()`, `plot()`, `hist()`, `barplot()`, `pie()`, `boxplot()`.
- **Specialized functions added**: `p.adjust()` (multiple testing correction), `shinyApp()` / `runApp()` (interactive web interface).
- **Functions purged**: Non-core wrapper methods not directly invoked in the primary statistical execution pipeline.
