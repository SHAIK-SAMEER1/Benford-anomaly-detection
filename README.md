# Can Statistics Detect Fake Data? — Benford's Law + Chi-Square Goodness-of-Fit

**Course:** BMAT202L Probability and Statistics (Theory) + BMAT202P Probability and Statistics Lab
**Slot:** F1 — **Faculty:** Dr. Tharasi Dilleswar — **Institute:** VIT Vellore
**Students:** Shaik Sameer (24BDS1154), Joshita Chowdary (24BRS1313)

> **Interpretation boundary (applies to every number in this project).**
> A statistically significant deviation from Benford's Law is **NOT** proof of fraud, fabrication
> or manipulation. It is a diagnostic flag for further review. Legitimate explanations —
> constrained ranges, psychological price thresholds, caps, rounding, non-multiplicative
> processes — must be considered. This project reports *statistically unusual first-digit
> patterns*; it never alleges wrongdoing.

**Frontend.** The dashboard is styled as the supplied **“Benford's Geometry Box”**: a compact
warm-paper case, dark outlines, a grid-paper workspace and eight tool-like navigation tabs.
It is a real Shiny application — every control, table, chart, download and report is connected
to live R calculations. No result is hard-coded.

**Row-level review queue.** When the raw USAspending transaction file is present, the First-Digit
test page also provides an explainable transaction screen. It uses robust amount outliers within
awarding-agency + NAICS peer groups, 3-IQR rules, duplicate transaction keys and repeated
amount/date/recipient signatures. Each flagged row carries its own reason. This is deliberately
separate from the population-level Benford result: a Benford deviation is never used as proof
that a particular transaction is fraudulent.

---

## 1. What the project is

Real datasets contain far too many numbers to audit by eye. This project asks whether statistics
can flag numerical data whose **first-digit pattern** differs from the **Benford expectation**

$$P(d)=\log_{10}\!\left(1+\frac{1}{d}\right),\qquad E(d)=N\cdot P(d),\qquad
X^2=\sum_{d=1}^{9}\frac{(O_d-E_d)^2}{E_d},\ \mathrm{df}=8 .$$

The eight-stage flow fixed in Review 1 is preserved:

1. Dataset selection → 2. Data preparation in R → 3. Exploratory analysis → 4. First-digit
extraction → 5. Benford expected distribution → 6. Chi-square goodness-of-fit → 7. Anomaly
flagging → 8. Interpretation.

Three things are always reported together, because chi-square alone becomes oversensitive for
large $N$:

* the chi-square p-value (raw, Holm-adjusted and Benjamini–Hochberg-adjusted, with the family
  defined in the `family` column) plus the **validity tier** (Reliable / Caution / Not run),
* the **mean absolute deviation (MAD)** with the Nigrini first-digit bands
  (≤ 0.006 close conformity, ≤ 0.012 acceptable, ≤ 0.015 marginal, above 0.015 nonconformity),
* per-digit **standardised (Pearson) residuals** and **Cohen's w**.

A controlled **synthetic manipulation experiment** (clearly labelled) shows how well — and how
badly — the method detects a known fraction of altered records.

The row-level screen is a separate layer. It never labels a row “fraud”; it produces review
candidates with a documented rule, a severity and a short explanation. Population-level Benford
deviation and row-level review are reported as different kinds of evidence.

## 2. What is in this repository

```
app.R                              Shiny dashboard (Geometry Box frontend, 8 tabs, live results)
R/benford.R                        every statistical routine (digits, cleaning, suitability,
                                   Benford probabilities, chi-square, MAD, residuals, flags,
                                   multiple testing, experiment, ANOVA/regression, data import,
                                   transaction-level review screening)
scripts/run_all.R                  one command reproduces every output
tests/testthat/test-core.R         testthat suite (digits, cleaning, chi-square, tiers, bands,
                                   flags, suitability, experiment, pipeline, dashboard)
reports/benford_report.Rmd         report source (reads every number from the outputs)
reports/benford_report.html        rendered report (also .docx when Pandoc is available)
data/raw/                          where the World Bank WDI file goes
data/processed/wdi_clean.csv       cleaned curated panel produced by the pipeline
data/processed/usaspending_panel.rds  prepared USAspending analysis panel
data/processed/usaspending_transactions.rds  cached verified-column transaction extract
data/fixtures/                     labelled synthetic test fixture
data/DATA_MANIFEST.md              data provenance, cleaning decisions, terms note, limitations
outputs/tables/                    13 result tables (CSV)
outputs/figures/                   9 figures (PNG, 150 dpi)
PROGRESS.md                        phase-by-phase build log
```

## 3. Requirements

* R ≥ 4.1 (developed and verified on **R 4.6.1**, Windows).
* Packages: `shiny`, `bslib`, `readr`, `dplyr`, `tidyr`, `ggplot2`, `DT`, `testthat`,
  `rmarkdown`, `knitr`, `jsonlite`.
* Pandoc is only needed for the report. If you have RStudio or Quarto installed, `run_all.R`
  finds its bundled Pandoc automatically; otherwise the report render is skipped and the script
  says so.
* No paid API, cloud account, database or Docker is used. Everything runs offline once the
  packages and the data file are present.

## 4. Install and run (Windows, from the project root)

### One-Click Windows Launcher (`RUN_PROJECT.bat`)
The recommended way to launch on Windows:
```cmd
RUN_PROJECT.bat           :: Launches the Shiny dashboard in your default browser
RUN_PROJECT.bat check     :: Verifies R installation and required packages
RUN_PROJECT.bat test      :: Executes the automated testthat test suite
RUN_PROJECT.bat pipeline  :: Rebuilds all 13 CSV tables, 9 figures, and reports
RUN_PROJECT.bat install   :: Automatically installs missing CRAN packages
```

### Manual CLI Execution
```sh
Rscript -e "install.packages(c('shiny','bslib','readr','dplyr','tidyr','ggplot2','DT','testthat','rmarkdown','knitr','jsonlite'))"

Rscript scripts/run_all.R                     # full run: all tables, figures, manifest, report
Rscript scripts/run_all.R --quick             # fast run (30 experiment replicates)
Rscript scripts/run_all.R --data=PATH         # use a specific WDI zip / CSV / folder
Rscript scripts/run_all.R --out=DIR           # write the outputs somewhere else
Rscript scripts/run_all.R --no-report         # skip the report

Rscript -e "shiny::runApp('app.R')"           # dashboard; prints the chosen local URL
$env:BENFORD_PORT=7523; Rscript -e "shiny::runApp('app.R')"   # pin a port (PowerShell)
Rscript -e "testthat::test_dir('tests/testthat')"   # test suite
```

The dashboard chooses a free local port automatically, so a previously running copy cannot
block startup. The exact launch command from the project root is:
```sh
Rscript -e "shiny::runApp('app.R', launch.browser=TRUE)"
```

`run_all.R` exits with status 1 if any mandatory output is missing or empty, and prints a compact
summary of the headline results (indicator, N, X², df, p, MAD, flag) using actual computed numbers.

### Distribution Archive (`dist/Prob_Proj_FINAL.zip`)
To keep the archive portable (~14 MB), `dist/Prob_Proj_FINAL.zip` excludes the **1.18 GB of unzipped raw CSV datasets** from `data/raw/` and the unused static prototype in `web/`. The active application is always `app.R`. 

* **What is included in the ZIP**: All source code, Shiny dashboard, `RUN_PROJECT.bat`, tests, pre-trained supervised models (`models/`), pre-rendered analytical tables (`outputs/tables/`), figures (`outputs/figures/`), reports (`reports/`), and the processed panels (`data/processed/wdi_clean.csv`, `data/processed/usaspending_panel.rds`, `data/processed/usaspending_transactions.rds`).
* **Sufficient for execution**: The included processed panels and the cached transaction extract are sufficient to launch and interact with the default dashboard (`RUN_PROJECT.bat`), run the unit tests (`RUN_PROJECT.bat test`), use the row-level review queue, and review all reports and models. If the raw USAspending CSV is present, the transaction extract is rebuilt automatically when the raw file is newer.
* **To re-run raw ETL from scratch**: If you need to re-run raw data processing from the original multi-gigabyte sources rather than the curated panels, place the raw files in their exact expected paths:
  1. `data/raw/usaspending/usaspending.csv` (USAspending 2024 contract transactions, 236 MB)
  2. `data/raw/creditcard.csv/creditcard.csv` (Credit Card Fraud benchmark, 144 MB)
  3. `data/raw/PS_20174392719_1491204439457_log.csv/PS_20174392719_1491204439457_log.csv` (PaySim, 470 MB)
  4. `data/raw/WDI_CSV.zip` (World Bank WDI bulk zip, ~270 MB)

## 5. Data

**Primary dataset — World Bank World Development Indicators (WDI), bulk CSV.**

* Landing page: <https://databank.worldbank.org/source/world-development-indicators>
* Bulk file: <https://databankfiles.worldbank.org/public/ddpext_download/WDI_CSV.zip>

The pipeline searches for the data **in this order** and uses the first hit:

1. `data/raw/wdi/` (an extracted `WDICSV.csv` plus `WDICountry.csv`),
2. `data/raw/WDI_CSV.zip` (unzipped automatically),
3. any other unzipped WDI folder inside the project (for example `WDI_CSV_2026_10_01/`),
4. `--data=PATH` on the command line.

If no WDI file is found the pipeline falls back to a **clearly labelled synthetic panel**:
every table, figure and title then carries the label `SYNTHETIC - NOT REAL DATA`, the dashboard
shows a red banner, and the results are **not** real-world findings.

**To make the real data available:** download the bulk ZIP from the URL above and place it at
`data/raw/WDI_CSV.zip` (or unzip it into `data/raw/wdi/`). Then re-run
`Rscript scripts/run_all.R` — it is picked up automatically.

**Curated indicator panel** (all codes verified present in the file, and any missing code is
logged in the manifest):

| Indicator code | Indicator | Role |
|---|---|---|
| NY.GDP.MKTP.CD | GDP (current US$) | Benford-plausible |
| SP.POP.TOTL | Population, total | Benford-plausible |
| NE.EXP.GNFS.CD | Exports of goods and services (current US$) | Benford-plausible |
| NE.IMP.GNFS.CD | Imports of goods and services (current US$) | Benford-plausible |
| AG.LND.TOTL.K2 | Land area (sq. km) | Benford-plausible |
| FI.RES.TOTL.CD | Total reserves incl. gold (current US$) | Benford-plausible |
| NY.GNP.MKTP.CD | GNI (current US$) | Benford-plausible |
| SP.DYN.LE00.IN | Life expectancy at birth (years) | **Negative control** (bounded) |
| SP.DYN.TFRT.IN | Fertility rate, total (births per woman) | **Negative control** (narrow range) |

The two negative controls are *expected* to deviate. They demonstrate that a flag means
"unusual first-digit pattern", not wrongdoing — the method is discriminating between suitable
and unsuitable data.

**Optional secondary dataset — USASpending.gov.** Put a small exported CSV (one fiscal year, one
award type) in `data/raw/usaspending/` and the pipeline picks it up automatically; amount columns
are detected by name, negative values are treated as de-obligations and analysed by magnitude.
Nothing is downloaded automatically and the project does not require this dataset.
Download centre: <https://www.usaspending.gov/download_center>.

## 6. Analysis units

For every indicator the pipeline tests four units and labels the family used for multiple-testing
adjustment:

* **(a) latest complete-year cross-section** — the most recent year with (almost) full country
  coverage; independent across countries, N ≈ 200;
* **(b) pooled country-years** — all years together; large N, but *not independent* (the same
  country appears many times), so those p-values are optimistic;
* **(c) per-year subsets** — only years with at least 110 eligible values are tested;
* **(d) per-region subsets** — only regions with at least 110 eligible values are tested.

Units that fail the minimum-sample guard appear in `outputs/tables/skipped_units.csv` with a
reason instead of a p-value.

## 7. Syllabus mapping (BMAT202P)

| Topic | Coverage | Where in this project |
|---|---|---|
| Data import and data types | Direct | `run_all.R` import section, dashboard tab 2 |
| Summary statistics | Direct | `outputs/tables/descriptive_statistics.csv`, dashboard tab 3 |
| Graphical representation | Direct | `outputs/figures/` (histograms, log histograms, bar charts, boxplots, heatmap) |
| Probability distributions (Benford as reference null) | Related / application | `benford_expected_probabilities.csv`, dashboard tab 1 |
| Hypothesis testing | Direct | H0/H1, α, decision rule, dashboard tab 4 |
| Chi-square goodness-of-fit | Direct / core | `chi_square_results.csv`, dashboard tab 4 |
| Correlation and regression | Optional (used) | MAD vs alteration rate, `regression_results.csv` |
| t-test / ANOVA | Optional (used) | One-way ANOVA of MAD, `anova_results.csv` |

## 8. Method details worth knowing

* **Digit extraction** uses `sprintf("%.14e", |x|)` and reads the mantissa, so it is exact at
  powers of ten and in scientific notation (`0.00417 → 4`, `3.2e-7 → 3`, `1000 → 1`,
  `9999.999 → 9`). `as.character()` and `floor(x/10^floor(log10(x)))` are deliberately avoided.
* **Cleaning** converts to numeric and counts every exclusion category (missing, non-finite,
  invalid text, zero, negative). Negative values are analysed by magnitude and the count of
  negatives is always reported.
* **Validity tiers.** Reliable = every expected count ≥ 5. Caution = every expected count ≥ 1 and
  at most 20% of cells below 5 (Cochran's rule). Otherwise **Not run** with a reason — an invalid
  p-value is never printed. The minimum sample sizes are computed from the probability vector
  (≈ 110 for the first digit, ≈ 1146 for the first two digits), not hard-coded.
* **Aggregates removed.** WDI mixes real countries with World / region / income-group aggregates;
  only rows whose Country Code has a non-empty `Region` in `WDICountry.csv` are kept.
* **Multiple testing.** Raw, Holm and Benjamini–Hochberg adjusted p-values are reported per
  family; **the flags use the BH-adjusted p-value**.
* **Row-level review rules (USAspending only).** The screen uses the log10 magnitude of
  `federal_action_obligation` and compares each row with its awarding-agency + NAICS peer group
  when that group has at least 30 finite values (otherwise the whole file). A row is a review
  candidate if its robust z is at least 4 (one-sided: unusually **large** obligations only),
  its log amount exceeds the upper 3-IQR fence, its transaction key is duplicated, or its
  amount/date/recipient signature repeats at least three times. Median/MAD scoring guards
  against zero MAD; negative amounts are de-obligations analysed by magnitude; zero and missing
  amounts are reported as data-quality notes. Every flagged row carries a reason. The screen is
  independent of the Benford population test and never labels a row “fraud”.
* **Flag rule (one function, five possible outputs).**

  | Flag | Condition |
  |---|---|
  | Not assessed - unsuitable data | the suitability screening rejected the column |
  | Not assessed - insufficient sample | no valid chi-square p-value (N or expected counts too small) |
  | Statistical deviation: significant AND practically material | adjusted p < α **and** MAD > 0.006 |
  | Statistically significant but small deviation | adjusted p < α but MAD ≤ 0.006 (typical for huge N) |
  | No significant deviation detected | adjusted p ≥ α |

## 9. Known limitations

1. **Non-independence.** Pooled country-years repeat the same country across years, so pooled
   p-values are optimistic. The latest-year cross-section is the independent unit and is always
   reported next to the pooled result.
2. **Bounded variables.** Percentages, shares, indices and narrow-range ratios (life expectancy,
   fertility rate) are not multiplicative-scale quantities; Benford is the wrong reference for
   them and they are screened out or flagged as unsuitable.
3. **Large-N oversensitivity.** With tens of thousands of values trivial departures become
   significant, which is why MAD, residuals and Cohen's w are reported with every p-value.
4. **Rounding and revisions.** Published figures are rounded and revised; heavy rounding pushes
   first digits away from Benford.
5. **The synthetic experiment is synthetic.** Its detection rates describe the simulation, not any
   real dataset, and small multiplicative alterations are hard to detect — the method does not
   catch everything.
6. **Benford's Law is a screening heuristic.** It flags unusual digit patterns; it cannot identify
   who altered what and it cannot prove intent.
7. **Row-level review is a triage aid.** Robust amount rules and duplicate checks can flag
   legitimate large awards, de-obligations, instalments and data-entry errors. The USAspending
   export used here is a single-agency slice, so peer groups are defined by NAICS categories and
   small categories fall back to the whole file. A review candidate is not a fraud finding.
8. **Transaction cache.** The first row-level screen reads the 237 MB raw CSV and writes
   `data/processed/usaspending_transactions.rds`. Later screens use the cache and rebuild it when
   the raw file is newer. Deleting the cache is safe; it is regenerated on demand.

## 10. Note on the student name spelling

The Review-1 DOCX spells the second student's name **"Chowdhary"**, while the PPTX spells it
**"Chowdary"**. This project uses **"Joshita Chowdary"** everywhere; please confirm the correct
spelling with the student and the faculty before final submission.

## 11. Reproducibility

* All random operations use fixed seeds (`set.seed(2025)`), and every seeded routine restores the
  caller's RNG state, so results do not depend on run order.
* Replicate seeds in the experiment are derived deterministically from
  (manipulation type, alteration level, replicate), so re-running the same configuration gives
  bit-identical results.
* The report is generated from `outputs/tables/` and `outputs/figures/` at render time; no result
  is typed into the document by hand.
