# Format Specification (Measured from TEAM 1 Project Report.pdf)

This specification documents the exact geometric, typographic, and stylistic layout of `TEAM 1 Project Report.pdf`. All measurements have been extracted directly from the reference PDF byte stream and text matrices.

---

## 1. Page Setup and Geometry
- **Page Size**: Standard A4 (595.32 pt × 841.92 pt / 210 mm × 297 mm).
- **Margins**:
  - Top: 72.0 pt (1.0 in / 25.4 mm)
  - Bottom: 72.0 pt (1.0 in / 25.4 mm)
  - Left: 72.0 pt (1.0 in / 25.4 mm)
  - Right: 72.0 pt (1.0 in / 25.4 mm)
- **Global Page Border**:
  - Encloses every page without exception.
  - Rectangular stroke coordinates: `Left = 24.0 pt`, `Right = 570.0 pt` (width = 546.0 pt), `Top = 816.5 pt`, `Bottom = 24.0 pt` (height = 792.5 pt).
  - Line thickness: `1.44 pt` (Word `sz="12"` = 1.5 pt solid black `#000000`).
  - Offset from page: 24 pt.

---

## 2. Cover Page (Page 1)
- **Background**:
  - Vertical axial gradient fill.
  - Top color stop: `#F6F8FC` (light white-blue, `RGB(246, 248, 252)`).
  - Bottom color stop: `#ABC0E4` (soft sky-blue, `RGB(171, 192, 228)`).
- **VIT Logo**:
  - Centered horizontally at top (`y ≈ 740 pt`).
  - Native extracted asset: `report_assets/extracted/page_1_Image17.png`.
  - Dimensions: ~150 pt width × ~80 pt height.
- **Header Lines** (All Centered, Bold, Underlined, Times New Roman):
  - Academic Term: `"Fall Semester 2026-27"` — **38 pt**, Bold, Underlined.
  - Course Title: `"Probability & Statistics"` — **38 pt**, Bold, Underlined.
  - Course Code: `"(BMAT202P)"` — **38 pt**, Bold, Underlined.
  - Project Label: `"PROJECT REPORT"` — **30 pt**, Bold, Underlined.
- **Project Title**:
  - `"Can Statistics Detect Fake Data? Identifying Anomalies and Outliers in Real Datasets"` — **24 pt**, Bold, Centered (no underline).
- **Faculty Label**:
  - `"Faculty: Dr. Tharasi Dilleswar"` — **20 pt**, Bold, Centered, with `"Faculty:"` underlined.
- **"Submitted By" Information Box**:
  - Located at bottom-left (`x0 = 33.5 pt`, `y0 = 40.0 pt`, `w ≈ 260 pt`).
  - Enclosed in a 1.0 pt solid black rectangular border.
  - Header: `"Submitted By:"` — **16 pt**, Bold (`#000000`).
  - Student Entries:
    - `"SHAIK SAMEER – 24BDS1154"` — **12 pt**, Bold.
    - `"JOSHITA CHOWDARY D – 24BRS1313"` — **12 pt**, Bold.

---

## 3. Table of Contents (Page 2)
- **Title**: `"Contents"` — **25 pt**, Bold, Centered, Underlined (solid black underline, 2.4 pt thick).
- **Structure and Hierarchy**:
  - Major sections (1., 2., 3.): Left-aligned at `90 pt` (0.25 in indent), **16 pt**, Times New Roman Bold.
  - Subsection items under Data Analysis (`➢ Code`, `➢ Console Outputs`, `➢ Data Visualisation`, `➢ Result`): Left-aligned at `126 pt` (0.5 in indent), **16 pt**, Times New Roman Bold.
  - Leader dots: Dotted tab leaders (`w:leader="dot"`) connecting section titles to page numbers aligned at the right margin (`471 pt` / 6.5 in).

---

## 4. Typography & Section Headings
- **Font Family**: Times New Roman throughout the document.
- **Section Headings**:
  - `Introduction`, `Functions Used`, `Data Analysis`: **25 pt**, Bold, Centered, Underlined.
  - Each major section begins on a new page (`pageBreakBefore`).
- **Body Text**:
  - Font: Times New Roman Regular.
  - Size: **16.0 pt**.
  - Line Spacing: 1.2× – 1.25× (~20 pt line pitch).
  - Alignment: Justified or Left-aligned with sharp margins.
  - Color: Pitch black (`#000000`).
- **Labels**:
  - `"AIM:"`, `"CODE:"`, `"CONSOLE OUTPUT:"`, `"DATA VISUALISATION:"`, `"RESULT:"`:
  - **16 pt**, Times New Roman Bold, Uppercase, followed by a colon.

---

## 5. Functions Used Section (Page 4)
- **Bullet Style**: Rightwards arrow `➢` (Unicode `\u27A2` / Wingdings character `\uF0D8`).
- **Entry Structure**:
  - `➢ func_name() – Description text`
  - Function name: **16 pt**, Times New Roman Bold.
  - Separator: En-dash (`–`).
  - Description: **16 pt**, Times New Roman Regular.
  - Sub-category header: `(Data visualisation function)` in Times New Roman Bold 16 pt.

---

## 6. Code Excerpts (Pages 5–8)
- **Layout**: Clean snippets of at most ~25 lines each with plain-English section comments `# ...`.
- **Typography**: Times New Roman Regular 14–16 pt (or Consolas 11 pt in bordered boxes).
- **Spacing**: Tightly formatted, matching R script readability.

---

## 7. Console Outputs (Pages 9–13)
- **Enclosure**: Bordered console transcript boxes (1.5 pt solid black rectangular border).
- **Typography**: Consolas / Courier New 10–11 pt monospace.
- **Coloring**: R console inputs in RStudio blue (`#0000CC` or `#0055AA`), execution output in pure black (`#000000`).

---

## 8. Data Visualisation & Figures (Pages 14–18)
- **Category Labels**: **16 pt**, Times New Roman Bold, left-aligned with a trailing dash:
  - `Regression Plots -`
  - `Histograms -`
  - `Bar Plots -`
  - `Box Plots -`
  - `Pie Chart -`
  - `Scatter Plot -`
  - `Line Plot -`
  - `Web Application Interface -`
- **Figure Boxes**: Each individual plot or screenshot is enclosed in a **thick solid black border** (1.5 pt), centered on the page.

---

## 9. Equations
- Native Word OMML equations (never low-resolution images):
  - Benford's Probability: $P(d) = \log_{10}\left(1 + \frac{1}{d}\right)$
  - Chi-Square Goodness-of-Fit: $\chi^2 = \sum_{d=1}^9 \frac{(O_d - E_d)^2}{E_d}$
  - Mean Absolute Deviation: $\text{MAD} = \frac{1}{9}\sum_{d=1}^9 |p_d - P(d)|$
