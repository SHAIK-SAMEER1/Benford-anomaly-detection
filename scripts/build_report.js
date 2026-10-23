// scripts/build_report.js
// Generates the final Word (.docx) project report matching TEAM 1 Project Report.pdf strictly

const fs = require('fs');
const path = require('path');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  ImageRun, AlignmentType, BorderStyle, WidthType, ShadingType,
  PageBorderOffsetFrom, PageBorderZOrder, UnderlineType
} = require('docx');

console.log("Building calibrated 18-page Final_Report.docx...");

// --- Constants ---
const FONT_FAMILY = "Times New Roman";
const MONO_FONT = "Consolas";
const COLOR_BLACK = "000000";
const COLOR_BLUE = "0000CC";
const COLOR_MUTED = "333333";

// Page Border Configuration
const PAGE_BORDER_CONFIG = {
  pageBorders: {
    offsetFrom: PageBorderOffsetFrom.PAGE,
    zOrder: PageBorderZOrder.FRONT,
  },
  pageBorderTop: { style: BorderStyle.SINGLE, size: 12, space: 24, color: COLOR_BLACK },
  pageBorderBottom: { style: BorderStyle.SINGLE, size: 12, space: 24, color: COLOR_BLACK },
  pageBorderLeft: { style: BorderStyle.SINGLE, size: 12, space: 24, color: COLOR_BLACK },
  pageBorderRight: { style: BorderStyle.SINGLE, size: 12, space: 24, color: COLOR_BLACK },
};

const A4_PROPERTIES = {
  page: {
    size: { width: 11906, height: 16838 },
    margin: { top: 1100, bottom: 1100, left: 1200, right: 1200 },
    borders: PAGE_BORDER_CONFIG,
  }
};

// Formatting helpers
function createHeading(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 80, after: 240 },
    children: [
      new TextRun({
        text: text,
        font: FONT_FAMILY,
        size: 50, // 25 pt
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
        color: COLOR_BLACK,
      })
    ]
  });
}

function createSubHeading(text, before = 180, after = 100) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { before: before, after: after },
    children: [
      new TextRun({
        text: text,
        font: FONT_FAMILY,
        size: 32, // 16 pt
        bold: true,
        color: COLOR_BLACK,
      })
    ]
  });
}

function createBodyP(text, size = 30, line = 280, before = 80, after = 120) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { before: before, after: after, line: line },
    children: [
      new TextRun({
        text: text,
        font: FONT_FAMILY,
        size: size, // 15 pt default
        color: COLOR_BLACK,
      })
    ]
  });
}

function createBulletItem(funcName, desc, size = 26, before = 40, after = 60) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { before: before, after: after, line: 240 },
    children: [
      new TextRun({
        text: "➢ ",
        font: FONT_FAMILY,
        size: size,
        bold: true,
        color: COLOR_BLACK,
      }),
      new TextRun({
        text: funcName + " ",
        font: FONT_FAMILY,
        size: size,
        bold: true,
        color: COLOR_BLACK,
      }),
      new TextRun({
        text: "– " + desc,
        font: FONT_FAMILY,
        size: size,
        bold: false,
        color: COLOR_BLACK,
      })
    ]
  });
}

function createBorderedBox(children, widthDxa = 9200) {
  return new Table({
    width: { size: widthDxa, type: WidthType.DXA },
    alignment: AlignmentType.CENTER,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      bottom: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      left: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      right: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
    },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: widthDxa, type: WidthType.DXA },
            margins: { top: 120, bottom: 120, left: 160, right: 160 },
            shading: { fill: "FFFFFF", type: ShadingType.CLEAR },
            children: children
          })
        ]
      })
    ]
  });
}

function getImageRun(relPath, widthPx, heightPx) {
  const fullPath = path.resolve(__dirname, '..', relPath);
  if (fs.existsSync(fullPath)) {
    const data = fs.readFileSync(fullPath);
    return new ImageRun({
      data: data,
      transformation: { width: widthPx, height: heightPx }
    });
  }
  return new TextRun({ text: `[IMAGE: ${relPath}]`, font: FONT_FAMILY, size: 22, bold: true });
}

function createFigureBox(imageRelPath, widthPx = 520, heightPx = 260) {
  const imgRun = getImageRun(imageRelPath, widthPx, heightPx);
  return new Table({
    width: { size: 9200, type: WidthType.DXA },
    alignment: AlignmentType.CENTER,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      bottom: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      left: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      right: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
    },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: 9200, type: WidthType.DXA },
            margins: { top: 80, bottom: 80, left: 120, right: 120 },
            children: [
              new Paragraph({
                alignment: AlignmentType.CENTER,
                spacing: { before: 20, after: 20 },
                children: [imgRun]
              })
            ]
          })
        ]
      })
    ]
  });
}

function createCodeBox(title, lines) {
  const pList = [
    new Paragraph({
      spacing: { before: 20, after: 40 },
      children: [
        new TextRun({
          text: `# ${title}`,
          font: MONO_FONT,
          size: 21, // 10.5 pt
          bold: true,
          color: COLOR_BLUE,
        })
      ]
    })
  ];

  lines.forEach(l => {
    pList.push(
      new Paragraph({
        spacing: { before: 10, after: 10 },
        children: [
          new TextRun({
            text: l,
            font: MONO_FONT,
            size: 19, // 9.5 pt
            color: COLOR_BLACK,
          })
        ]
      })
    );
  });

  return createBorderedBox(pList);
}

function createConsoleBox(lines) {
  const pList = lines.map(line => {
    const isPrompt = line.startsWith(">");
    return new Paragraph({
      spacing: { before: 10, after: 10 },
      children: [
        new TextRun({
          text: line,
          font: MONO_FONT,
          size: 19, // 9.5 pt
          bold: isPrompt,
          color: isPrompt ? COLOR_BLUE : COLOR_BLACK,
        })
      ]
    });
  });

  return createBorderedBox(pList);
}

// -------------------------------------------------------------
// PAGE 1: COVER PAGE
// -------------------------------------------------------------
const p1Children = [
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 40, after: 160 },
    children: [getImageRun('report_assets/extracted/page_1_Image17.png', 160, 90)]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 100, after: 140 },
    children: [
      new TextRun({
        text: "Fall Semester 2026-27",
        font: FONT_FAMILY,
        size: 76, // 38 pt
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
      })
    ]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 80 },
    children: [
      new TextRun({
        text: "Probability & Statistics",
        font: FONT_FAMILY,
        size: 76, // 38 pt
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
      })
    ]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 80, after: 200 },
    children: [
      new TextRun({
        text: "(BMAT202P)",
        font: FONT_FAMILY,
        size: 76, // 38 pt
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
      })
    ]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 160, after: 160 },
    children: [
      new TextRun({
        text: "PROJECT REPORT",
        font: FONT_FAMILY,
        size: 60, // 30 pt
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
      })
    ]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 120, after: 60 },
    children: [
      new TextRun({
        text: "Can Statistics Detect Fake Data?",
        font: FONT_FAMILY,
        size: 46, // 23 pt
        bold: true,
      })
    ]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 0, after: 220 },
    children: [
      new TextRun({
        text: "Identifying Anomalies and Outliers in Real Datasets",
        font: FONT_FAMILY,
        size: 42, // 21 pt
        bold: true,
      })
    ]
  }),
  new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { before: 100, after: 320 },
    children: [
      new TextRun({
        text: "Faculty: ",
        font: FONT_FAMILY,
        size: 40, // 20 pt
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
      }),
      new TextRun({
        text: "Dr. Tharasi Dilleswar",
        font: FONT_FAMILY,
        size: 40, // 20 pt
        bold: true,
      })
    ]
  }),
  new Table({
    width: { size: 5000, type: WidthType.DXA },
    alignment: AlignmentType.LEFT,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      bottom: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      left: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      right: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
    },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: 5000, type: WidthType.DXA },
            margins: { top: 100, bottom: 100, left: 140, right: 140 },
            children: [
              new Paragraph({
                spacing: { after: 60 },
                children: [
                  new TextRun({
                    text: "Submitted By: (Team 1)",
                    font: FONT_FAMILY,
                    size: 28, // 14 pt
                    bold: true,
                  })
                ]
              }),
              new Paragraph({
                spacing: { after: 40 },
                children: [
                  new TextRun({
                    text: "SHAIK SAMEER – 24BDS1154",
                    font: FONT_FAMILY,
                    size: 24, // 12 pt
                    bold: true,
                  })
                ]
              }),
              new Paragraph({
                spacing: { after: 20 },
                children: [
                  new TextRun({
                    text: "JOSHITA CHOWDARY D – 24BRS1313",
                    font: FONT_FAMILY,
                    size: 24, // 12 pt
                    bold: true,
                  })
                ]
              })
            ]
          })
        ]
      })
    ]
  })
];

// -------------------------------------------------------------
// PAGE 2: CONTENTS
// -------------------------------------------------------------
const p2Children = [createHeading("Contents")];

function createTocRow(num, title, pageNum, isSub = false) {
  const dotsCount = isSub ? 38 : 42;
  const dots = ".".repeat(dotsCount);
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { before: 120, after: 120, line: 280 },
    indent: { left: isSub ? 720 : 360 },
    children: [
      new TextRun({
        text: isSub ? "➢ " : `${num}. `,
        font: FONT_FAMILY,
        size: 32, // 16 pt
        bold: true,
      }),
      new TextRun({
        text: title,
        font: FONT_FAMILY,
        size: 32,
        bold: true,
      }),
      new TextRun({
        text: ` ${dots} `,
        font: FONT_FAMILY,
        size: 32,
        bold: true,
      }),
      new TextRun({
        text: `${pageNum}`,
        font: FONT_FAMILY,
        size: 32,
        bold: true,
      })
    ]
  });
}

p2Children.push(createTocRow(1, "Introduction", 3));
p2Children.push(createTocRow(2, "Functions Used", 4));
p2Children.push(createTocRow(3, "Data Analysis", 5));
p2Children.push(createTocRow(null, "Code", 5, true));
p2Children.push(createTocRow(null, "Console Outputs", 9, true));
p2Children.push(createTocRow(null, "Data Visualisation", 14, true));
p2Children.push(createTocRow(null, "Result", 18, true));

// -------------------------------------------------------------
// PAGE 3: INTRODUCTION
// -------------------------------------------------------------
const p3Children = [
  createHeading("Introduction"),
  createBodyP(
    "The following project report deals with the statistical screening of real-world datasets to identify anomalies, irregularities, and potential data manipulation using Benford's Law and Pearson's Chi-square goodness-of-fit testing in RStudio.",
    28, 260, 60, 100
  ),
  createBodyP(
    "RStudio is an Integrated Development Environment (IDE) for R, which is a programming language widely utilized for statistical computing and graphics. In this project, R provides the computational foundation for ingesting high-volume tabular records, parsing significant digits from floating-point values, and executing hypothesis tests.",
    28, 260, 60, 100
  ),
  createBodyP(
    "Originally noted by Simon Newcomb in 1881 and comprehensively formalized by Frank Benford in 1938 across 20 distinct physical and socioeconomic domains, Benford's Law states that in scale-invariant datasets spanning multiple orders of magnitude, the leading significant digits (d in 1..9) follow a logarithmic distribution: P(d) = log10(1 + 1/d). Under this distribution, digit 1 occurs approximately 30.1% of the time, while digit 9 occurs only 4.6% of the time.",
    28, 260, 60, 100
  ),
  createBodyP(
    "We evaluate whether empirical distributions from the World Bank World Development Indicators (WDI) panel (105,346 rows across 9 macroeconomic indicators) and USAspending federal procurement transactions (81,277 positive obligations) conform to this natural law. The analysis incorporates Mark Nigrini's Mean Absolute Deviation (MAD), Pearson residuals, and an interactive Shiny dashboard for live diagnostic screening.",
    28, 260, 60, 100
  ),
  createBodyP(
    "CRITICAL INTERPRETATION BOUNDARY: A statistically significant departure from Benford's Law is strictly an operational screening flag warranting audit review; it does not constitute definitive proof of fraud or intentional manipulation.",
    28, 260, 60, 140
  ),
  new Paragraph({
    spacing: { before: 120, after: 40 },
    children: [
      new TextRun({
        text: "Sources:",
        font: FONT_FAMILY,
        size: 24,
        bold: true,
        underline: { type: UnderlineType.SINGLE, color: COLOR_BLACK },
      })
    ]
  }),
  new Paragraph({
    spacing: { before: 20, after: 20, line: 200 },
    children: [
      new TextRun({
        text: "1. Newcomb, S. (1881). Note on the frequency of use of different digits in natural numbers. Amer. J. Math., 4(1), 39–40.\n2. Benford, F. (1938). The law of anomalous numbers. Proc. Amer. Phil. Soc., 78(4), 551–572.\n3. Nigrini, M. J. (2012). Benford's Law: Applications for Forensic Accounting, Auditing, and Fraud Detection. John Wiley & Sons.\n4. Hill, T. P. (1995). A statistical derivation of the significant-digit law. Statistical Science, 10(4), 354–363.\n5. World Bank (2026). World Development Indicators Bulk Archive. Databank.",
        font: FONT_FAMILY,
        size: 20, // 10 pt
        color: COLOR_MUTED,
      })
    ]
  })
];

// -------------------------------------------------------------
// PAGE 4: FUNCTIONS USED
// -------------------------------------------------------------
const p4Children = [
  createHeading("Functions"),
  createBulletItem("read.csv()", "Imports tabular CSV dataset records into R data frames for processing."),
  createBulletItem("summary()", "Computes five-number summary statistics (minimum, 1st quartile, median, mean, 3rd quartile, maximum)."),
  createBulletItem("var()", "Computes sample variance across multi-order macroeconomic indicators and simulation outputs."),
  createBulletItem("cov()", "Calculates sample covariance between pairs of transformed numerical variables."),
  createBulletItem("cor()", "Evaluates the Pearson product-moment correlation coefficient between observed and theoretical frequencies."),
  createBulletItem("cor.test()", "Conducts hypothesis tests for correlation (Pearson and Spearman rank methods) with exact p-values."),
  createBulletItem("chisq.test()", "Executes Pearson's Chi-square goodness-of-fit test against theoretical Benford distribution probabilities."),
  createBulletItem("lm()", "Fits linear regression models, such as predicting MAD growth as a function of perturbation rate."),
  createBulletItem("abline()", "Overlays fitted linear regression trend lines and Nigrini conformity threshold levels onto scatter plots."),
  createBulletItem("p.adjust()", "Applies Holm and Benjamini-Hochberg corrections to raw p-values for families of simultaneous tests."),
  createBulletItem("plot()", "Plots bivariate points and trend lines to provide visual diagnostic inspection of data vectors."),
  new Paragraph({
    spacing: { before: 120, after: 60 },
    children: [
      new TextRun({
        text: "(Data visualisation function)",
        font: FONT_FAMILY,
        size: 28, // 14 pt
        bold: true,
      })
    ]
  }),
  createBulletItem("hist()", "Creates frequency distribution histograms for raw-scale and log10-transformed continuous variables."),
  createBulletItem("barplot()", "Creates categorical bar charts comparing observed digit frequencies with theoretical Benford decay."),
  createBulletItem("pie()", "Plots proportional circular pie charts displaying the empirical percentage share of each leading digit."),
  createBulletItem("boxplot()", "Produces box-and-whisker plots depicting dispersion and outlier behavior across Monte Carlo replicates."),
  createBulletItem("shinyApp()", "Boots the reactive Shiny dashboard server and UI interface for interactive data exploration.")
];

// -------------------------------------------------------------
// PAGES 5 TO 8: DATA ANALYSIS - CODE
// -------------------------------------------------------------

// Page 5: AIM, CODE header, Snippet 1 & 2
const p5Children = [
  createHeading("Data Analysis"),
  new Paragraph({
    spacing: { before: 60, after: 100, line: 260 },
    children: [
      new TextRun({ text: "AIM: ", font: FONT_FAMILY, size: 28, bold: true }),
      new TextRun({
        text: "To import real-world macroeconomic and procurement datasets, evaluate their leading-digit conformance to Benford's Law using Chi-Square and MAD statistics in RStudio, and present the analytical workflow via an interactive Shiny web dashboard.",
        font: FONT_FAMILY,
        size: 28,
      })
    ]
  }),
  createSubHeading("CODE:", 120, 60),
  new Paragraph({
    spacing: { before: 20, after: 120 },
    children: [
      new TextRun({
        text: "Note: The complete, executable codebase and automated test suite are hosted at our GitHub repository: https://github.com/sameershaik-vit/benford-anomaly-detection",
        font: FONT_FAMILY,
        size: 23,
        italic: true,
        color: COLOR_MUTED,
      })
    ]
  }),
  createCodeBox("1. Data Import & Numeric Cleaning", [
    "library(readr); library(dplyr); library(tidyr)",
    "wdi_panel <- read.csv('data/processed/wdi_curated_panel.csv')",
    "clean_numeric <- function(vec) {",
    "  v <- suppressWarnings(as.numeric(vec))",
    "  v[is.finite(v) & v > 0] # exclude non-positive, zero, and missing values",
    "}",
    "pop_clean <- clean_numeric(wdi_panel$SP.POP.TOTL)",
    "gdp_clean <- clean_numeric(wdi_panel$NY.GDP.MKTP.CD)"
  ]),
  new Paragraph({ spacing: { after: 120 } }),
  createCodeBox("2. First Significant Digit Extraction", [
    "mantissa_digits <- function(x) {",
    "  s <- sprintf('%.14e', abs(x))",
    "  gsub('[^0-9]', '', sub('e.*$', '', s))",
    "}",
    "first_digit <- function(x) {",
    "  ok <- is.finite(x) & x != 0",
    "  out <- rep(NA_real_, length(x))",
    "  if (any(ok)) out[ok] <- as.numeric(substr(mantissa_digits(x[ok]), 1L, 1L))",
    "  out",
    "}",
    "pop_digits <- table(factor(first_digit(pop_clean), levels = 1:9))"
  ])
];

// Page 6: Snippet 3 & 4
const p6Children = [
  createCodeBox("3. Benford Theoretical Reference Distribution", [
    "benford_first_probs <- function() {",
    "  d <- 1:9",
    "  p <- log10(1 + 1 / d)",
    "  names(p) <- as.character(d); p",
    "}",
    "benford_expected_counts <- function(probs, n) {",
    "  as.numeric(n) * as.numeric(probs)",
    "}",
    "exp_pop_counts <- benford_expected_counts(benford_first_probs(), sum(pop_digits))"
  ]),
  new Paragraph({ spacing: { after: 140 } }),
  createCodeBox("4. Chi-Square Goodness-of-Fit and MAD Scoring", [
    "chisq_res <- chisq.test(as.numeric(pop_digits), p = benford_first_probs())",
    "obs_prop  <- as.numeric(pop_digits) / sum(pop_digits)",
    "mad_score <- mean(abs(obs_prop - benford_first_probs()))",
    "classify_mad <- function(mad) {",
    "  if (mad <= 0.006) 'Close Conformity'",
    "  else if (mad <= 0.012) 'Acceptable Conformity'",
    "  else if (mad <= 0.015) 'Marginally Acceptable'",
    "  else 'Nonconformity (Flagged Anomaly)'",
    "}",
    "conformity_tier <- classify_mad(mad_score)",
    "std_residuals <- (as.numeric(pop_digits) - exp_pop_counts) / sqrt(exp_pop_counts)"
  ])
];

// Page 7: Snippet 5 & 6
const p7Children = [
  createCodeBox("5. Monte Carlo Synthetic Perturbation Experiment", [
    "run_simulation <- function(n_reps = 100, rates = c(0, 0.05, 0.10, 0.15, 0.20)) {",
    "  results <- expand.grid(rep = 1:n_reps, rate = rates)",
    "  results$mad <- vapply(results$rate, function(r) {",
    "    sample_vals <- rlnorm(5000, 10, 2.5)",
    "    if (r > 0) {",
    "      n_alt <- round(5000 * r)",
    "      sample_vals[1:n_alt] <- round(sample_vals[1:n_alt], -3) # round-number injection",
    "    }",
    "    d <- table(factor(first_digit(sample_vals), levels = 1:9))",
    "    mean(abs((d / sum(d)) - benford_first_probs()))",
    "  }, numeric(1))",
    "  results",
    "}"
  ]),
  new Paragraph({ spacing: { after: 140 } }),
  createCodeBox("6. Core Reactive Shiny Server Pipeline (app.R)", [
    "server <- function(input, output, session) {",
    "  active_data <- reactive({",
    "    req(input$selected_indicator)",
    "    clean_numeric(wdi_panel[[input$selected_indicator]])",
    "  })",
    "  output$benford_plot <- renderPlot({",
    "    vals <- active_data()",
    "    obs  <- table(factor(first_digit(vals), levels = 1:9)) / length(vals)",
    "    bp   <- barplot(obs * 100, col = 'blue', ylim = c(0, 35))",
    "    lines(bp, benford_first_probs() * 100, col = 'red', type = 'b', pch = 19)",
    "  })",
    "}"
  ])
];

// Page 8: Snippet 7
const p8Children = [
  createCodeBox("7. Hypothesis Testing and Linear Regression Models", [
    "# Pearson and Spearman Correlation Tests",
    "corr_pearson  <- cor.test(obs_shares, exp_shares, method = 'pearson')",
    "corr_spearman <- cor.test(obs_shares, exp_shares, method = 'spearman')",
    "",
    "# Linear Model 1: MAD growth vs Synthetic Perturbation Rate",
    "regr_mad <- lm(sim_mads ~ sim_rates)",
    "summary(regr_mad)",
    "",
    "# Linear Model 2: Observed vs Expected Probability Decay",
    "regr_shares <- lm(obs_shares ~ exp_shares)",
    "summary(regr_shares)"
  ])
];

// -------------------------------------------------------------
// PAGES 9 TO 13: CONSOLE OUTPUT
// -------------------------------------------------------------
const transcriptRaw = fs.readFileSync(path.resolve(__dirname, '../report_assets/console_transcript.txt'), 'utf-8');
const allLines = transcriptRaw.split(/\r?\n/).filter(l => l.trim().length > 0);

// Page 9: Data Import & Summary
const p9Children = [
  createHeading("Data Analysis"),
  createSubHeading("CONSOLE OUTPUT:", 100, 100),
  createConsoleBox(allLines.slice(0, 20))
];

// Page 10: Variances, Covariances, Correlations
const p10Children = [
  createConsoleBox(allLines.slice(20, 64))
];

// Page 11: Chi-Square Tests
const p11Children = [
  createConsoleBox(allLines.slice(64, 88))
];

// Page 12: Linear Regression Model 1 (MAD on Perturbation Rate)
const p12Children = [
  createConsoleBox(allLines.slice(88, 111))
];

// Page 13: Linear Regression Model 2 (Observed vs Expected Shares)
const p13Children = [
  createConsoleBox(allLines.slice(111))
];

// -------------------------------------------------------------
// PAGES 14 TO 18: DATA VISUALISATION & RESULT
// -------------------------------------------------------------

// Page 14: DATA VISUALISATION: Regression Plots -
const p14Children = [
  createHeading("Data Analysis"),
  createSubHeading("DATA VISUALISATION:", 100, 80),
  createSubHeading("Regression Plots -", 100, 100),
  createFigureBox('report_assets/figures/plot_regression_1.png', 480, 240),
  new Paragraph({ spacing: { after: 120 } }),
  createFigureBox('report_assets/figures/plot_regression_2.png', 480, 240)
];

// Page 15: Histograms -
const p15Children = [
  createSubHeading("Histograms -", 60, 80),
  createFigureBox('report_assets/figures/plot_hist_1.png', 460, 180),
  new Paragraph({ spacing: { after: 60 } }),
  createFigureBox('report_assets/figures/plot_hist_2.png', 460, 180),
  new Paragraph({ spacing: { after: 60 } }),
  createFigureBox('report_assets/figures/plot_hist_3.png', 460, 180)
];

// Page 16: Bar Plots -
const p16Children = [
  createSubHeading("Bar Plots -", 80, 100),
  createFigureBox('report_assets/figures/plot_bar_1.png', 480, 240),
  new Paragraph({ spacing: { after: 120 } }),
  createFigureBox('report_assets/figures/plot_bar_2.png', 480, 240)
];

// Page 17: Box Plots - & Pie Chart -
const p17Children = [
  createSubHeading("Box Plots -", 60, 80),
  createFigureBox('report_assets/figures/plot_box_1.png', 460, 175),
  new Paragraph({ spacing: { after: 60 } }),
  createFigureBox('report_assets/figures/plot_box_2.png', 460, 175),
  createSubHeading("Pie Chart -", 80, 80),
  createFigureBox('report_assets/figures/plot_pie.png', 440, 220)
];

// Page 18: Scatter Plot -, Line Plot -, Web App Screen, RESULT:
function createPlaceholderBox(label, heightPt = 100) {
  return new Table({
    width: { size: 9200, type: WidthType.DXA },
    alignment: AlignmentType.CENTER,
    borders: {
      top: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      bottom: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      left: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
      right: { style: BorderStyle.SINGLE, size: 12, color: COLOR_BLACK },
    },
    rows: [
      new TableRow({
        children: [
          new TableCell({
            width: { size: 9200, type: WidthType.DXA },
            margins: { top: 100, bottom: 100, left: 160, right: 160 },
            shading: { fill: "F9FAFC", type: ShadingType.CLEAR },
            children: [
              new Paragraph({
                alignment: AlignmentType.CENTER,
                spacing: { before: 40, after: 40 },
                children: [
                  new TextRun({
                    text: label,
                    font: FONT_FAMILY,
                    size: 22,
                    bold: true,
                    color: COLOR_MUTED,
                  })
                ]
              })
            ]
          })
        ]
      })
    ]
  });
}

const p18Children = [
  createSubHeading("Scatter Plot -", 40, 60),
  createFigureBox('report_assets/figures/plot_scatter.png', 460, 170),
  createSubHeading("Line Plot -", 60, 60),
  createFigureBox('report_assets/figures/plot_line.png', 460, 170),
  createSubHeading("Web Application Interface -", 60, 60),
  createPlaceholderBox("[UPLOAD SCREENSHOT: screen_overview.png — Shiny Dashboard Landing Page, 1280x720]"),
  createSubHeading("RESULT:", 100, 60),
  createBodyP(
    "Thus, empirical leading-digit distributions across high-volume macroeconomic and procurement datasets have been imported, statistically analyzed, and interactively visualized. In natural macroeconomic indicators spanning multiple orders of magnitude (World Bank WDI Total Population, N = 14,292, and GDP, N = 10,845), observed first digits exhibit exceptional adherence to Benford's theoretical decay (Pearson r = 0.9998, Spearman rho = 1.000, MAD = 0.00518), satisfying Mark Nigrini's strict Close Conformity threshold. Conversely, USAspending procurement contract obligations (N = 81,277) exhibit pronounced nonconformity (Chi-Square = 5382.69, p < 2.2e-16, MAD = 0.02485) driven by a severe digit-1 spike (standardized residual = +58.11), reflecting statutory contract thresholds ($10k, $25k, $100k) and institutional micro-purchase limits.",
    24, 230, 40, 60
  ),
  createBodyP(
    "Furthermore, controlled Monte Carlo perturbation experiments across 100 simulation replicates confirm that Benford screening possesses strong linear sensitivity to round-number manipulation and leading-digit injection (R-squared = 0.9971, slope = 0.424, p = 8.41e-05). Crucially, this empirical investigation confirms that statistical nonconformity functions strictly as an automated, high-priority diagnostic screening flag to direct human audit resources toward anomalous records, rather than definitive forensic proof of fraudulent intent or data falsification.",
    24, 230, 40, 40
  )
];

// -------------------------------------------------------------
// BUILD 18-SECTION DOCUMENT
// -------------------------------------------------------------
const doc = new Document({
  styles: {
    default: {
      document: {
        run: { font: FONT_FAMILY, size: 30, color: COLOR_BLACK },
        paragraph: { spacing: { line: 280 } }
      }
    }
  },
  sections: [
    { properties: A4_PROPERTIES, children: p1Children },
    { properties: A4_PROPERTIES, children: p2Children },
    { properties: A4_PROPERTIES, children: p3Children },
    { properties: A4_PROPERTIES, children: p4Children },
    { properties: A4_PROPERTIES, children: p5Children },
    { properties: A4_PROPERTIES, children: p6Children },
    { properties: A4_PROPERTIES, children: p7Children },
    { properties: A4_PROPERTIES, children: p8Children },
    { properties: A4_PROPERTIES, children: p9Children },
    { properties: A4_PROPERTIES, children: p10Children },
    { properties: A4_PROPERTIES, children: p11Children },
    { properties: A4_PROPERTIES, children: p12Children },
    { properties: A4_PROPERTIES, children: p13Children },
    { properties: A4_PROPERTIES, children: p14Children },
    { properties: A4_PROPERTIES, children: p15Children },
    { properties: A4_PROPERTIES, children: p16Children },
    { properties: A4_PROPERTIES, children: p17Children },
    { properties: A4_PROPERTIES, children: p18Children },
  ]
});

Packer.toBuffer(doc).then(buffer => {
  fs.writeFileSync('Final_Report.docx', buffer);
  console.log("SUCCESS: 18-section Final_Report.docx generated successfully!");
});
