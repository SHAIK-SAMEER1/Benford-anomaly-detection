# DATA MANIFEST - World Bank WDI

Generated: 2026-10-19 17:28:17

| field | value |
|---|---|
| source_name | World Bank World Development Indicators (WDI) bulk CSV |
| source_url | https://databankfiles.worldbank.org/public/ddpext_download/WDI_CSV.zip |
| landing_page | https://databank.worldbank.org/source/world-development-indicators |
| local_main_file | C:\Users\SAMEER\OneDrive\Desktop\Prob_Proj/WDI_CSV_2026_10_01/WDICSV.csv |
| local_country_file | C:\Users\SAMEER\OneDrive\Desktop\Prob_Proj/WDI_CSV_2026_10_01/WDICountry.csv |
| download_attempted | no (a local copy of the WDI bulk CSV was found in the workspace) |
| download_date_or_file_timestamp | not downloaded; local file timestamp 2026-10-12 21:05:32 |
| is_synthetic | FALSE |
| selected_indicator_codes | AG.LND.TOTL.K2; FI.RES.TOTL.CD; NE.EXP.GNFS.CD; NE.IMP.GNFS.CD; NY.GDP.MKTP.CD; NY.GNP.MKTP.CD; SP.DYN.LE00.IN; SP.DYN.TFRT.IN; SP.POP.TOTL; USASPEND.FEDERAL_ACTION_OBLIGATION; USASPEND.CURRENT_TOTAL_VALUE_OF_AWARD; USASPEND.POTENTIAL_TOTAL_VALUE_OF_AWARD |
| indicator_codes_missing | none |
| rows_panel_before_cleaning | 157410 |
| rows_panel_after_cleaning | 441070 |
| row_counts_before_cleaning_wide | 441070 |
| cleaning_decisions | Wide to long via tidyr::pivot_longer; non-numeric fields removed; empty cells dropped; only country ids with a non-empty Region in WDICountry.csv kept (so World/region/income-group aggregates are removed); zeros, NA/NaN, Inf and non-numeric text excluded from digit analysis; negatives analysed by magnitude (see cleaning_exclusions.csv) |
| terms_of_use_note | The WDI bulk file is published by the World Bank as open data; confirm the current terms on the World Bank Data Terms of Use page before redistribution (https://www.worldbank.org/en/about/legal/terms-of-use). |
| optional_secondary_dataset | USASpending.gov bulk data are optional and were not required; if a CSV is placed in data/raw/usaspending/ the pipeline analyses its amount columns by magnitude. |
| limitations | Pooled country-years are not independent (the same country appears in many years), so pooled p-values are optimistic; Benford's Law is a screening heuristic, not proof of fraud; bounded indicators (life expectancy, fertility) are expected to deviate. |

## Notes

- Optional USASpending file picked up: 335724 rows.

## What the student must do

1. Download https://databankfiles.worldbank.org/public/ddpext_download/WDI_CSV.zip
2. Place it at `data/raw/WDI_CSV.zip` (or unzip it to `data/raw/wdi/`).
3. Re-run `Rscript scripts/run_all.R`; the pipeline picks it up automatically.
4. Optional: export a small USASpending subset from https://www.usaspending.gov/download_center
   (one fiscal year, one award type) into `data/raw/usaspending/`.
