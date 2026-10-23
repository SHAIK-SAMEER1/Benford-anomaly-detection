# Placeholders Checklist (`placeholders_checklist.md`)

In accordance with **STEP 5 HARD RULES** ("If you cannot run or reach the site, do NOT fake it. Leave a bordered placeholder box in the exact spot, labelled `[UPLOAD SCREENSHOT: page name, size]`. Then give me a numbered list of the exact screenshots I must supply"), this checklist enumerates all web interface screenshots required for the report.

Each screenshot has a corresponding bordered placeholder box in `Final_Report.docx` under the section **"Data Visualisation — Web Application Interface -"**.

---

## Required Website Screenshots

| # | Tab / Screen Name | Recommended File Name | Target Aspect / Resolution | Description / Expected Visual Elements |
|---|---|---|---|---|
| **1** | Landing / Overview & Method | `screen_overview.png` | 16:9 (~1280 × 720 px) | Displays the main dashboard header, project title (*"Can Statistics Detect Fake Data?"*), purpose card, workflow pipeline steps, and the prominent interpretation boundary banner (*"Anomalies are screening triggers, never proof of fraud"*). |
| **2** | Data Management & Preview | `screen_data.png` | 16:9 (~1280 × 720 px) | Shows data source controls (World Bank WDI selected, or USAspending toggle), summary metadata cards (total rows = 105,346, indicators = 9), and interactive preview table. |
| **3** | Column & Suitability Assessment | `screen_suitability.png` | 16:9 (~1280 × 720 px) | Displays the selected indicator dropdown (e.g. `SP.POP.TOTL`), suitability evaluation verdict (**Suitable**), reason bullet points, skewness, and orders-of-magnitude spread. |
| **4** | First-Digit Goodness-of-Fit Test | `screen_first_digit.png` | 16:9 (~1280 × 720 px) | Shows the empirical vs Benford theoretical bar chart, the Chi-square test summary ($X^2 = 96.22, df = 8, p < 0.001$), and MAD conformity badge (**Close Conformity**). |
| **5** | Extended Digits Analysis | `screen_extended_digits.png` | 16:9 (~1280 × 720 px) | Displays second-digit (0–9) and first-two-digit (10–99) frequency test results, along with sample-size validity checks. |
| **6** | Compare Subsets | `screen_compare_subsets.png` | 16:9 (~1280 × 720 px) | Displays regional or longitudinal facet plots comparing MAD scores across geographical regions (Sub-Saharan Africa, Europe & Central Asia, Latin America, etc.). |
| **7** | Controlled Synthetic Experiment | `screen_experiment.png` | 16:9 (~1280 × 720 px) | Shows the experimental setup panel (round-number substitution, leading-digit bias), Monte Carlo simulation runs, and detection power curves across 0% to 20% contamination. |
| **8** | Data & Report Export | `screen_export.png` | 16:9 (~1280 × 720 px) | Displays download buttons for pipeline CSV tables (`outputs/tables/`), analytical figures (`outputs/figures/`), and generated HTML/Word reports. |

---

## Instructions for Supplying Screenshots
1. Launch the dashboard locally:
   ```cmd
   RUN_PROJECT.bat
   ```
   *(or run `Rscript -e "shiny::runApp('app.R', port=7523)"` in your terminal)*.
2. Open `http://127.0.0.1:7523` in Google Chrome or Microsoft Edge.
3. Maximize the browser window (or set zoom to 100%).
4. For each numbered tab above, capture a clean rectangular window screenshot (using `Win + Shift + S` or Chrome DevTools screenshot).
5. Save the image into `report_assets/screens/` using the corresponding file name.
6. Open `Final_Report.docx`, right-click on the matching bordered placeholder box, and select **"Change Picture" > "This Device"**.
