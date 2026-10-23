###############################################################################
##  app.R -- local Shiny dashboard for the Benford's Law project
##  BMAT202L / BMAT202P, Slot F1, VIT Vellore.
##
##  Run with:   Rscript -e "shiny::runApp('app.R')"
##
##  Every number shown in the dashboard is computed live from the currently
##  loaded data. Nothing is hard-coded. Statistical deviation is presented as a
##  flag for review and never as evidence of fraud.
###############################################################################

## ------------------------------------------------------------- bootstrap
find_app_root <- function() {
  d <- normalizePath(getwd())
  for (i in 1:6) {
    if (file.exists(file.path(d, "R", "benford.R"))) return(d)
    up <- dirname(d)
    if (identical(up, d)) break
    d <- up
  }
  normalizePath(getwd())
}
ROOT <- find_app_root()
source(file.path(ROOT, "R", "benford.R"))

library(shiny)
library(bslib)
library(ggplot2)
library(DT)

options(shiny.maxRequestSize = 100 * 1024^2)
options(shiny.host = "127.0.0.1")
## Use a free port by default so a previously running dashboard cannot block
## startup. Set BENFORD_PORT to pin a specific port when needed.
if (nzchar(Sys.getenv("BENFORD_PORT"))) {
  options(shiny.port = as.integer(Sys.getenv("BENFORD_PORT")))
} else if (requireNamespace("httpuv", quietly = TRUE)) {
  options(shiny.port = httpuv::randomPort(min = 7523, max = 7600))
}

## Serve the pipeline outputs and reports through the app itself so the links
## work in the browser (file:/// links are blocked by most browsers).
if (dir.exists(file.path(ROOT, "outputs")))
  addResourcePath("outputs", file.path(ROOT, "outputs"))
if (dir.exists(file.path(ROOT, "reports")))
  addResourcePath("project-reports", file.path(ROOT, "reports"))

## ------------------------------------------------------------- palette/theme
KIT <- list(ink = "#1c1c1c", paper = "#f5f2e8", cream = "#fffdf6",
            grid = "#d9d5c5", red = "#c9352a", green = "#2e7d4f",
            yellow = "#f2c230", orange = "#d97122", pink = "#d45f8c",
            blue = "#2f6f9f", muted = "#6b6658")
CB <- c(observed = KIT$blue, expected = KIT$orange, alt = KIT$green,
        warn = KIT$pink, red = KIT$red)

SUB_FLAG_COLORS <- c(
  "No significant deviation detected" = KIT$blue,
  "Statistical deviation: significant AND practically material" = KIT$red,
  "Statistically significant but small deviation" = KIT$orange,
  "Not assessed - insufficient sample" = "#8b8677",
  "Not assessed - unsuitable data" = "#b9b3a3")

THEME <- bslib::bs_theme(
  version = 5,
  bg = KIT$paper, fg = KIT$ink,
  primary = KIT$ink, secondary = KIT$orange,
  success = KIT$green, warning = KIT$yellow, danger = KIT$red,
  base_font = "Segoe UI, system-ui, -apple-system, sans-serif",
  heading_font = "Segoe Print, Bradley Hand, Segoe UI, sans-serif",
  code_font = "Consolas, Courier New, monospace",
  base_font_size = 14)

theme_kit <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.background  = ggplot2::element_rect(fill = KIT$cream, colour = NA),
      panel.background = ggplot2::element_rect(fill = "#fffdfa", colour = NA),
      panel.grid.major = ggplot2::element_line(colour = KIT$grid, linewidth = 0.3),
      panel.grid.minor = ggplot2::element_blank(),
      axis.text        = ggplot2::element_text(colour = KIT$ink, size = base_size - 1),
      axis.title       = ggplot2::element_text(colour = KIT$ink),
      plot.title       = ggplot2::element_text(face = "bold", colour = KIT$ink, size = base_size + 1),
      plot.subtitle    = ggplot2::element_text(colour = KIT$muted, size = base_size - 1),
      legend.position  = "bottom",
      legend.background = ggplot2::element_rect(fill = KIT$cream, colour = NA),
      legend.key       = ggplot2::element_rect(fill = KIT$cream, colour = NA),
      strip.background = ggplot2::element_rect(fill = KIT$paper, colour = KIT$ink),
      strip.text       = ggplot2::element_text(colour = KIT$ink, face = "bold")
    )
}

BOUNDARY <- paste("A statistically significant deviation from Benford's Law is NOT proof of fraud,",
                  "fabrication or manipulation. It is a diagnostic flag for further review;",
                  "constrained ranges, price thresholds, caps, rounding and non-multiplicative",
                  "processes are all legitimate explanations.")

APP_CSS <- '
:root{--ink:#1c1c1c;--paper:#f5f2e8;--cream:#fffdf6;--grid:#d9d5c5;--red:#c9352a;
--green:#2e7d4f;--yellow:#f2c230;--orange:#d97122;--pink:#d45f8c;--blue:#2f6f9f;
--muted:#6b6658;--head:"Segoe Print","Bradley Hand","Comic Sans MS",cursive;
--mono:Consolas,"Courier New",monospace}
html,body{background:var(--paper);margin:0;padding:0;width:100%;min-height:100vh}
body{color:var(--ink);font-family:"Segoe UI",system-ui,-apple-system,sans-serif;font-size:14px}
.container-fluid{padding:0 !important;margin:0 !important;max-width:100% !important;width:100% !important}
.desk{padding:0;margin:0;width:100%;min-height:100vh;background:var(--paper)}
.kit{max-width:100% !important;width:100% !important;margin:0;background:var(--paper);border:none;border-bottom:4px solid var(--ink);
border-radius:0;box-shadow:none;overflow:visible;min-height:100vh;display:flex;flex-direction:column}
.lid{position:relative;border-bottom:4px solid var(--ink);padding:14px 24px 12px;
background:repeating-linear-gradient(45deg,var(--paper) 0 10px,#ebe7d8 10px 11px);
display:flex;gap:16px;align-items:center;flex-wrap:wrap}
.rivet{position:absolute;width:11px;height:11px;border:2px solid var(--ink);border-radius:50%;
background:radial-gradient(circle at 35% 35%,#fff,#aaa)}
.r1{left:8px;top:8px}.r2{right:8px;top:8px}.r3{left:8px;bottom:8px}.r4{right:8px;bottom:8px}
.brand{flex:1 1 460px;min-width:260px}
.eyebrow{margin:0 0 2px;font-family:var(--mono);font-size:10px;letter-spacing:.12em;
text-transform:uppercase;color:var(--muted)}
.lid h1{margin:0 0 3px;font-family:var(--head);font-size:clamp(24px,3.2vw,40px);
line-height:1.05;letter-spacing:.01em;text-transform:uppercase}
.lid h1 span{background:var(--yellow);border:2px solid var(--ink);padding:0 8px;
display:inline-block;transform:rotate(-1.4deg)}
.tagline{margin:0;font-size:13px;line-height:1.35;max-width:760px;color:#3d3a32}
.lid-side{margin-left:auto;display:flex;flex-direction:column;gap:8px;align-items:flex-end}
.source-chip{border:2px solid var(--ink);background:var(--cream);padding:5px 9px;
border-radius:4px 10px 4px 10px;font-family:var(--mono);font-size:11px;max-width:390px;
line-height:1.35;overflow-wrap:anywhere}
.source-chip b{display:block;font-size:9px;text-transform:uppercase;letter-spacing:.1em;color:var(--muted)}
.lid-actions{display:flex;gap:8px}
.boundary-strip{background:#fdf3c9;border-bottom:3px solid var(--ink);padding:7px 24px;
font-size:12px;line-height:1.35}
.boundary-strip strong{text-transform:uppercase;letter-spacing:.04em;font-size:11px}
.kit .nav-tabs{display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:6px;
padding:12px 24px 8px;border:0;margin:0;background:transparent}
.kit .nav-tabs > li{margin:0;min-width:0}
.kit .nav-tabs > li > a,.kit .nav-tabs .nav-link{display:block;background:var(--paper);
color:var(--ink);border:2px solid var(--ink) !important;border-radius:4px 12px 4px 12px;
padding:6px 7px;min-height:52px;font-weight:700;line-height:1.1;
box-shadow:2px 2px 0 rgba(28,28,28,.18);transition:transform .12s,box-shadow .12s,background .12s;
white-space:normal;text-decoration:none;margin:0}
.kit .nav-tabs > li > a:hover,.kit .nav-tabs .nav-link:hover{background:#fff;
transform:translate(-1px,-1px);box-shadow:4px 4px 0 var(--ink);color:var(--ink)}
.kit .nav-tabs > li.active > a,.kit .nav-tabs .nav-link.active{background:var(--ink) !important;
color:var(--paper) !important;box-shadow:3px 3px 0 var(--orange);transform:none}
.kit .nav-tabs > li.active > a small,.kit .nav-tabs .nav-link.active small{color:#d8d3c5}
.tool-line{display:grid;grid-template-columns:auto auto 1fr;column-gap:6px;align-items:center;
text-align:left;min-width:0}
.tool-dot{width:9px;height:9px;border:1.5px solid var(--ink);border-radius:50%;
background:var(--dot,var(--yellow))}
.tool-kicker{font-family:var(--mono);font-size:8px;letter-spacing:.08em;color:var(--muted)}
.tool-name{font-weight:800;font-size:12px;overflow-wrap:anywhere}
.tool-line small{grid-column:1 / -1;display:block;font-size:10.5px;font-weight:400;
opacity:.72;margin-top:2px;line-height:1.15}
.tab-content{padding:0 24px 20px;flex:1 0 auto}
.tab-pane{background:var(--cream);background-image:
linear-gradient(var(--grid) 1px,transparent 1px),
linear-gradient(90deg,var(--grid) 1px,transparent 1px);
background-size:22px 22px;border:3px solid var(--ink);border-radius:6px 18px 6px 12px;
padding:16px 18px;min-height:440px;width:100%;box-sizing:border-box}
.tab-pane h3{font-size:21px;text-decoration:underline wavy var(--red);text-underline-offset:5px;
margin:0 0 8px}
.tab-pane h4{font-size:14px;text-transform:uppercase;letter-spacing:.05em;margin:12px 0 6px}
.panel{border:2px solid var(--ink);background:var(--cream);border-radius:4px 14px 4px 14px;
padding:12px 14px;margin:0 0 14px;box-shadow:3px 3px 0 rgba(28,28,28,.12);overflow-x:auto}
.panel > h3:first-child,.panel > h4:first-child,.panel > h2:first-child{margin-top:0}
.note{border:2px dashed var(--ink);background:var(--paper);padding:8px 10px;margin:8px 0;
font-size:13px;line-height:1.4;border-radius:3px}
.note.bad{border-color:var(--red);background:#fbe9e6}
.note.warn{border-color:var(--orange);background:#fdf1e4}
.note.ok{border-color:var(--green);background:#e9f5ed}
.note .mono{font-family:var(--mono)}
.with-side{display:grid;grid-template-columns:280px minmax(0,1fr);gap:14px;align-items:start}
.with-side.two-up{grid-template-columns:1fr 1fr;margin-bottom:0}
.side-card{border:2px solid var(--ink);background:var(--cream);border-radius:18px 4px 12px 4px;
padding:12px;margin-bottom:12px}
.side-card h4{margin-top:0}
.main-col{min-width:0;width:100%}
.section-head{display:flex;align-items:baseline;gap:10px;flex-wrap:wrap;margin:0 0 8px}
.section-head h3{margin:0}
.section-head .mono{font-family:var(--mono);font-size:11px;color:var(--muted)}
.stat-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(128px,1fr));gap:8px;
margin:10px 0}
.stat{border:2px solid var(--ink);background:var(--cream);padding:7px 9px;
border-radius:3px 12px 3px 12px;min-width:0}
.stat b{display:block;font-family:var(--mono);font-size:20px;line-height:1.15;overflow-wrap:anywhere}
.stat span{display:block;font-size:11px;color:var(--muted);line-height:1.25;margin-top:2px}
.stat.ok b{color:var(--green)}.stat.warn b{color:var(--orange)}.stat.bad b{color:var(--red)}
.stat.muted b{color:var(--muted)}
.stamp{display:inline-block;border:3px solid var(--red);color:var(--red);
font-family:var(--mono);font-weight:700;font-size:13px;padding:3px 10px;
transform:rotate(-2deg);text-transform:uppercase;background:var(--paper);
letter-spacing:.04em;margin:4px 0}
.stamp.ok{border-color:var(--green);color:var(--green)}
.stamp.muted{border-color:var(--muted);color:var(--muted)}
.hero-wrap{display:grid;grid-template-columns:minmax(0,1fr) auto;gap:12px;align-items:start;
margin-bottom:12px}
.hero-side{text-align:right;max-width:280px}
.caption{font-size:12px;color:var(--muted);margin:4px 0 0;line-height:1.35}
.mono{font-family:var(--mono)}
.formula{background:var(--cream);border:2px solid var(--ink);border-radius:4px 14px 4px 14px;
padding:10px;text-align:center;font-family:var(--mono);overflow-x:auto;font-size:13px}
.form-control,.form-select{border:2px solid var(--ink) !important;border-radius:4px;
background:#fffdf8;color:var(--ink);box-shadow:none !important;font-size:13px;padding:6px 8px}
.form-control:focus,.form-select:focus{border-color:var(--ink) !important;
box-shadow:0 0 0 3px rgba(242,194,48,.55) !important}
.form-check-input{border:2px solid var(--ink) !important}
.form-check-input:checked{background-color:var(--ink) !important;border-color:var(--ink) !important}
label,.control-label{font-weight:700;font-size:12px;letter-spacing:.02em}
.help-block,.help-text{font-size:11.5px;color:var(--muted)}
.btn{font-weight:700;border:2px solid var(--ink);border-radius:4px 12px 4px 12px;
background:var(--paper);color:var(--ink);box-shadow:2px 2px 0 var(--ink)}
.btn:hover,.btn:focus{background:var(--yellow);color:var(--ink);
transform:translate(-1px,-1px);box-shadow:3px 3px 0 var(--ink)}
.btn-primary{background:var(--ink);color:var(--paper);border-color:var(--ink)}
.btn-primary:hover,.btn-primary:focus{background:var(--orange);color:var(--ink)}
.btn-sm{padding:4px 8px;font-size:12px}
.btn .fa,.btn .fas{color:inherit}
.w-100{width:100%}
.table{font-size:12.5px;background:transparent;margin-bottom:0}
.table > thead > tr > th{background:#ebe7d8;border-bottom:2px solid var(--ink) !important;
font-size:11px;text-transform:uppercase;letter-spacing:.04em;vertical-align:bottom}
.table > tbody > tr > td{border-color:var(--grid) !important;vertical-align:top}
.table-striped > tbody > tr:nth-of-type(odd) > *{background:#fbf8ee}
.dataTables_wrapper{font-size:12.5px}
.dataTables_wrapper .dataTables_filter input{border:2px solid var(--ink);border-radius:4px;
background:#fffdf8;padding:3px 6px;margin-left:6px}
.dataTables_wrapper .dataTables_length select{border:2px solid var(--ink);border-radius:4px;
background:#fffdf8;padding:2px 4px}
.dataTables_wrapper .dataTables_paginate .paginate_button{border:2px solid var(--ink) !important;
border-radius:4px !important;background:var(--paper) !important;color:var(--ink) !important;
margin:0 2px;padding:2px 7px !important}
.dataTables_wrapper .dataTables_paginate .paginate_button.current{background:var(--ink) !important;
color:var(--paper) !important}
table.dataTable{width:100% !important}
.plot-card{border:2px solid var(--ink);background:var(--cream);border-radius:4px 14px 4px 14px;
padding:9px 11px 5px;margin-bottom:14px}
.plot-card h4{margin:0 0 5px;font-size:12px;text-transform:uppercase;letter-spacing:.05em}
.shiny-plot-output{background:var(--cream)}
.recalculating{opacity:.45;transition:opacity .2s;position:relative}
.recalculating::after{content:"";position:absolute;right:10px;top:8px;width:14px;height:14px;
border:2px solid var(--grid);border-top-color:var(--ink);border-radius:50%;
animation:kitspin .8s linear infinite}
@keyframes kitspin{to{transform:rotate(360deg)}}
.shiny-output-error-validation{border:2px dashed var(--orange);background:#fdf1e4;
color:var(--ink);padding:10px 12px;font-size:13px;display:block;border-radius:3px}
.shiny-output-error-validation::before{content:"! ";font-weight:800;color:var(--orange)}
.shiny-output-error{border:2px solid var(--red);background:#fbe9e6;color:var(--ink);
padding:10px 12px;font-size:13px;border-radius:3px}
.empty-state{border:2px dashed var(--grid);background:#fbf9f0;padding:18px;
text-align:center;color:var(--muted);font-size:13px}
.empty-state b{display:block;color:var(--ink);font-size:14px;margin-bottom:3px}
.reason-list{margin:0;padding-left:20px}
.reason-list li{margin:3px 0;font-size:12.5px;line-height:1.35}
.flow{margin:0;padding-left:20px;font-size:12.5px;line-height:1.45}
.flow li{margin:2px 0}
.fact{display:flex;justify-content:space-between;gap:10px;border-bottom:1px dashed var(--grid);
padding:4px 0;font-size:12px}
.fact:last-child{border-bottom:0}
.fact span{color:var(--muted)}
.fact b{font-family:var(--mono);font-weight:600;text-align:right;overflow-wrap:anywhere}
.dl-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:8px}
.dl-grid .btn{width:100%;text-align:left;justify-content:flex-start}
.fig-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:10px}
.fig{border:2px solid var(--ink);background:var(--cream);padding:6px;
border-radius:4px 10px 4px 10px;min-width:0}
.fig img{width:100%;height:auto;display:block;border:1px solid var(--grid);background:#fff}
.fig a{font-family:var(--mono);font-size:10.5px;display:block;margin-top:4px;
color:var(--ink);text-decoration:underline;overflow-wrap:anywhere}
.base{border-top:4px solid var(--ink);padding:10px 24px;display:flex;justify-content:space-between;
gap:10px;flex-wrap:wrap;background:#ebe7d8;font-size:11.5px;margin-top:auto}
.base .mono{font-size:10.5px}
@media (max-width:1300px){
.kit .nav-tabs{grid-template-columns:repeat(4,minmax(0,1fr));gap:6px}
}
@media (max-width:960px){
.with-side,.with-side.two-up{grid-template-columns:1fr}
.hero-wrap{grid-template-columns:1fr}
.hero-side{text-align:left;max-width:none}
}
@media (max-width:680px){
.kit .nav-tabs{grid-template-columns:repeat(2,minmax(0,1fr))}
.kit .nav-tabs > li > a,.kit .nav-tabs .nav-link{min-height:48px;padding:5px}
.lid{padding:10px 14px}
.boundary-strip{padding:6px 14px}
.lid-side{margin-left:0;align-items:flex-start}
.source-chip{max-width:100%}
.kit .nav-tabs{padding:8px 14px 6px;gap:4px}
.tool-name{font-size:11px}
.tab-content{padding:0 14px 14px}
.tab-pane{padding:12px 14px;min-height:0}
.tab-pane h3{font-size:18px}
.base{padding:8px 14px}
}
'

## ------------------------------------------------------------- UI helpers
tool_title <- function(num, name, sub, dot) {
  div(class = "tool-line",
      span(class = "tool-dot", style = paste0("--dot:", dot)),
      span(class = "tool-kicker", num),
      span(class = "tool-name", name),
      tags$small(sub))
}

stat_card <- function(value, label, tone = "") {
  div(class = paste("stat", tone), tags$b(value), tags$span(label))
}

empty_note <- function(msg) {
  div(class = "empty-state", tags$b("Nothing to show yet"), msg)
}

panel_box <- function(..., class = "panel") div(class = class, ...)

plot_card <- function(title, output, caption = NULL) {
  div(class = "plot-card", h4(title), output,
      if (!is.null(caption)) p(class = "caption", caption))
}

boundary_note <- function(class = "note warn") {
  div(class = class, tags$strong("Interpretation boundary. "), BOUNDARY)
}

fmt_int <- function(x) {
  if (length(x) != 1L || is.na(x)) return("\u2014")
  formatC(as.integer(x), big.mark = ",", format = "d")
}
fmt_p <- function(p) {
  if (length(p) != 1L || is.na(p)) return("not run")
  if (p < 1e-4) formatC(p, format = "e", digits = 2) else formatC(p, format = "f", digits = 4)
}
fmt_x2 <- function(x) {
  if (length(x) != 1L || is.na(x)) return("not run")
  formatC(x, format = "f", digits = 2)
}
fmt_mad <- function(x) {
  if (length(x) != 1L || is.na(x)) return("\u2014")
  formatC(x, format = "f", digits = 4)
}

## ------------------------------------------------------------------- UI
ui <- bslib::page_fluid(
  title = "Benford's Geometry Box | BMAT202L / BMAT202P",
  theme = THEME,
  tags$head(tags$style(HTML(APP_CSS))),

  div(class = "desk",
    div(class = "kit",
      tags$i(class = "rivet r1"), tags$i(class = "rivet r2"),
      tags$i(class = "rivet r3"), tags$i(class = "rivet r4"),

      ## ---------------------------------------------------------- lid
      tags$header(class = "lid",
        div(class = "brand",
          p(class = "eyebrow", "BMAT202L / BMAT202P \u00b7 Slot F1 \u00b7 VIT Vellore"),
          h1(span("Benford's"), " Geometry Box"),
          p(class = "tagline",
            "Statistical detection of potentially manipulated data. Eight instruments,",
            " live R analysis, and language that never confuses an unusual pattern with proof of fraud.")
        ),
        div(class = "lid-side",
          uiOutput("active_source"),
          div(class = "lid-actions",
            actionButton("jump_data", "Data desk", class = "btn btn-sm"),
            actionButton("show_boundary", "?", class = "btn btn-sm",
                         `aria-label` = "Interpretation boundary and how to read this dashboard")
          )
        )
      ),
      div(class = "boundary-strip",
        tags$strong("Interpretation boundary: "),
        "a significant deviation is a review flag, not proof of fraud."),

      bslib::navset_tab(
        id = "main_tabs",

        ## -------------------------------------------------- 1 Overview
        bslib::nav_panel(
          title = tool_title("01", "Overview", "the law & method", KIT$yellow),
          value = "overview",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                h4("The law"),
                div(class = "formula", "P(d) = log\u2081\u2080(1 + 1/d)"),
                p(class = "caption", "d = 1 \u2026 9. Expected counts E(d) = N \u00b7 P(d)."),
                div(class = "formula", style = "margin-top:8px;",
                    "X\u00b2 = \u03a3 (O \u2212 E)\u00b2 / E,  df = 8")
              ),
              div(class = "side-card",
                h4("Reading order"),
                tags$ol(class = "flow",
                  tags$li("Stage a dataset on the Data desk."),
                  tags$li("Screen the column for suitability."),
                  tags$li("Read the first-digit test and MAD."),
                  tags$li("Check extended digits and subsets."),
                  tags$li("Use the experiment to see detection limits."),
                  tags$li("Export tables and figures."))
              )
            ),
            div(class = "main-col",
              panel_box(
                h3("Can statistics detect fake data?"),
                p(em("Identifying anomalies and outliers in real datasets using Benford's Law and the chi-square goodness-of-fit test.")),
                p(tags$b("Students: "), "Shaik Sameer (24BDS1154), Joshita Chowdary (24BRS1313) \u2014 ",
                  tags$b("Faculty: "), "Dr. Tharasi Dilleswar"),
                p("The dashboard is a live instrument case: every number is computed from the dataset you stage.",
                  " It is a screening method, not an accusation machine.")
              ),
              div(class = "stat-grid",
                stat_card("8", "analysis instruments"),
                stat_card("df = 8", "first-digit chi-square"),
                stat_card("0.006", "MAD close-conformity band"),
                stat_card("\u03b1", "adjustable on the test tab")
              ),
              panel_box(
                h4("The eight-stage flow"),
                tags$ol(class = "flow",
                  tags$li("Dataset selection \u2014 bundled USAspending, World Bank WDI, upload or labelled synthetic sample."),
                  tags$li("Data preparation in R \u2014 import, type conversion, missing/zero/negative handling, tidy reshaping."),
                  tags$li("Exploratory analysis \u2014 descriptive statistics, histograms, log-scale histograms."),
                  tags$li("First-digit extraction \u2014 robust extraction of significant digits."),
                  tags$li("Benford expected distribution \u2014 computed from the formula, never from the data."),
                  tags$li("Chi-square goodness-of-fit \u2014 X\u00b2 with validity conditions checked first."),
                  tags$li("Anomaly flagging \u2014 significance AND practical deviation (MAD, Nigrini bands)."),
                  tags$li("Interpretation \u2014 careful language; deviation is a flag, not an accusation."))
              ),
              panel_box(
                h4("Hypotheses and why p alone is not enough"),
                tags$ul(class = "reason-list",
                  tags$li(tags$b("H0:"), " the observed first-digit distribution is consistent with the Benford distribution."),
                  tags$li(tags$b("H1:"), " the observed first-digit distribution differs significantly from it."),
                  tags$li("Reject H0 when p < \u03b1; \u03b1 is adjustable on the First-Digit Test tab."),
                  tags$li("For very large N chi-square becomes oversensitive, so MAD, Nigrini bands, standardised residuals and Cohen's w are always shown alongside it.")
                )
              ),
              boundary_note()
            )
          )
        ),

        ## ------------------------------------------------------ 2 Data
        bslib::nav_panel(
          title = tool_title("02", "Data", "load & preview", KIT$green),
          value = "data",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                h4("Stage a dataset"),
                radioButtons("src", NULL,
                  choices = c("USAspending Federal Transactions" = "usaspending",
                              "Bundled processed WDI panel" = "bundled",
                              "Upload a CSV" = "upload",
                              "Synthetic sample (labelled)" = "synthetic"),
                  selected = if (file.exists(file.path(ROOT, "data", "raw", "usaspending", "usaspending.csv"))) "usaspending" else "bundled"),
                conditionalPanel("input.src == 'upload'",
                  fileInput("file", "CSV file", accept = c(".csv"))),
                actionButton("load", "Load data", class = "btn-primary w-100"),
                actionButton("jump_col", "Open suitability check \u2192", class = "btn w-100", style = "margin-top:6px;"),
                hr(),
                uiOutput("src_info")
              ),
              div(class = "side-card",
                h4("What gets analysed"),
                p(class = "caption",
                  "Long panels (indicator_code + value) are analysed one indicator at a time.",
                  " Wide CSVs are analysed one numeric column at a time.",
                  " Identifiers, codes and year-like columns are screened out or warned about.")
              )
            ),
            div(class = "main-col",
              uiOutput("synth_banner"),
              panel_box(
                h4("Preview"),
                p(class = "caption", "First 200 rows of the active dataset. The preview always follows the active source."),
                DTOutput("preview")
              ),
              panel_box(
                h4("Cleaning summary of the selected column"),
                p(class = "caption", "Missing, non-finite, invalid text, zero and negative values are counted explicitly. Negative amounts are analysed by magnitude."),
                tableOutput("clean_summary")
              ),
              boundary_note("note")
            )
          )
        ),

        ## ---------------------------------------- 3 Column & suitability
        bslib::nav_panel(
          title = tool_title("03", "Column", "suitability check", KIT$orange),
          value = "column",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                h4("Instruments"),
                uiOutput("col_ui"),
                uiOutput("sub_ui"),
                uiOutput("sub_val"),
                actionButton("jump_first", "Run First-digit test \u2192", class = "btn btn-primary w-100", style = "margin-top:8px;"),
                helpText("Non-numeric and identifier-like columns are warned about or excluded.")
              )
            ),
            div(class = "main-col",
              uiOutput("col_heading"),
              uiOutput("suit_cards"),
              panel_box(
                h4("Suitability verdict"),
                tableOutput("suit_tbl"),
                h4("Reasons"),
                htmlOutput("suit_reasons")
              ),
              panel_box(
                h4("Descriptive statistics"),
                tableOutput("desc_tbl")
              ),
              div(class = "with-side two-up",
                plot_card("Value distribution", plotOutput("hist", height = "300px")),
                plot_card("Log10 distribution", plotOutput("loghist", height = "300px"),
                          "Roughly uniform for Benford-conforming data.")
              )
            )
          )
        ),

        ## --------------------------------------------- 4 First-digit test
        bslib::nav_panel(
          title = tool_title("04", "First digit", "chi-square test", KIT$red),
          value = "first",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                h4("Test controls"),
                uiOutput("col_ui4"),
                uiOutput("sub_ui4"),
                uiOutput("sub_val4"),
                numericInput("alpha", "Significance level (\u03b1)", value = 0.05,
                             min = 0.001, max = 0.2, step = 0.005),
                checkboxInput("boot", "Bootstrap CI for MAD (B = 300)", value = FALSE),
                hr(),
                uiOutput("tier_box"),
                actionButton("jump_extended", "Check extended digits \u2192", class = "btn w-100", style = "margin-top:8px;")
              ),
              boundary_note()
            ),
            div(class = "main-col",
              uiOutput("hero4"),
              panel_box(
                h4("Chi-square goodness-of-fit against Benford's Law"),
                tableOutput("chi_tbl"),
                uiOutput("decision")
              ),
              plot_card("Observed vs expected first-digit proportions", plotOutput("bar", height = "360px")),
              panel_box(
                h4("Per-digit detail"),
                DTOutput("freq_tbl")
              ),
              plot_card("Standardised residuals by digit", plotOutput("resid", height = "300px"),
                        "Dashed lines at \u00b11.96. Residuals describe the column, not individual records."),
              panel_box(
                h4("Practical deviation"),
                tableOutput("mad_tbl"),
                p(class = "caption", "MAD is compared with the Nigrini first-digit bands. A p-value without MAD is incomplete for large N.")
              ),
              conditionalPanel(
                "input.src == 'usaspending'",
                panel_box(
                  h4("Record-level review candidates (USAspending transactions)"),
                  p(class = "caption",
                    "This is a separate, row-level screen of the raw transaction file, not a Benford verdict.",
                    " It compares log10 amounts with awarding-agency + NAICS peers (median/MAD robust z),"),
                  p(class = "caption",
                    "checks 3 IQR, duplicate transaction keys and repeated amount/date/recipient signatures.",
                    " Every flag is a review candidate, never proof of fraud."),
                  actionButton("run_review", "Screen transactions", class = "btn-primary"),
                  uiOutput("review_status"),
                  DTOutput("review_tbl"),
                  div(class = "dl-grid", style = "margin-top:10px;",
                      downloadButton("dl_review", "Download review candidates (CSV)"))
                )
              )
            )
          )
        ),

        ## -------------------------------------------- 5 Extended digits
        bslib::nav_panel(
          title = tool_title("05", "Extended", "2nd digit & pairs", KIT$pink),
          value = "extended",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                h4("Extended-digit controls"),
                uiOutput("col_ui5"),
                uiOutput("sub_ui5"),
                uiOutput("sub_val5"),
                actionButton("jump_compare", "Compare subsets \u2192", class = "btn w-100", style = "margin-top:8px;"),
                helpText("The first-two-digit test has df = 89 and needs a much larger sample. When the sample is too small the test is reported as NOT RUN.")
              )
            ),
            div(class = "main-col",
              uiOutput("ext_hint"),
              panel_box(
                h4("First-two-digit and second-digit tests"),
                tableOutput("two_tbl")
              ),
              plot_card("Second-digit observed vs expected", plotOutput("second_bar", height = "320px")),
              panel_box(
                h4("First-two-digit frequencies (valid rows only)"),
                DTOutput("two_freq")
              ),
              boundary_note("note")
            )
          )
        ),

        ## -------------------------------------------- 6 Compare subsets
        bslib::nav_panel(
          title = tool_title("06", "Compare", "subsets & groups", KIT$blue),
          value = "compare",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                h4("Comparison controls"),
                uiOutput("group_ui"),
                uiOutput("col_ui6"),
                numericInput("min_n", "Minimum N per subset", value = 110, min = 10, step = 10),
                actionButton("jump_experiment", "Open experiment \u2192", class = "btn w-100", style = "margin-top:8px;"),
                helpText("Subsets below the minimum, or columns that fail suitability, are shown as not assessed and never tested.")
              )
            ),
            div(class = "main-col",
              uiOutput("subset_note"),
              panel_box(
                h4("Per-subset first-digit results"),
                DTOutput("subset_tbl")
              ),
              plot_card("MAD by subset", plotOutput("subset_plot", height = "420px"),
                        "Dotted 0.006, dashed 0.012, solid 0.015 Nigrini thresholds."),
              boundary_note("note")
            )
          )
        ),

        ## ------------------------------------- 7 Manipulation experiment
        bslib::nav_panel(
          title = tool_title("07", "Experiment", "forge & detect", KIT$yellow),
          value = "experiment",
          div(class = "with-side",
            div(class = "side",
              div(class = "side-card",
                div(class = "note bad", tags$b("SYNTHETIC EXPERIMENT."), " No real-world records are involved."),
                numericInput("exp_n", "Base sample size", value = 2000, min = 200, max = 20000, step = 100),
                numericInput("exp_R", "Replicates per cell", value = 30, min = 5, max = 500, step = 5),
                numericInput("exp_seed", "Seed", value = 2025, min = 1, step = 1),
                checkboxGroupInput("exp_types", "Manipulation types",
                  choices = stats::setNames(names(manipulation_labels()),
                                            unname(manipulation_labels())),
                  selected = names(manipulation_labels())),
                checkboxGroupInput("exp_levels", "Alteration levels",
                  choices = c("0%" = "0", "5%" = "0.05", "10%" = "0.1",
                              "20%" = "0.2", "30%" = "0.3", "50%" = "0.5"),
                  selected = c("0", "0.05", "0.1", "0.2", "0.3", "0.5")),
                actionButton("run_exp", "Run experiment", class = "btn-primary w-100")
              )
            ),
            div(class = "main-col",
              uiOutput("exp_meta"),
              p(class = "caption",
                "The control sample is drawn from 10^U(0,6), which conforms to Benford's Law.",
                " A known fraction of records is then altered in a copy of the control.",
                " The true alteration rate is stored separately from every statistical result."),
              plot_card("Detection rate vs true alteration rate (SYNTHETIC)",
                        plotOutput("exp_curve", height = "380px")),
              panel_box(h4("Summary"), DTOutput("exp_sum")),
              panel_box(h4("ANOVA of MAD on the alteration level"), DTOutput("exp_anova")),
              panel_box(h4("Regression and correlation of MAD on the alteration rate"), DTOutput("exp_reg")),
              div(class = "note",
                "The method does not detect everything: small multiplicative changes barely move the",
                " first-digit distribution. Interpret the numbers exactly as observed.")
            )
          )
        ),

        ## ---------------------------------------------------- 8 Export
        bslib::nav_panel(
          title = tool_title("08", "Export", "tables & reports", KIT$green),
          value = "export",
          uiOutput("export_context"),
          div(class = "stat-grid",
            stat_card("CSV", "live result tables"),
            stat_card("PNG", "pipeline figures"),
            stat_card("HTML", "rendered report")
          ),
          panel_box(
            h4("Download the current results"),
            p(class = "caption", "Everything below is generated live from the dataset, column and subset currently selected."),
            div(class = "dl-grid",
              downloadButton("dl_chi", "Chi-square results"),
              downloadButton("dl_freq", "First-digit frequencies"),
              downloadButton("dl_flags", "Column flag summary"),
              downloadButton("dl_desc", "Descriptive statistics"))
          ),
          panel_box(
            h4("Extended, subset and experiment results"),
            div(class = "dl-grid",
              downloadButton("dl_two", "Extended digit results"),
              downloadButton("dl_subset", "Subset comparison"),
              downloadButton("dl_exp", "Experiment summary"),
              downloadButton("dl_an", "ANOVA results"),
              downloadButton("dl_rg", "Regression results"))
          ),
          panel_box(
            h4("Rendered reports"),
            uiOutput("report_buttons")
          ),
          panel_box(
            h4("Pipeline figures (PNG)"),
            p(class = "caption", "Click a figure to open the full-size PNG. These are the static outputs of scripts/run_all.R."),
            uiOutput("fig_links")
          ),
          boundary_note("note")
        )
      ),

      ## ---------------------------------------------------------- base
      tags$footer(class = "base",
        div(class = "mono", uiOutput("audit_line", inline = TRUE)),
        div("BMAT202L / BMAT202P \u00b7 Slot F1 \u00b7 VIT Vellore \u00b7 deviation is a review flag, not proof of fraud")
      )
    )
  )
)

## ---------------------------------------------------------------- server
server <- function(input, output, session) {

  data_state <- reactiveVal(NULL)
  load_counter <- 0L
  review_state <- reactiveVal(NULL)
  review_error <- reactiveVal(NULL)

  ## Per-selector readiness.  A selector only becomes authoritative once the
  ## client has initialised it for the CURRENT dataset.  This prevents a column
  ## that exists in both datasets (for example a USASpending code that is also
  ## present in the bundled WDI panel) from being reused after a dataset switch.
  selection_ready <- reactiveValues(
    col = FALSE, col4 = FALSE, col5 = FALSE, col6 = FALSE,
    sub_var = FALSE, sub_var4 = FALSE, sub_var5 = FALSE,
    sub_val_sel = FALSE, sub_val_sel4 = FALSE, sub_val_sel5 = FALSE,
    group_var = FALSE)
  observeEvent(data_state(), {
    for (nm in names(selection_ready)) selection_ready[[nm]] <- FALSE
    review_state(NULL)
    review_error(NULL)
  }, ignoreNULL = TRUE)
  lapply(c("col", "col4", "col5", "col6", "sub_var", "sub_var4", "sub_var5",
           "sub_val_sel", "sub_val_sel4", "sub_val_sel5", "group_var"),
         function(id) observeEvent(input[[id]], {
           selection_ready[[id]] <- TRUE
         }, ignoreInit = TRUE))

  ## Synchronize column choices across tabs when user selects a column
  syncing_col <- FALSE
  lapply(c("col", "col4", "col5", "col6"), function(id) {
    observeEvent(input[[id]], {
      if (syncing_col) return()
      val <- input[[id]]
      if (!is.null(val) && nzchar(val)) {
        syncing_col <<- TRUE
        on.exit(syncing_col <<- FALSE, add = TRUE)
        for (other in setdiff(c("col", "col4", "col5", "col6"), id)) {
          if (!identical(input[[other]], val)) {
            updateSelectInput(session, other, selected = val)
          }
        }
      }
    }, ignoreInit = TRUE)
  })

  ## Synchronize subset variable across tabs
  syncing_sub <- FALSE
  lapply(c("sub_var", "sub_var4", "sub_var5"), function(id) {
    observeEvent(input[[id]], {
      if (syncing_sub) return()
      val <- input[[id]]
      if (!is.null(val)) {
        syncing_sub <<- TRUE
        on.exit(syncing_sub <<- FALSE, add = TRUE)
        for (other in setdiff(c("sub_var", "sub_var4", "sub_var5"), id)) {
          if (!identical(input[[other]], val)) {
            updateSelectInput(session, other, selected = val)
          }
        }
      }
    }, ignoreInit = TRUE)
  })

  ## -------------------------------------------------- data loading
  load_source <- function() {
    src <- input$src
    if (identical(src, "usaspending")) {
      p_rds <- file.path(ROOT, "data", "processed", "usaspending_panel.rds")
      if (file.exists(p_rds)) {
        df <- try(readRDS(p_rds), silent = TRUE)
        if (!inherits(df, "try-error") && !is.null(df) && nrow(df) > 0) {
          return(list(df = as.data.frame(df), short = "USAspending panel",
                      label = paste0("USAspending Federal Transactions (",
                                     format(nrow(df), big.mark = ","), " rows)"),
                      synthetic = FALSE))
        }
      }
      p_csv <- file.path(ROOT, "data", "raw", "usaspending", "usaspending.csv")
      if (!file.exists(p_csv)) {
        return(list(df = NULL, short = "USAspending file missing",
                    label = paste("USAspending raw file not found at", p_csv,
                                  "- place it there or choose the bundled WDI panel."),
                    synthetic = FALSE))
      }
      df <- try(load_usaspending(file.path(ROOT, "data", "raw", "usaspending")), silent = TRUE)
      if (inherits(df, "try-error") || is.null(df) || nrow(df) == 0) {
        msg <- if (inherits(df, "try-error")) conditionMessage(attr(df, "condition")) else "no amount rows found"
        return(list(df = NULL, short = "USAspending load failed",
                    label = paste("Could not load USAspending data:", msg), synthetic = FALSE))
      }
      return(list(df = as.data.frame(df), short = "USAspending panel",
                  label = paste0("USAspending Federal Transactions (",
                                 format(nrow(df), big.mark = ","), " rows)"),
                  synthetic = FALSE))
    }

    if (identical(src, "bundled")) {
      p <- file.path(ROOT, "data", "processed", "wdi_clean.csv")
      if (!file.exists(p))
        return(list(df = NULL, short = "WDI panel missing",
                    label = paste("Bundled panel not found at", p, "- run scripts/run_all.R first."),
                    synthetic = FALSE))
      df <- try(readr::read_csv(p, show_col_types = FALSE, progress = FALSE), silent = TRUE)
      if (inherits(df, "try-error"))
        return(list(df = NULL, short = "WDI panel load failed",
                    label = paste("Could not read the bundled panel:", conditionMessage(attr(df, "condition"))),
                    synthetic = FALSE))
      return(list(df = as.data.frame(df), short = "Bundled WDI panel",
                  label = "Bundled processed WDI panel (data/processed/wdi_clean.csv)",
                  synthetic = isTRUE(unique(df$is_synthetic)[1])))
    }

    if (identical(src, "upload")) {
      if (is.null(input$file))
        return(list(df = NULL, short = "No upload selected",
                    label = "Choose a CSV file, then press Load data.", synthetic = FALSE))
      df <- try(read_any_csv(input$file$datapath), silent = TRUE)
      if (inherits(df, "try-error"))
        return(list(df = NULL, short = "Upload failed",
                    label = paste("Could not read the upload:", conditionMessage(attr(df, "condition"))),
                    synthetic = FALSE))
      return(list(df = df, short = paste0("Upload: ", input$file$name),
                  label = paste0("Uploaded file: ", input$file$name),
                  synthetic = FALSE))
    }

    list(df = synthetic_panel(), short = "Synthetic sample",
         label = "SYNTHETIC - NOT REAL DATA (generated sample)", synthetic = TRUE)
  }

  do_load <- function(notify = FALSE) {
    st <- tryCatch(load_source(),
                   error = function(e) list(df = NULL, short = "Load failed",
                                            label = paste("Failed to load data:", conditionMessage(e)),
                                            synthetic = FALSE))
    load_counter <<- load_counter + 1L
    st$id <- load_counter
    data_state(st)
    if (isTRUE(notify)) {
      if (is.null(st$df)) {
        showNotification(st$label, type = "error", duration = 9)
      } else {
        showNotification(paste0("Active dataset: ", st$short, " \u00b7 ",
                                format(nrow(st$df), big.mark = ","), " rows"),
                         type = "message", duration = 3)
      }
    }
    invisible(st)
  }

  observeEvent(input$src, do_load(FALSE), ignoreInit = FALSE)
  observeEvent(input$load, do_load(TRUE))
  observeEvent(input$file, {
    if (identical(input$src, "upload") && !is.null(input$file)) do_load(FALSE)
  }, ignoreNULL = TRUE)

  ## -------------------------------------------------- schema helpers
  is_long_panel <- function(df) !is.null(df) && all(c("indicator_code", "value") %in% names(df))

  long_groups <- function(df) {
    code <- as.character(df$indicator_code)
    lab <- if ("indicator_label" %in% names(df)) as.character(df$indicator_label) else code
    role <- if ("indicator_role" %in% names(df)) as.character(df$indicator_role) else NA_character_
    g <- data.frame(indicator_code = code,
                    indicator_label = ifelse(is.na(lab) | !nzchar(lab), code, lab),
                    indicator_role = role, stringsAsFactors = FALSE)
    g <- g[!is.na(g$indicator_code) & nzchar(g$indicator_code), , drop = FALSE]
    g[!duplicated(g$indicator_code), , drop = FALSE]
  }

  col_choices <- function(df) {
    if (is.null(df) || !ncol(df)) return(character(0))
    if (is_long_panel(df)) {
      g <- long_groups(df)
      if (!nrow(g)) return(character(0))
      return(stats::setNames(g$indicator_code,
                             paste0(g$indicator_code, " \u2014 ",
                                    substr(g$indicator_label, 1, 46))))
    }
    num <- names(df)[vapply(df, is.numeric, logical(1))]
    if (!length(num)) return(character(0))
    keep <- !grepl("(^|_)(id|code|zip|postal|phone|year|date|index|rank|serial)(_|$)",
                   tolower(num))
    keep <- keep & vapply(df[num], function(z) any(is.finite(z)), logical(1))
    stats::setNames(num[keep], num[keep])
  }

  col_label <- function(df, col) {
    if (is.null(col)) return("")
    ch <- col_choices(df)
    if (col %in% unname(ch)) names(ch)[match(col, unname(ch))] else col
  }

  subset_choices <- function(df) {
    if (is.null(df)) return(c("Whole dataset (no subset)" = "none"))
    cand <- intersect(c("year", "region", "income_group", "indicator_role"), names(df))
    c("Whole dataset (no subset)" = "none", stats::setNames(cand, cand))
  }

  group_choices <- function(df) {
    if (is.null(df)) return(character(0))
    cand <- intersect(c("year", "region", "income_group", "indicator_code", "country_code"),
                      names(df))
    stats::setNames(cand, cand)
  }

  values_for <- function(df, col, subset_var = "none", subset_val = NULL) {
    if (is.null(df) || is.null(col) || !length(col) || !nzchar(col)) return(numeric(0))
    if (is_long_panel(df)) {
      d <- df[!is.na(df$indicator_code) & as.character(df$indicator_code) == col, , drop = FALSE]
      if (!identical(subset_var, "none") && !is.null(subset_val) && nzchar(subset_val) &&
          subset_var %in% names(d))
        d <- d[as.character(d[[subset_var]]) == subset_val, , drop = FALSE]
      return(suppressWarnings(as.numeric(d$value)))
    }
    if (!col %in% names(df)) return(numeric(0))
    d <- df
    if (!identical(subset_var, "none") && !is.null(subset_val) && nzchar(subset_val) &&
        subset_var %in% names(d))
      d <- d[as.character(d[[subset_var]]) == subset_val, , drop = FALSE]
    suppressWarnings(as.numeric(d[[col]]))
  }

  current_col <- function(id, df = NULL) {
    if (is.null(df)) {
      st <- data_state()
      df <- if (is.null(st)) NULL else st$df
    }
    ch <- col_choices(df)
    if (!length(ch)) return(NULL)
    if (!isTRUE(selection_ready[[id]])) return(unname(ch[[1]]))
    v <- input[[id]]
    if (is.null(v) || length(v) != 1L || is.na(v) || !nzchar(v) || !v %in% unname(ch))
      return(unname(ch[[1]]))
    v
  }

  current_subset <- function(var_id, val_id, df) {
    if (is.null(df)) return(list(var = "none", val = NULL))
    if (!isTRUE(selection_ready[[var_id]])) return(list(var = "none", val = NULL))
    sv <- input[[var_id]]
    if (is.null(sv) || length(sv) != 1L || is.na(sv) || identical(sv, "none") ||
        !sv %in% names(df))
      return(list(var = "none", val = NULL))
    vals <- sort(unique(as.character(df[[sv]])))
    vals <- vals[!is.na(vals) & nzchar(vals)]
    if (!length(vals)) return(list(var = "none", val = NULL))
    val <- input[[val_id]]
    if (is.null(val) || length(val) != 1L || is.na(val) || !nzchar(as.character(val)) ||
        !as.character(val) %in% vals)
      val <- vals[[1]]
    list(var = sv, val = as.character(val))
  }

  subset_desc <- function(var_id, val_id, df) {
    ss <- current_subset(var_id, val_id, df)
    if (identical(ss$var, "none")) "whole dataset"
    else paste0(ss$var, " = ", ss$val)
  }

  alpha_val <- reactive({
    a <- input$alpha
    if (is.null(a) || length(a) != 1L || !is.finite(a)) 0.05 else a
  })

  min_n_val <- reactive({
    m <- input$min_n
    if (is.null(m) || length(m) != 1L || !is.finite(m)) 110L else max(10L, as.integer(m))
  })

  ## Server-rendered selectors: the full option list is rebuilt with the active
  ## dataset, so it can never be lost by an update sent before the client has
  ## initialised the control.
  make_col_select <- function(id, df) {
    ch <- col_choices(df)
    selectInput(id, "Column to analyse", choices = ch,
                selected = if (length(ch)) unname(ch[[1]]) else "",
                selectize = FALSE)
  }
  make_sub_select <- function(id, df) {
    selectInput(id, "Subset by", choices = subset_choices(df), selected = "none",
                selectize = FALSE)
  }
  output$col_ui <- renderUI({
    st <- data_state(); make_col_select("col", if (is.null(st)) NULL else st$df)
  })
  output$col_ui4 <- renderUI({
    st <- data_state(); make_col_select("col4", if (is.null(st)) NULL else st$df)
  })
  output$col_ui5 <- renderUI({
    st <- data_state(); make_col_select("col5", if (is.null(st)) NULL else st$df)
  })
  output$col_ui6 <- renderUI({
    st <- data_state(); make_col_select("col6", if (is.null(st)) NULL else st$df)
  })
  output$sub_ui <- renderUI({
    st <- data_state(); make_sub_select("sub_var", if (is.null(st)) NULL else st$df)
  })
  output$sub_ui4 <- renderUI({
    st <- data_state(); make_sub_select("sub_var4", if (is.null(st)) NULL else st$df)
  })
  output$sub_ui5 <- renderUI({
    st <- data_state(); make_sub_select("sub_var5", if (is.null(st)) NULL else st$df)
  })
  output$group_ui <- renderUI({
    st <- data_state()
    gc <- group_choices(if (is.null(st)) NULL else st$df)
    selectInput("group_var", "Group by", choices = gc,
                selected = if (length(gc)) unname(gc[[1]]) else "",
                selectize = FALSE)
  })

  make_sub_val <- function(var_id, val_id, out_id) {
    output[[out_id]] <- renderUI({
      st <- data_state()
      if (is.null(st) || is.null(st$df)) return(NULL)
      v <- input[[var_id]]
      if (is.null(v) || identical(v, "none") || !v %in% names(st$df)) return(NULL)
      vals <- sort(unique(as.character(st$df[[v]])))
      vals <- vals[!is.na(vals) & nzchar(vals)]
      if (!length(vals)) return(helpText("No values available for this column."))
      selectInput(val_id, "Value", choices = vals, selected = vals[[1]],
                  selectize = FALSE)
    })
  }
  make_sub_val("sub_var", "sub_val_sel", "sub_val")
  make_sub_val("sub_var4", "sub_val_sel4", "sub_val4")
  make_sub_val("sub_var5", "sub_val_sel5", "sub_val5")

  ## -------------------------------------------------- header / status
  output$active_source <- renderUI({
    st <- data_state()
    if (is.null(st)) {
      return(div(class = "source-chip", tags$b("Active dataset"), "loading the case \u2026"))
    }
    txt <- if (is.null(st$df)) st$short
           else paste0(st$short, " \u00b7 ", format(nrow(st$df), big.mark = ","), " rows")
    div(class = "source-chip", tags$b("Active dataset"), txt)
  })

  output$audit_line <- renderUI({
    st <- data_state()
    if (is.null(st)) return("notebook: nothing loaded yet")
    if (is.null(st$df)) return(paste0("notebook: ", st$short, " \u2014 ", st$label))
    r <- tryCatch(result4(), error = function(e) NULL)
    if (is.null(r)) {
      return(paste0("notebook: ", st$short, " \u00b7 ", format(nrow(st$df), big.mark = ","),
                    " rows \u00b7 select a column to measure"))
    }
    paste0("notebook: ", st$short, " \u00b7 ", current_col("col4", st$df),
           " \u00b7 N=", fmt_int(r$N), " \u00b7 X\u00b2=", fmt_x2(r$x2),
           " \u00b7 p=", fmt_p(r$p), " \u00b7 MAD=", fmt_mad(r$mad))
  })

  output$src_info <- renderUI({
    st <- data_state()
    if (is.null(st)) return(helpText("Loading \u2026"))
    if (is.null(st$df)) return(div(class = "note bad", st$label))
    tagList(
      div(class = "fact", span("Source"), tags$b(st$short)),
      div(class = "fact", span("Rows"), tags$b(format(nrow(st$df), big.mark = ","))),
      div(class = "fact", span("Columns"), tags$b(ncol(st$df))),
      div(class = "fact", span("Status"), tags$b(if (isTRUE(st$synthetic)) "SYNTHETIC" else "Real data")),
      p(class = "caption", st$label)
    )
  })

  output$synth_banner <- renderUI({
    st <- data_state()
    if (is.null(st)) return(NULL)
    if (is.null(st$df)) return(div(class = "note bad", tags$b("No dataset active. "), st$label))
    if (isTRUE(st$synthetic))
      div(class = "note bad", tags$b("SYNTHETIC - NOT REAL DATA."),
          " Results below are from generated data and are not real-world findings.")
    else
      div(class = "note ok", tags$b("Active data: "), st$label)
  })

  output$preview <- renderDT({
    st <- data_state()
    validate(need(!is.null(st) && !is.null(st$df),
                  "Choose a data source and press Load data."))
    df <- utils::head(st$df, 200)
    datatable(df, class = "compact stripe hover row-border",
              options = list(pageLength = 6, scrollX = TRUE, autoWidth = FALSE,
                             lengthMenu = c(5, 10, 25), dom = "tip"),
              rownames = FALSE)
  })

  output$clean_summary <- renderTable({
    v <- vals3()
    cl <- clean_numeric(v)
    data.frame(Check = gsub("_", " ", cl$counts$category),
               Count = vapply(cl$counts$n, fmt_int, character(1)),
               stringsAsFactors = FALSE)
  }, striped = TRUE, bordered = FALSE, hover = TRUE, spacing = "s")

  ## -------------------------------------------------- tab 3: column
  vals3 <- reactive({
    st <- data_state()
    validate(need(!is.null(st) && !is.null(st$df), "Load a dataset on the Data tab first."))
    col <- current_col("col", st$df)
    validate(need(!is.null(col), "No suitable numeric column is available in this dataset."))
    ss <- current_subset("sub_var", "sub_val_sel", st$df)
    values_for(st$df, col, ss$var, ss$val)
  })

  suit3 <- reactive({
    v <- vals3()
    validate(need(length(v) > 0, "The active column/subset has no eligible numeric values."))
    suitability(v, name = current_col("col"))
  })

  output$col_heading <- renderUI({
    st <- data_state()
    if (is.null(st) || is.null(st$df))
      return(div(class = "section-head", h3("Column & suitability"),
                 span(class = "mono", "no dataset loaded")))
    col <- current_col("col", st$df)
    if (is.null(col))
      return(div(class = "section-head", h3("Column & suitability"),
                 span(class = "mono", "no numeric column")))
    ss <- current_subset("sub_var", "sub_val_sel", st$df)
    div(class = "section-head",
        h3(col_label(st$df, col)),
        span(class = "mono", paste0("code: ", col)),
        if (!identical(ss$var, "none"))
          span(class = "mono", paste0("subset: ", ss$var, " = ", ss$val)))
  })

  output$suit_cards <- renderUI({
    s <- suit3()
    tone <- switch(s$verdict, "Suitable" = "ok", "Use with caution" = "warn", "Unsuitable" = "bad", "")
    div(class = "stat-grid",
      stat_card(s$verdict, "suitability verdict", tone),
      stat_card(fmt_int(s$n_eligible), "eligible values", ""),
      stat_card(paste0(s$score, "/", s$max_score), "screening score", ""),
      stat_card(if (is.finite(s$range_orders)) sprintf("%.2f", s$range_orders) else "\u2014",
                "orders of magnitude", ""))
  })

  output$suit_tbl <- renderTable({
    s <- suit3()
    data.frame(indicator = current_col("col"),
               n_eligible = s$n_eligible,
               range_orders = round(s$range_orders, 2),
               score = paste0(s$score, "/", s$max_score),
               verdict = s$verdict,
               hard_failures = if (length(s$hard_failures)) paste(s$hard_failures, collapse = "; ") else "none")
  }, striped = TRUE, bordered = FALSE, hover = TRUE)

  output$suit_reasons <- renderUI({
    s <- suit3()
    tagList(
      if (length(s$hard_failures))
        div(class = "note bad", tags$b("Hard failures: "), paste(s$hard_failures, collapse = "; ")),
      tags$ul(class = "reason-list", lapply(s$reasons, tags$li)))
  })

  output$desc_tbl <- renderTable({
    v <- vals3()
    d <- describe_numeric(v)
    data.frame(N = d$n, missing = d$missing,
               min = signif(d$min, 6), q1 = signif(d$q1, 6),
               median = signif(d$median, 6), mean = signif(d$mean, 6),
               q3 = signif(d$q3, 6), max = signif(d$max, 6),
               sd = signif(d$sd, 5), skewness = signif(d$skewness, 3),
               range_orders = round(d$range_orders, 2),
               pct_unique = round(d$pct_unique, 3))
  }, striped = TRUE, bordered = FALSE, hover = TRUE)

  output$hist <- renderPlot({
    v <- vals3()
    validate(need(sum(is.finite(v)) >= 2, "Not enough finite values for a histogram."))
    ggplot(data.frame(x = v[is.finite(v)]), aes(x = x)) +
      geom_histogram(bins = 40, fill = KIT$blue, colour = KIT$ink, linewidth = 0.25) +
      labs(title = "Value distribution", x = "value", y = "count") +
      theme_kit()
  })

  output$loghist <- renderPlot({
    v <- vals3()
    v <- v[is.finite(v) & v > 0]
    validate(need(length(v) >= 2, "No positive values for a log10 histogram."))
    ggplot(data.frame(x = log10(v)), aes(x = x)) +
      geom_histogram(bins = 40, fill = KIT$green, colour = KIT$ink, linewidth = 0.25) +
      labs(title = "Log10 distribution", x = "log10(value)", y = "count") +
      theme_kit()
  })

  ## -------------------------------------------------- tab 4: first digit
  vals4 <- reactive({
    st <- data_state()
    validate(need(!is.null(st) && !is.null(st$df), "Load a dataset on the Data tab first."))
    col <- current_col("col4", st$df)
    validate(need(!is.null(col), "No suitable numeric column is available in this dataset."))
    ss <- current_subset("sub_var4", "sub_val_sel4", st$df)
    values_for(st$df, col, ss$var, ss$val)
  })

  result4 <- reactive({
    v <- vals4()
    validate(need(length(v) > 0, "No eligible numeric values for the active column/subset."))
    tryCatch(benford_test_values(v, "first", alpha = alpha_val()),
             error = function(e) NULL)
  })

  suit4 <- reactive({
    v <- vals4()
    if (!length(v)) return(NULL)
    suitability(v, name = current_col("col4"))
  })

  output$tier_box <- renderUI({
    r <- result4()
    if (is.null(r)) return(div(class = "note bad", "No test result available."))
    cls <- switch(r$tier, Reliable = "note ok", Caution = "note warn", "note bad")
    div(class = cls, tags$b(paste("Validity:", r$tier)), tags$br(), tags$small(r$note))
  })

  output$hero4 <- renderUI({
    r <- result4()
    s <- suit4()
    st <- data_state()
    stamp <- if (is.na(r$p)) {
      div(class = "stamp muted", "Test not run")
    } else if (r$p < r$alpha) {
      div(class = "stamp", "Review flag: differs from Benford")
    } else {
      div(class = "stamp ok", "No significant deviation")
    }
    div(class = "hero-wrap",
      div(class = "stat-grid",
        stat_card(fmt_int(r$N), "eligible values"),
        stat_card(fmt_x2(r$x2), paste0("X\u00b2 (df ", r$df, ")")),
        stat_card(fmt_p(r$p), paste0("p-value (\u03b1 = ", r$alpha, ")")),
        stat_card(fmt_mad(r$mad), paste0("MAD \u00b7 ", if (is.na(r$band)) "first digit" else r$band)),
        stat_card(r$tier, "validity tier",
                  switch(r$tier, Reliable = "ok", Caution = "warn", "bad")),
        stat_card(if (is.na(r$cohen_w)) "\u2014" else sprintf("%.4f", r$cohen_w), "Cohen's w")),
      div(class = "hero-side",
        stamp,
        p(class = "caption", "Flag \u2260 fraud. This is a column-level screening result."),
        if (!is.null(s) && identical(s$verdict, "Unsuitable"))
          div(class = "note bad", style = "text-align:left;",
              tags$b("Suitability warning. "),
              "This column failed the suitability screening; treat the p-value as descriptive only."),
        p(class = "caption",
          "Subset: ", subset_desc("sub_var4", "sub_val_sel4", st$df))
      )
    )
  })

  output$chi_tbl <- renderTable({
    r <- result4()
    data.frame(indicator = current_col("col4"),
               subset = subset_desc("sub_var4", "sub_val_sel4", data_state()$df),
               N = r$N,
               X2 = ifelse(is.na(r$x2), NA, round(r$x2, 4)),
               df = r$df,
               p_value = ifelse(is.na(r$p), NA, signif(r$p, 4)),
               alpha = r$alpha,
               min_expected_count = round(r$min_E, 2),
               pct_cells_E_lt_5 = paste0(round(100 * r$pct_cells_E_lt5, 1), "%"),
               validity_tier = r$tier,
               MAD = round(r$mad, 4),
               Nigrini_band = ifelse(is.na(r$band), "-", r$band),
               Cohens_w = round(r$cohen_w, 4))
  }, striped = TRUE, bordered = FALSE, hover = TRUE)

  output$decision <- renderUI({
    r <- result4()
    tagList(
      tags$p(tags$b("H0:"), " the observed first-digit distribution is consistent with the Benford distribution."),
      tags$p(tags$b("H1:"), " it differs significantly."),
      div(class = "note", tags$b("Decision: "), r$decision),
      tags$p(tags$small(r$note)),
      tags$p(class = "caption", BOUNDARY))
  })

  output$bar <- renderPlot({
    r <- result4()
    f <- r$frequency
    df <- rbind(
      data.frame(digit = f$digit, value = f$proportion, kind = "Observed"),
      data.frame(digit = f$digit, value = as.numeric(r$expected_prop), kind = "Benford expected"))
    df$digit <- factor(df$digit, levels = f$digit)
    ggplot(df, aes(x = digit, y = value, fill = kind)) +
      geom_col(position = position_dodge(width = 0.82), width = 0.72,
               colour = KIT$ink, linewidth = 0.3) +
      scale_fill_manual("", values = c(Observed = KIT$blue, "Benford expected" = KIT$orange)) +
      scale_y_continuous(labels = function(x) sprintf("%.0f%%", 100 * x),
                         expand = expansion(mult = c(0, 0.06))) +
      labs(title = "Observed vs expected first-digit proportions",
           x = "first digit", y = "proportion") +
      theme_kit()
  })

  output$freq_tbl <- renderDT({
    r <- result4()
    f <- r$frequency
    df <- data.frame(
      digit = f$digit,
      observed = f$count,
      observed_prop = round(f$proportion, 5),
      expected_prop = round(as.numeric(r$expected_prop), 5),
      expected_count = round(as.numeric(r$E), 2),
      difference = round(f$proportion - as.numeric(r$expected_prop), 5),
      pearson_residual = round(as.numeric(r$residuals), 3),
      notable = ifelse(abs(r$residuals) > 1.96, "yes", "no"))
    datatable(df, class = "compact stripe hover row-border",
              colnames = c("Digit", "Observed", "Observed prop.", "Expected prop.",
                           "Expected count", "Difference", "Std. residual", "|r| > 1.96"),
              options = list(dom = "t", pageLength = 9, scrollX = TRUE, autoWidth = FALSE),
              rownames = FALSE)
  })

  output$resid <- renderPlot({
    r <- result4()
    f <- r$frequency
    d <- data.frame(digit = factor(f$digit, levels = f$digit),
                    r = as.numeric(r$residuals),
                    notable = abs(as.numeric(r$residuals)) > 1.96)
    ggplot(d, aes(x = digit, y = r, fill = notable)) +
      geom_col(colour = KIT$ink, linewidth = 0.3, width = 0.7) +
      geom_hline(yintercept = c(-1.96, 1.96), linetype = "dashed", colour = KIT$red) +
      geom_hline(yintercept = 0, colour = KIT$ink, linewidth = 0.4) +
      scale_fill_manual("", values = c("FALSE" = KIT$blue, "TRUE" = KIT$red),
                        labels = c("within \u00b11.96", "beyond \u00b11.96")) +
      labs(title = "Standardised residuals by digit", x = "first digit",
           y = "(O \u2212 E) / \u221aE") +
      theme_kit()
  })

  output$mad_tbl <- renderTable({
    r <- result4()
    out <- data.frame(MAD = round(r$mad, 4),
                      Nigrini_band = ifelse(is.na(r$band), "- (first digit only)", r$band),
                      Cohens_w = round(r$cohen_w, 4),
                      min_N_for_reliable = r$min_n_reliable,
                      min_N_for_E_ge_1 = r$min_n_all_ge1)
    if (isTRUE(input$boot)) {
      ci <- tryCatch(bootstrap_mad_ci(vals4(), "first", B = 300, seed = 2025),
                     error = function(e) c(lower = NA_real_, upper = NA_real_))
      out$MAD_CI_lower <- round(ci[["lower"]], 4)
      out$MAD_CI_upper <- round(ci[["upper"]], 4)
    }
    out
  }, striped = TRUE, bordered = FALSE, hover = TRUE)

  ## ------------------------------------- row-level review candidates
  observeEvent(input$run_review, {
    review_error(NULL)
    review_state(NULL)
    if (!identical(input$src, "usaspending")) {
      review_error("The row-level screen uses the raw USAspending transaction export. Select that source first.")
      return()
    }
    withProgress(message = "Screening USAspending transactions \u2026", value = 0.05, {
      res <- tryCatch({
        tx <- load_usaspending_transactions(ROOT)
        setProgress(0.45, detail = "Applying row-level review rules")
        sc <- screen_usaspending_transactions(tx)
        setProgress(0.95, detail = "Summarising")
        list(screened = sc, summary = review_summary(sc),
             meta = attr(sc, "screening"),
             built = format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
      }, error = function(e) {
        review_error(conditionMessage(e))
        showNotification(paste("Transaction screening failed:", conditionMessage(e)),
                         type = "error", duration = 9)
        NULL
      })
      if (!is.null(res)) review_state(res)
    })
  })

  output$review_status <- renderUI({
    if (!is.null(review_error()))
      return(div(class = "note bad", tags$b("Screening error. "), review_error()))
    st <- review_state()
    if (is.null(st))
      return(div(class = "note",
                 tags$b("No transaction screen has been run."),
                 " Press Screen transactions. This is independent of the column-level Benford result above."))
    s <- st$summary
    m <- st$meta
    tagList(
      div(class = "stat-grid",
        stat_card(fmt_int(s$rows_scanned), "transactions scanned"),
        stat_card(fmt_int(s$review_candidates), "review candidates", if (s$review_candidates > 0) "warn" else "ok"),
        stat_card(fmt_int(s$high_severity), "high severity", if (s$high_severity > 0) "bad" else "ok"),
        stat_card(fmt_int(s$medium_severity), "medium severity"),
        stat_card(fmt_int(s$duplicate_keys), "duplicate keys"),
        stat_card(fmt_int(s$negative_amount), "negative amounts")),
      div(class = "note",
          tags$b("Method. "), m$note,
          sprintf(" Peer groups: %s; minimum group size: %s; one-sided |z| threshold: %s.",
                  fmt_int(m$peer_groups), fmt_int(m$min_group), m$z_review),
          tags$br(),
          "A review candidate is a reason to inspect the row. It is not proof of fraud, and the Benford population test is not used to condemn any row."),
      p(class = "caption", "Screen built ", st$built, ". Showing up to 200 candidates in the table; the CSV contains all candidates.")
    )
  })

  output$review_tbl <- renderDT({
    st <- review_state()
    validate(need(!is.null(st), "Press Screen transactions to build the row-level review queue."))
    d <- st$screened[st$screened$review_candidate, , drop = FALSE]
    if (!nrow(d))
      return(datatable(data.frame(note = "No row-level review candidates were triggered by the current rules."),
                       rownames = FALSE, options = list(dom = "t")))
    d$severity <- factor(d$severity, levels = c("High", "Medium", "Low"))
    d <- d[order(d$severity, -d$score, na.last = TRUE), , drop = FALSE]
    d <- utils::head(d, 200)
    out <- data.frame(
      transaction = d$transaction_key,
      date = as.character(d$action_date),
      agency = d$agency,
      naics = d$naics,
      recipient = d$recipient,
      amount = ifelse(is.na(d$amount), NA, round(d$amount, 2)),
      severity = as.character(d$severity),
      robust_z = round(d$score, 2),
      reasons = d$reasons,
      stringsAsFactors = FALSE)
    datatable(out, class = "compact stripe hover row-border",
              colnames = c("Transaction", "Date", "Agency", "NAICS", "Recipient",
                           "Amount", "Severity", "Robust z", "Why this row is here"),
              options = list(pageLength = 10, scrollX = TRUE, autoWidth = FALSE,
                             order = list(list(7, "desc"))),
              rownames = FALSE)
  })

  output$dl_review <- downloadHandler(
    filename = function() "usaspending_review_candidates.csv",
    content = function(f) {
      st <- review_state()
      if (is.null(st)) {
        utils::write.csv(data.frame(note = "Run the transaction screen first."), f, row.names = FALSE)
        return(invisible(NULL))
      }
      d <- st$screened[st$screened$review_candidate, , drop = FALSE]
      if (!nrow(d)) d <- data.frame(note = "No row-level review candidates were triggered.")
      utils::write.csv(d, f, row.names = FALSE)
    })

  ## -------------------------------------------------- tab 5: extended
  vals5 <- reactive({
    st <- data_state()
    validate(need(!is.null(st) && !is.null(st$df), "Load a dataset on the Data tab first."))
    col <- current_col("col5", st$df)
    validate(need(!is.null(col), "No suitable numeric column is available in this dataset."))
    ss <- current_subset("sub_var5", "sub_val_sel5", st$df)
    values_for(st$df, col, ss$var, ss$val)
  })

  result5 <- reactive({
    v <- vals5()
    validate(need(length(v) > 0, "No eligible numeric values for the active column/subset."))
    list(f2 = tryCatch(benford_test_values(v, "first2", alpha = alpha_val()),
                       error = function(e) NULL),
         sd2 = tryCatch(benford_test_values(v, "second", alpha = alpha_val()),
                        error = function(e) NULL))
  })

  output$ext_hint <- renderUI({
    r <- result5()
    n <- if (!is.null(r$f2)) r$f2$N else 0
    div(class = "note",
        tags$b("Sample size check. "),
        sprintf("N = %s eligible values. The first-two-digit test needs at least %s values for every expected count to reach 5; the second-digit test needs %s. Below those thresholds the test is reported as NOT RUN.",
                fmt_int(n),
                if (!is.null(r$f2)) fmt_int(r$f2$min_n_reliable) else "\u2014",
                if (!is.null(r$sd2)) fmt_int(r$sd2$min_n_reliable) else "\u2014"))
  })

  output$two_tbl <- renderTable({
    r <- result5()
    mk <- function(x, lbl) {
      if (is.null(x)) return(NULL)
      data.frame(indicator = current_col("col5"), test = lbl, N = x$N, df = x$df,
                 X2 = ifelse(is.na(x$x2), NA, round(x$x2, 3)),
                 p_value = ifelse(is.na(x$p), NA, signif(x$p, 4)),
                 validity = x$tier,
                 min_expected = round(x$min_E, 3),
                 min_N_for_reliable = x$min_n_reliable,
                 MAD = round(x$mad, 5), note = x$note)
    }
    out <- rbind(mk(r$f2, "First two digits"), mk(r$sd2, "Second digit"))
    validate(need(!is.null(out) && nrow(out) > 0, "No extended-digit result available."))
    out
  }, striped = TRUE, bordered = FALSE, hover = TRUE)

  output$second_bar <- renderPlot({
    r <- result5()
    x <- r$sd2
    validate(need(!is.null(x) && sum(x$frequency$count) > 0, "No second-digit observations."))
    f <- x$frequency
    df <- rbind(
      data.frame(digit = f$digit, value = f$proportion, kind = "Observed"),
      data.frame(digit = f$digit, value = as.numeric(x$expected_prop), kind = "Benford expected"))
    df$digit <- factor(df$digit, levels = f$digit)
    ggplot(df, aes(x = digit, y = value, fill = kind)) +
      geom_col(position = position_dodge(width = 0.82), width = 0.72,
               colour = KIT$ink, linewidth = 0.3) +
      scale_fill_manual("", values = c(Observed = KIT$pink, "Benford expected" = KIT$orange)) +
      scale_y_continuous(labels = function(x) sprintf("%.0f%%", 100 * x),
                         expand = expansion(mult = c(0, 0.06))) +
      labs(title = "Second significant digit", x = "second digit", y = "proportion") +
      theme_kit()
  })

  output$two_freq <- renderDT({
    r <- result5()
    x <- r$f2
    validate(need(!is.null(x) && sum(x$frequency$count) > 0,
                  "No first-two-digit observations for this sample."))
    f <- x$frequency
    df <- data.frame(digit_pair = f$digit, observed = f$count,
                     observed_prop = round(f$proportion, 5),
                     expected_prop = round(as.numeric(x$expected_prop), 5),
                     expected_count = round(as.numeric(x$E), 4))
    datatable(df, class = "compact stripe hover row-border",
              options = list(pageLength = 10, scrollX = TRUE, autoWidth = FALSE),
              rownames = FALSE)
  })

  ## -------------------------------------------------- tab 6: subsets
  subset_results <- reactive({
    st <- data_state()
    validate(need(!is.null(st) && !is.null(st$df), "Load a dataset on the Data tab first."))
    df <- st$df
    col <- current_col("col6", df)
    validate(need(!is.null(col), "No suitable numeric column is available."))
    gv_name <- input$group_var
    gc <- group_choices(df)
    if (!isTRUE(selection_ready$group_var) || is.null(gv_name) ||
        length(gv_name) != 1L || is.na(gv_name) || !nzchar(gv_name) ||
        !gv_name %in% names(df))
      gv_name <- if (length(gc)) unname(gc[[1]]) else NULL
    validate(need(!is.null(gv_name) && length(gv_name) == 1L && nzchar(gv_name) &&
                    gv_name %in% names(df), "Choose a grouping column."))
    gv <- as.character(df[[gv_name]])
    keys <- sort(unique(gv[!is.na(gv) & nzchar(gv)]))
    validate(need(length(keys) > 0, "The grouping column has no usable values."))
    n_keys <- length(keys)
    if (length(keys) > 60) keys <- keys[seq_len(60)]
    rows <- lapply(keys, function(k) {
      v <- values_for(df, col, gv_name, k)
      cl <- clean_numeric(v)
      base <- data.frame(group = k, N = cl$n_eligible, X2 = NA_real_, df = 8,
                         p_raw = NA_real_, p_holm = NA_real_, p_bh = NA_real_,
                         MAD = NA_real_, tier = "Not run", suitability = NA_character_,
                         flag = "Not assessed - insufficient sample",
                         stringsAsFactors = FALSE)
      if (cl$n_eligible < min_n_val()) return(base)
      s <- suitability(v, name = col)
      base$suitability <- s$verdict
      if (identical(s$verdict, "Unsuitable")) {
        base$flag <- "Not assessed - unsuitable data"
        return(base)
      }
      r <- tryCatch(benford_test_values(cl$eligible, "first", alpha = alpha_val()),
                    error = function(e) NULL)
      if (is.null(r)) return(base)
      data.frame(group = k, N = r$N, X2 = r$x2, df = r$df, p_raw = r$p,
                 p_holm = NA_real_, p_bh = NA_real_, MAD = r$mad,
                 tier = r$tier, suitability = s$verdict, flag = "",
                 stringsAsFactors = FALSE)
    })
    out <- do.call(rbind, rows)
    validate(need(!is.null(out) && nrow(out) > 0, "No subsets could be built."))
    adj <- adjust_family(out$p_raw, paste0("subset comparison by ", gv_name))
    out$p_holm <- adj$p_holm
    out$p_bh <- adj$p_bh
    out$flag <- vapply(seq_len(nrow(out)), function(i) {
      if (identical(out$flag[i], "Not assessed - unsuitable data"))
        return("Not assessed - unsuitable data")
      if (is.na(out$p_bh[i])) return("Not assessed - insufficient sample")
      flag_anomaly(TRUE, out$N[i], out$p_bh[i], out$MAD[i], alpha_val())$flag
    }, character(1))
    attr(out, "n_keys") <- n_keys
    out
  })

  output$subset_note <- renderUI({
    out <- subset_results()
    tested <- sum(!is.na(out$p_bh))
    n_keys <- attr(out, "n_keys")
    if (is.null(n_keys)) n_keys <- nrow(out)
    div(class = "note",
        tags$b("Comparison family. "),
        sprintf("%d groups shown of %d; %d had a valid chi-square test. p-values are Holm- and BH-adjusted within this comparison family. Groups below the minimum N, or columns that fail suitability, are never tested.",
                nrow(out), n_keys, tested))
  })

  output$subset_tbl <- renderDT({
    out <- subset_results()
    df <- data.frame(
      group = out$group,
      N = out$N,
      X2 = ifelse(is.na(out$X2), NA, round(out$X2, 3)),
      p_raw = ifelse(is.na(out$p_raw), NA, signif(out$p_raw, 4)),
      p_holm = ifelse(is.na(out$p_holm), NA, signif(out$p_holm, 4)),
      p_bh = ifelse(is.na(out$p_bh), NA, signif(out$p_bh, 4)),
      MAD = round(out$MAD, 4),
      tier = out$tier,
      suitability = out$suitability,
      flag = out$flag)
    datatable(df, class = "compact stripe hover row-border",
              colnames = c("Group", "N", "X2", "p raw", "p Holm", "p BH", "MAD",
                           "Validity", "Suitability", "Flag"),
              options = list(pageLength = 12, scrollX = TRUE, autoWidth = FALSE),
              rownames = FALSE)
  })

  output$subset_plot <- renderPlot({
    out <- subset_results()
    out <- out[is.finite(out$MAD), , drop = FALSE]
    validate(need(nrow(out) > 0, "No finite MAD values to plot."))
    out$group <- factor(out$group, levels = out$group)
    ggplot(out, aes(x = group, y = MAD, fill = flag)) +
      geom_col(colour = KIT$ink, linewidth = 0.3, width = 0.72) +
      geom_hline(yintercept = c(0.006, 0.012, 0.015),
                 linetype = c("dotted", "dashed", "solid"), colour = KIT$ink) +
      scale_fill_manual("", values = SUB_FLAG_COLORS, drop = TRUE) +
      labs(title = "MAD by subset",
           subtitle = "Dotted 0.006 \u00b7 dashed 0.012 \u00b7 solid 0.015",
           x = NULL, y = "first-digit MAD") +
      theme_kit() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })

  ## -------------------------------------------------- tab 7: experiment
  exp_state <- reactiveVal(NULL)

  observeEvent(input$run_exp, {
    if (!length(input$exp_types) || !length(input$exp_levels)) {
      showNotification("Select at least one manipulation type and one alteration level.",
                       type = "error", duration = 6)
      return()
    }
    ## Accept either the internal keys or the human-readable labels (older
    ## sessions may still send labels if the checkbox choices were rebuilt).
    type_keys <- names(manipulation_labels())
    type_labels <- unname(manipulation_labels())
    chosen_types <- as.character(input$exp_types)
    if (all(chosen_types %in% type_labels))
      chosen_types <- type_keys[match(chosen_types, type_labels)]
    chosen_types <- intersect(chosen_types, type_keys)
    if (!length(chosen_types)) {
      showNotification("No valid manipulation type was selected.", type = "error", duration = 6)
      return()
    }
    exp_state(NULL)
    a <- alpha_val()
    withProgress(message = "Running the synthetic experiment \u2026", value = 0, {
      e <- try(run_experiment(n = input$exp_n, R = input$exp_R,
                              levels = as.numeric(input$exp_levels),
                              types = chosen_types, seed = input$exp_seed,
                              alpha = a,
                              progress = function(i, total) setProgress(i / total)),
               silent = TRUE)
      if (inherits(e, "try-error")) {
        showNotification(paste("Experiment failed:", conditionMessage(attr(e, "condition"))),
                         type = "error", duration = 9)
        exp_state(NULL)
      } else {
        e$anova <- experiment_anova(e$replicates, alpha = a)
        e$reg <- experiment_regression(e$replicates)
        e$settings <- list(n = input$exp_n, R = input$exp_R,
                           levels = as.numeric(input$exp_levels),
                           types = chosen_types, seed = input$exp_seed)
        exp_state(e)
      }
    })
  })

  output$exp_meta <- renderUI({
    e <- exp_state()
    if (is.null(e))
      return(div(class = "note", tags$b("No experiment has been run yet. "),
                 "Set the design on the left and press Run experiment. The result is synthetic and is never mixed with the active dataset."))
    s <- e$settings
    stale <- !isTRUE(all.equal(e$alpha, alpha_val()))
    tagList(
      div(class = "stat-grid",
        stat_card("SYNTHETIC", "data type", "warn"),
        stat_card(fmt_int(e$base_n), "base sample size"),
        stat_card(fmt_int(e$R), "replicates per cell"),
        stat_card(sprintf("%.3g", e$alpha), "alpha used"),
        stat_card(fmt_int(nrow(e$replicates)), "simulated tests")),
      if (stale)
        div(class = "note warn", tags$b("Alpha changed after this run. "),
            "The detection rates below were computed with alpha = ", e$alpha,
            ". Re-run the experiment to update them."),
      p(class = "caption",
        sprintf("Design: n = %s, R = %s, seed = %s, levels = %s.",
                fmt_int(s$n), fmt_int(s$R), s$seed,
                paste(s$levels, collapse = ", ")))
    )
  })

  output$exp_curve <- renderPlot({
    e <- exp_state()
    validate(need(!is.null(e), "Run the experiment to draw the detection curve."))
    s <- e$summary
    s$manip_label <- factor(manipulation_labels()[s$manipulation],
                            levels = unname(manipulation_labels()))
    ggplot(s, aes(x = true_alteration_rate, y = detection_rate, colour = manip_label)) +
      geom_line(linewidth = 1) +
      geom_point(size = 2.2) +
      geom_errorbar(aes(ymin = pmax(0, detection_rate - detection_se),
                        ymax = pmin(1, detection_rate + detection_se)), width = 0.012) +
      geom_hline(yintercept = e$alpha, linetype = "dashed", colour = KIT$ink) +
      scale_colour_manual("", values = unname(c(KIT$blue, KIT$orange, KIT$green))) +
      scale_x_continuous(labels = function(x) sprintf("%.0f%%", 100 * x)) +
      scale_y_continuous(labels = function(x) sprintf("%.0f%%", 100 * x),
                         limits = c(0, 1)) +
      labs(title = "Detection rate vs true alteration rate (SYNTHETIC)",
           x = "true fraction of records altered",
           y = "proportion flagged (p < alpha)") +
      theme_kit()
  })

  output$exp_sum <- renderDT({
    e <- exp_state()
    validate(need(!is.null(e), "Run the experiment to see the summary."))
    df <- e$summary
    df$mean_mad <- round(df$mean_mad, 4)
    df$median_mad <- round(df$median_mad, 4)
    df$mean_x2 <- round(df$mean_x2, 2)
    df$detection_rate <- round(df$detection_rate, 3)
    df$detection_se <- round(df$detection_se, 3)
    datatable(df, class = "compact stripe hover row-border",
              options = list(pageLength = 10, scrollX = TRUE, autoWidth = FALSE),
              rownames = FALSE)
  })

  output$exp_anova <- renderDT({
    e <- exp_state()
    validate(need(!is.null(e), "Run the experiment to see the ANOVA results."))
    an <- e$anova
    an$statistic <- round(an$statistic, 4)
    an$p_value <- signif(an$p_value, 4)
    datatable(an, class = "compact stripe hover row-border",
              options = list(pageLength = 10, scrollX = TRUE, autoWidth = FALSE),
              rownames = FALSE)
  })

  output$exp_reg <- renderDT({
    e <- exp_state()
    validate(need(!is.null(e), "Run the experiment to see the regression results."))
    rg <- e$reg
    num <- vapply(rg, is.numeric, logical(1))
    rg[num] <- lapply(rg[num], function(z) signif(z, 5))
    datatable(rg, class = "compact stripe hover row-border",
              options = list(pageLength = 10, scrollX = TRUE, autoWidth = FALSE),
              rownames = FALSE)
  })

  ## -------------------------------------------------- tab 8: export
  output$export_context <- renderUI({
    st <- data_state()
    if (is.null(st) || is.null(st$df))
      return(div(class = "note bad", "No dataset is active. Load data before exporting."))
    r <- tryCatch(result4(), error = function(e) NULL)
    div(class = "note ok",
        tags$b("Export context. "),
        "Dataset: ", st$short, " \u00b7 Column: ", current_col("col4", st$df),
        " \u00b7 Subset: ", subset_desc("sub_var4", "sub_val_sel4", st$df),
        " \u00b7 N: ", if (is.null(r)) "\u2014" else fmt_int(r$N),
        " \u00b7 \u03b1: ", alpha_val())
  })

  dl <- function(name, getter) {
    downloadHandler(
      filename = function() name,
      content = function(f) {
        df <- tryCatch(getter(), error = function(e) {
          data.frame(note = paste("Could not build this download:", conditionMessage(e)),
                     stringsAsFactors = FALSE)
        })
        if (is.null(df) || !is.data.frame(df) || !nrow(df))
          df <- data.frame(note = "No result available yet. Load data and run the analysis first.",
                           stringsAsFactors = FALSE)
        utils::write.csv(df, f, row.names = FALSE)
      })
  }

  build_chi <- function() {
    st <- data_state()
    if (is.null(st) || is.null(st$df)) return(NULL)
    r <- result4()
    if (is.null(r)) return(NULL)
    data.frame(indicator = current_col("col4", st$df),
               subset = subset_desc("sub_var4", "sub_val_sel4", st$df),
               N = r$N, df = r$df, X2 = r$x2, p_value = r$p, alpha = r$alpha,
               validity_tier = r$tier, min_expected_count = r$min_E,
               MAD = r$mad, nigrini_band = r$band, cohens_w = r$cohen_w,
               decision = r$decision, stringsAsFactors = FALSE)
  }
  build_freq <- function() {
    st <- data_state()
    if (is.null(st) || is.null(st$df)) return(NULL)
    r <- result4()
    if (is.null(r)) return(NULL)
    data.frame(indicator = current_col("col4", st$df),
               subset = subset_desc("sub_var4", "sub_val_sel4", st$df),
               r$frequency,
               expected_proportion = as.numeric(r$expected_prop),
               expected_count = as.numeric(r$E),
               pearson_residual = as.numeric(r$residuals))
  }
  build_flags <- function() {
    st <- data_state()
    if (is.null(st) || is.null(st$df)) return(NULL)
    v <- vals4()
    if (!length(v)) return(NULL)
    s <- suitability(v, name = current_col("col4", st$df))
    r <- result4()
    if (is.null(r)) return(NULL)
    fl <- flag_anomaly(!identical(s$verdict, "Unsuitable"), r$N, r$p, r$mad, alpha_val())
    data.frame(indicator = current_col("col4", st$df),
               subset = subset_desc("sub_var4", "sub_val_sel4", st$df),
               suitability = s$verdict,
               n = r$N, p_value = r$p, mad = r$mad,
               flag = fl$flag, interpretation = fl$interpretation,
               stringsAsFactors = FALSE)
  }
  build_desc <- function() {
    d <- describe_numeric(vals4())
    out <- as.data.frame(d, stringsAsFactors = FALSE)
    out$indicator <- current_col("col4")
    out
  }
  build_two <- function() {
    r <- result5()
    if (is.null(r)) return(NULL)
    mk <- function(x, lbl) {
      if (is.null(x)) return(NULL)
      data.frame(test = lbl, N = x$N, df = x$df, X2 = x$x2, p_value = x$p,
                 validity_tier = x$tier, min_expected_count = x$min_E,
                 MAD = x$mad, stringsAsFactors = FALSE)
    }
    out <- rbind(mk(r$f2, "first_two_digits"), mk(r$sd2, "second_digit"))
    if (!is.null(out)) out$indicator <- current_col("col5")
    out
  }
  build_subset <- function() {
    out <- subset_results()
    out[, c("group", "N", "X2", "p_raw", "p_holm", "p_bh", "MAD",
            "tier", "suitability", "flag"), drop = FALSE]
  }

  output$dl_chi <- dl("benford_chi_square.csv", build_chi)
  output$dl_freq <- dl("benford_first_digit_frequency.csv", build_freq)
  output$dl_flags <- dl("benford_column_flag_summary.csv", build_flags)
  output$dl_desc <- dl("benford_descriptive_statistics.csv", build_desc)
  output$dl_two <- dl("benford_extended_digits.csv", build_two)
  output$dl_subset <- dl("benford_subset_comparison.csv", build_subset)
  output$dl_exp <- dl("benford_experiment_summary.csv", function() exp_state()$summary)
  output$dl_an <- dl("benford_anova_results.csv", function() exp_state()$anova)
  output$dl_rg <- dl("benford_regression_results.csv", function() exp_state()$reg)

  output$report_buttons <- renderUI({
    files <- c(
      html = file.path(ROOT, "reports", "benford_report.html"),
      docx = file.path(ROOT, "reports", "benford_report.docx"))
    if (!any(file.exists(files)))
      return(div(class = "note", "No rendered report found. Run Rscript scripts/run_all.R to build it."))
    btns <- list()
    if (file.exists(files[["html"]]))
      btns <- c(btns, list(downloadButton("dl_report_html", "Report (HTML)")))
    if (file.exists(files[["docx"]]))
      btns <- c(btns, list(downloadButton("dl_report_docx", "Report (Word)")))
    div(class = "dl-grid", btns)
  })

  output$dl_report_html <- downloadHandler(
    filename = function() "benford_report.html",
    content = function(f) {
      src <- file.path(ROOT, "reports", "benford_report.html")
      if (file.exists(src)) file.copy(src, f, overwrite = TRUE)
      else writeLines("Report not rendered yet. Run scripts/run_all.R.", f)
    })
  output$dl_report_docx <- downloadHandler(
    filename = function() "benford_report.docx",
    content = function(f) {
      src <- file.path(ROOT, "reports", "benford_report.docx")
      if (file.exists(src)) file.copy(src, f, overwrite = TRUE)
      else writeLines("Report not rendered yet. Run scripts/run_all.R.", f)
    })

  output$fig_links <- renderUI({
    fs <- list.files(file.path(ROOT, "outputs", "figures"),
                     pattern = "\\.png$", full.names = TRUE)
    if (!length(fs))
      return(div(class = "note", "No pipeline figures found. Run Rscript scripts/run_all.R first."))
    div(class = "fig-grid", lapply(fs, function(p) {
      b <- basename(p)
      div(class = "fig",
          tags$a(href = paste0("outputs/figures/", b), target = "_blank", rel = "noopener",
                 tags$img(src = paste0("outputs/figures/", b), alt = b, loading = "lazy")),
          tags$a(href = paste0("outputs/figures/", b), target = "_blank", rel = "noopener", b))
    }))
  })

  ## -------------------------------------------------- navigation / help
  observeEvent(input$jump_data, {
    bslib::nav_select("main_tabs", "data")
  })
  observeEvent(input$jump_col, {
    bslib::nav_select("main_tabs", "column")
  })
  observeEvent(input$jump_first, {
    bslib::nav_select("main_tabs", "first")
  })
  observeEvent(input$jump_extended, {
    bslib::nav_select("main_tabs", "extended")
  })
  observeEvent(input$jump_compare, {
    bslib::nav_select("main_tabs", "compare")
  })
  observeEvent(input$jump_experiment, {
    bslib::nav_select("main_tabs", "experiment")
  })

  observeEvent(input$show_boundary, {
    showModal(modalDialog(
      title = "How to read this instrument case",
      easyClose = TRUE,
      footer = modalButton("Close"),
      tags$p(tags$b("Statistical deviation is not proof of fraud. "), BOUNDARY),
      tags$ul(class = "reason-list",
        tags$li("The first-digit test is applied to one column (and optionally one subset) at a time."),
        tags$li("The chi-square p-value is only shown when the expected-count validity rules are met."),
        tags$li("MAD and Nigrini bands are always reported with the p-value."),
        tags$li("Subset p-values are Holm- and BH-adjusted within the comparison family."),
        tags$li("The experiment is synthetic and is never mixed with the active dataset.")),
      tags$p(class = "caption",
        "Use the Data desk to stage a dataset; every other tab follows the active dataset, column and subset automatically.")
    ))
  })
}

shiny::shinyApp(ui, server)
