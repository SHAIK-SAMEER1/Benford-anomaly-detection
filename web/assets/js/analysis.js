/* ==========================================================================
   analysis.js — client-side statistics for uploaded CSVs
   The built-in datasets use the R pipeline. This file gives an upload the same
   shape: schema, quality, Benford tests, group tests, peer screening.
   It is deliberately conservative: no labels are invented, no scores are
   presented as probabilities of fraud.
   ========================================================================== */
(function () {
  "use strict";

  const FIRST = Array.from({ length: 9 }, (_, i) => Math.log10(1 + 1 / (i + 1)));
  const SECOND = Array.from({ length: 10 }, (_, j) => {
    let p = 0;
    for (let k = 1; k <= 9; k++) p += Math.log10(1 + 1 / (10 * k + j));
    return p;
  });
  const FIRST2 = Array.from({ length: 90 }, (_, i) => Math.log10(1 + 1 / (10 + i)));

  const log10 = Math.log10;
  const isNum = (v) => v != null && v !== "" && isFinite(Number(v));

  function parseNumber(raw) {
    if (raw == null) return NaN;
    if (typeof raw === "number") return raw;
    let s = String(raw).trim();
    if (!s) return NaN;
    let neg = false;
    if (/^\(.*\)$/.test(s)) { neg = true; s = s.slice(1, -1); }
    s = s.replace(/[$€£¥,\s]/g, "");
    if (/^-/.test(s)) { neg = !neg; s = s.slice(1); }
    if (!/^[+-]?(\d+\.?\d*|\.\d+)(e[+-]?\d+)?$/i.test(s)) return NaN;
    const v = Number(s);
    return neg ? -v : v;
  }

  function splitCsvLine(line) {
    const out = [];
    let field = "", q = false;
    for (let i = 0; i < line.length; i++) {
      const ch = line[i];
      if (q) {
        if (ch === '"') {
          if (line[i + 1] === '"') { field += '"'; i++; }
          else q = false;
        } else field += ch;
      } else if (ch === '"') q = true;
      else if (ch === ",") { out.push(field); field = ""; }
      else field += ch;
    }
    out.push(field);
    return out;
  }

  function parseCSV(text, maxRows) {
    text = text.replace(/^\uFEFF/, "");
    let rows = [], row = [], field = "", q = false, i = 0;
    const n = text.length;
    while (i < n) {
      const ch = text[i];
      if (q) {
        if (ch === '"') {
          if (text[i + 1] === '"') { field += '"'; i += 2; continue; }
          q = false; i++; continue;
        }
        field += ch; i++; continue;
      }
      if (ch === '"') { q = true; i++; continue; }
      if (ch === ",") { row.push(field); field = ""; i++; continue; }
      if (ch === "\n" || ch === "\r") {
        if (ch === "\r" && text[i + 1] === "\n") i++;
        row.push(field); field = "";
        if (row.length > 1 || row[0] !== "") rows.push(row);
        row = []; i++;
        if (maxRows && rows.length >= maxRows + 1) break;
        continue;
      }
      field += ch; i++;
    }
    if (field !== "" || row.length) { row.push(field); rows.push(row); }
    if (!rows.length) return { header: [], rows: [], truncated: false };
    const header = rows[0].map((h, j) => {
      let name = String(h).trim();
      if (!name) name = "column_" + (j + 1);
      return name;
    });
    return { header, rows: rows.slice(1), truncated: !!(maxRows && rows.length >= maxRows + 1) };
  }

  function quantile(sorted, p) {
    if (!sorted.length) return NaN;
    if (sorted.length === 1) return sorted[0];
    const pos = (sorted.length - 1) * p;
    const lo = Math.floor(pos), hi = Math.ceil(pos);
    if (lo === hi) return sorted[lo];
    return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
  }

  function median(v) {
    const a = v.filter(isFinite).sort((x, y) => x - y);
    return quantile(a, 0.5);
  }
  function mean(v) {
    const a = v.filter(isFinite);
    return a.length ? a.reduce((s, x) => s + x, 0) / a.length : NaN;
  }
  function sd(v) {
    const a = v.filter(isFinite);
    if (a.length < 2) return NaN;
    const m = mean(a);
    return Math.sqrt(a.reduce((s, x) => s + (x - m) ** 2, 0) / (a.length - 1));
  }
  function skew(v) {
    const a = v.filter(isFinite);
    if (a.length < 3) return NaN;
    const m = mean(a), s2 = a.reduce((s, x) => s + (x - m) ** 2, 0) / a.length;
    if (s2 <= 0) return NaN;
    return a.reduce((s, x) => s + (x - m) ** 3, 0) / a.length / Math.pow(s2, 1.5);
  }

  function lgamma(x) {
    const g = [76.18009172947146, -86.50532032941677, 24.01409824083091,
      -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5];
    let y = x, tmp = x + 5.5;
    tmp -= (x + 0.5) * Math.log(tmp);
    let ser = 1.000000000190015;
    for (let j = 0; j < 6; j++) ser += g[j] / ++y;
    return -tmp + Math.log(2.5066282746310005 * ser / x);
  }
  function gammaincLower(a, x) {
    if (x <= 0) return 0;
    if (x < a + 1) {
      let ap = a, sum = 1 / a, del = sum;
      for (let k = 0; k < 200; k++) {
        ap++; del *= x / ap; sum += del;
        if (Math.abs(del) < Math.abs(sum) * 1e-12) break;
      }
      return sum * Math.exp(-x + a * Math.log(x) - lgamma(a));
    }
    // continued fraction for the upper tail
    let b = x + 1 - a, c = 1e300, d = 1 / b, h = d;
    for (let k = 1; k < 200; k++) {
      const an = -k * (k - a);
      b += 2;
      d = an * d + b;
      if (Math.abs(d) < 1e-300) d = 1e-300;
      c = b + an / c;
      if (Math.abs(c) < 1e-300) c = 1e-300;
      d = 1 / d;
      const del = d * c;
      h *= del;
      if (Math.abs(del - 1) < 1e-12) break;
    }
    return 1 - Math.exp(-x + a * Math.log(x) - lgamma(a)) * h;
  }
  function chi2sf(x, df) {
    if (!isFinite(x) || x <= 0) return 1;
    return Math.max(0, Math.min(1, 1 - gammaincLower(df / 2, x / 2)));
  }

  function benfordProbs(kind) {
    return kind === "first2" ? FIRST2 : kind === "second" ? SECOND : FIRST;
  }
  function digitsOf(value, kind) {
    if (!isFinite(value) || value === 0) return NaN;
    const s = Math.abs(value).toExponential(14);
    const mant = s.split("e")[0].replace(/[^0-9]/g, "");
    if (kind === "first") return Number(mant[0]);
    if (kind === "second") return Number(mant[1]);
    return Number(mant.slice(0, 2));
  }

  function countDigits(values, kind) {
    const probs = benfordProbs(kind);
    const counts = probs.map(() => 0);
    let n = 0;
    for (let i = 0; i < values.length; i++) {
      const d = digitsOf(values[i], kind);
      if (!isFinite(d)) continue;
      const idx = kind === "first2" ? d - 10 : kind === "second" ? d : d - 1;
      if (idx >= 0 && idx < counts.length) { counts[idx]++; n++; }
    }
    return { counts, n, probs };
  }

  function benfordTest(values, kind) {
    const probs = benfordProbs(kind);
    const { counts, n } = countDigits(values, kind);
    const minN = kind === "first2" ? 1150 : 110;
    const expected = probs.map((p) => n * p);
    let valid = n >= minN && expected.every((e) => e >= 1);
    let tier = "Not run";
    if (n < minN) tier = "Not run";
    else if (expected.every((e) => e >= 5)) { tier = "Reliable"; valid = true; }
    else if (expected.some((e) => e < 5) && expected.filter((e) => e < 5).length / expected.length <= 0.2) { tier = "Caution"; valid = true; }
    else { tier = "Not run"; valid = false; }
    let chi2 = NaN, p = NaN;
    if (valid) {
      chi2 = counts.reduce((s, c, i) => s + (c - expected[i]) ** 2 / expected[i], 0);
      p = chi2sf(chi2, probs.length - 1);
    }
    const obs = counts.map((c) => c / (n || 1));
    const mad = obs.reduce((s, v, i) => s + Math.abs(v - probs[i]), 0) / probs.length;
    const residuals = counts.map((c, i) => expected[i] > 0 ? (c - expected[i]) / Math.sqrt(expected[i]) : NaN);
    const band = kind === "first"
      ? (mad <= 0.006 ? "Close conformity" : mad <= 0.012 ? "Acceptable conformity" : mad <= 0.015 ? "Marginal conformity" : "Nonconformity")
      : "";
    return {
      kind, N: n, counts, probs, expected, chi2: isFinite(chi2) ? chi2 : null,
      p: isFinite(p) ? p : null, df: probs.length - 1, mad: isFinite(mad) ? mad : null,
      band, tier, min_E: Math.min(...expected), residuals,
      cohen_w: isFinite(chi2) ? Math.sqrt(chi2 / (n || 1)) : null,
      decision: valid
        ? (p < 0.05 ? "Reject H0: the digit distribution differs significantly from Benford." : "Fail to reject H0: no significant deviation detected.")
        : "Not assessed: expected-count or sample-size condition not met."
    };
  }

  function pAdjust(pvals, method) {
    const idx = pvals.map((p, i) => ({ p, i })).filter((d) => d.p != null && isFinite(d.p));
    const m = idx.length;
    const out = pvals.map(() => null);
    if (!m) return out;
    idx.sort((a, b) => a.p - b.p);
    if (method === "holm") {
      let prev = 0;
      idx.forEach((d, k) => {
        const adj = Math.min(1, Math.max(prev, d.p * (m - k)));
        out[d.i] = adj; prev = adj;
      });
    } else {
      let prev = 1;
      for (let k = m - 1; k >= 0; k--) {
        const d = idx[k];
        const adj = Math.min(prev, d.p * m / (k + 1));
        out[d.i] = adj; prev = adj;
      }
    }
    return out;
  }

  function groupBenford(rows, valueIdx, groupIdx, kind) {
    const minN = kind === "first2" ? 1150 : 110;
    const map = new Map();
    rows.forEach((r) => {
      const v = parseNumber(r[valueIdx]);
      const g = r[groupIdx] == null || r[groupIdx] === "" ? "(missing)" : String(r[groupIdx]);
      if (!isFinite(v) || v <= 0) return;
      if (!map.has(g)) map.set(g, []);
      map.get(g).push(v);
    });
    const out = [];
    map.forEach((vals, g) => {
      const t = benfordTest(vals, kind);
      out.push({
        family: "Selected grouping", group: g, n: t.N, chi2: t.chi2, p: t.p,
        df: t.df, mad: t.mad, band: t.band, tier: t.tier, min_E: t.min_E,
        cohen_w: t.cohen_w, counts: t.counts, residuals: t.residuals,
        flag: t.tier === "Not run" ? "Not assessed - insufficient sample"
          : (t.p < 0.05 && t.mad > 0.006 ? "Statistical deviation: significant AND practically material"
            : t.p < 0.05 ? "Statistically significant but small deviation" : "No significant deviation detected")
      });
    });
    return out.sort((a, b) => b.n - a.n);
  }

  function inferColumn(values, name) {
    const nonEmpty = values.filter((v) => v != null && String(v).trim() !== "");
    const sample = nonEmpty.slice(0, 600);
    const numeric = sample.map(parseNumber).filter(isFinite).length / Math.max(1, sample.length);
    const dateish = sample.filter((v) => {
      if (isNum(v)) return false;
      const s = String(v);
      return /^\d{4}-\d{2}-\d{2}/.test(s) || /^\d{1,2}[\/.-]\d{1,2}[\/.-]\d{2,4}/.test(s);
    }).length / Math.max(1, sample.length);
    const uniq = new Set(sample.map(String)).size;
    const uniqRatio = uniq / Math.max(1, sample.length);
    const lname = name.toLowerCase();
    let role = "text";
    if (/\b(class|fraud|is_fraud|isfraud|label|target|outcome|default)\b/.test(lname)) role = "label";
    else if (/(^|_)(id|key|uei|code|number|no)($|_)|identifier|invoice/.test(lname) && uniqRatio > 0.5) role = "identifier";
    else if (numeric >= 0.8) role = uniq <= 12 ? "categorical" : "numeric";
    else if (dateish >= 0.7) role = "date";
    else if (uniqRatio < 0.5 && uniq <= 60) role = "categorical";
    else if (uniqRatio > 0.9) role = "identifier";
    if (/(amount|obligation|revenue|price|value|total|balance|quantity|salary|cost|spend)/.test(lname)) role = role === "label" ? role : "measure";
    if (/(agency|country|region|type|category|subagency|state|class_name|group|sector|department)/.test(lname) && role === "text") role = "categorical";
    return { role, numericShare: numeric, dateShare: dateish, unique: uniq, uniqueRatio: uniqRatio };
  }

  function buildProfile(fileName, text, opts = {}) {
    const MAX_ROWS = opts.maxRows || 200000;
    const parsed = parseCSV(text, MAX_ROWS);
    const header = parsed.header;
    const rawRows = parsed.rows;
    if (!header.length) throw new Error("The file has no readable header row.");
    const rows = rawRows.map((r) => header.map((_, i) => r[i] == null ? "" : r[i]));
    const cols = header.map((name, i) => {
      const vals = rows.map((r) => r[i]);
      const inf = inferColumn(vals, name);
      return { name, index: i, ...inf, values: vals };
    });

    // choose measure: explicit, then strongest measure-named numeric column
    let measureCol = opts.measure ? cols.find((c) => c.name === opts.measure) : null;
    if (!measureCol) {
      const candidates = cols.filter((c) => c.role === "measure" || (c.numericShare || 0) > 0.9);
      const scored = candidates.map((c) => {
        const nums = c.values.map(parseNumber).filter((v) => isFinite(v) && v > 0);
        const rng = nums.length ? log10(Math.max(...nums) / Math.min(...nums)) : 0;
        const nameBonus = /(amount|obligation|revenue|price|value|total|cost|spend)/i.test(c.name) ? 4 : 0;
        return { c, score: nameBonus + Math.min(4, rng) + Math.min(3, nums.length / 50000) + (c.role === "measure" ? 2 : 0) };
      }).sort((a, b) => b.score - a.score);
      measureCol = scored.length ? scored[0].c : cols.find((c) => (c.numericShare || 0) > 0.8);
    }
    if (!measureCol) throw new Error("No numeric measurement column could be detected. Choose one manually.");
    const values = rows.map((r) => parseNumber(r[measureCol.index]));
    const pos = values.filter((v) => isFinite(v) && v > 0);

    // group column: explicit, then low-cardinality meaningful categorical
    let groupCol = opts.group ? cols.find((c) => c.name === opts.group) : null;
    if (!groupCol) {
      const candidates = cols.filter((c) => c.index !== measureCol.index && (c.role === "categorical" || ((c.unique || 0) >= 2 && (c.unique || 0) <= 30)));
      const scored = candidates.map((c) => {
        const nGroups = new Set(rows.map((r) => r[c.index]).filter((v) => v !== "")).size;
        const nameBonus = /(agency|country|region|type|category|sector|department|subagency|state|group)/i.test(c.name) ? 5 : 0;
        return { c, score: nameBonus + (nGroups >= 2 && nGroups <= 20 ? 3 : 0) + (rows.length / nGroups > 50 ? 1 : 0) };
      }).sort((a, b) => b.score - a.score);
      groupCol = scored.length ? scored[0].c : null;
    }
    const groupVals = groupCol ? rows.map((r) => r[groupCol.index]) : null;

    // date / time column for trends
    const dateCol = cols.find((c) => c.role === "date") ||
      cols.find((c) => /(year|month|date|step|time)/i.test(c.name) && (c.numericShare || 0) > 0.8) || null;

    // label candidate, never silently used as a predictor
    const labelCol = opts.label ? cols.find((c) => c.name === opts.label) :
      cols.find((c) => c.role === "label" && new Set(rows.map((r) => String(r[c.index]))).size <= 3) || null;

    // quality
    const missingCells = rows.reduce((s, r) => s + r.filter((v) => String(v).trim() === "").length, 0);
    const seen = new Set();
    let duplicateRows = 0;
    rows.forEach((r) => {
      const key = r.join("\u0001");
      if (seen.has(key)) duplicateRows++; else seen.add(key);
    });
    const quality = {
      rows: rows.length, cols: header.length, cells: rows.length * header.length,
      missingCells, missingPct: rows.length * header.length ? 100 * missingCells / (rows.length * header.length) : 0,
      duplicateRows, duplicateRowPct: rows.length ? 100 * duplicateRows / rows.length : 0,
      missingAmount: values.filter((v) => !isFinite(v)).length,
      missingAmountPct: rows.length ? 100 * values.filter((v) => !isFinite(v)).length / rows.length : 0,
      zeroAmounts: values.filter((v) => v === 0).length,
      negativeAmounts: values.filter((v) => v < 0).length,
      invalidAmounts: 0,
      missingDates: dateCol ? rows.filter((r) => String(r[dateCol.index]).trim() === "").length : null,
      minDate: "", maxDate: "",
      idDuplicates: null, signatureDuplicates: null, missingGroups: groupVals ? groupVals.filter((v) => !v).length : null,
      positiveAmounts: pos.length, retained: pos.length, excluded: rows.length - pos.length
    };

    const benford = {
      first: benfordTest(pos, "first"),
      first2: benfordTest(pos, "first2"),
      second: benfordTest(pos, "second")
    };
    const groups = {
      first: groupCol ? groupBenford(rows, measureCol.index, groupCol.index, "first") : [],
      first2: groupCol ? groupBenford(rows, measureCol.index, groupCol.index, "first2") : [],
      second: groupCol ? groupBenford(rows, measureCol.index, groupCol.index, "second") : []
    };

    // peer screening
    const anomalies = screenPeers(rows, measureCol, groupCol, dateCol, cols);

    // peers
    const peers = buildPeers(rows, measureCol, groupCol, dateCol);

    // schema
    const schema = cols.map((c) => {
      let miss = 0;
      for (let i = 0; i < rows.length; i++) if (String(rows[i][c.index]).trim() === "") miss++;
      return {
        name: c.name, mapped: c.name, role: c.role,
        type: c.role === "numeric" || c.role === "measure" ? "numeric" : c.role === "date" ? "date" : "text",
        missing: miss, missingPct: rows.length ? 100 * miss / rows.length : 0,
        unique: new Set(rows.map((r) => r[c.index])).size,
        sample: String((rows.find((r) => String(r[c.index]).trim() !== "") || [])[c.index] || "").slice(0, 42)
      };
    });

    const rng = pos.length ? log10(Math.max(...pos) / Math.min(...pos)) : 0;
    const uniqueShare = pos.length ? new Set(pos).size / pos.length : 0;
    const sk = skew(pos);
    const roundShare = pos.length ? pos.filter((v) => v >= 1000 && v % 1000 === 0).length / pos.length : 0;
    const checks = [
      { key: "Sample size", ok: pos.length >= 110, detail: `N = ${pos.length.toLocaleString()} positive values (minimum 110 for all first-digit expected counts).` },
      { key: "Dynamic range", ok: rng >= 2, detail: `${rng.toFixed(2)} orders of magnitude between the smallest and largest value.` },
      { key: "Right skew", ok: sk > 0, detail: `Moment skewness ${isFinite(sk) ? sk.toFixed(2) : "—"}.` },
      { key: "Uniqueness", ok: uniqueShare >= 0.5, detail: `${(100 * uniqueShare).toFixed(0)}% of positive values are distinct.` },
      { key: "No hard ceiling", ok: roundShare <= 0.5, detail: `${(100 * roundShare).toFixed(1)}% of values are exact multiples of 1,000.` }
    ];
    const hard = checks.filter((c) => !c.ok).length;
    const suitability = {
      label: measureCol.name, n: pos.length, rangeOrders: rng, skewness: sk,
      uniqueShare, roundShare, checks,
      verdict: pos.length < 110 ? "Insufficient" : hard >= 3 ? "Unsuitable" : hard >= 1 ? "Use with caution" : "Suitable"
    };

    const today = new Date().toISOString().slice(0, 10);
    return {
      id: "upload-" + Date.now().toString(36),
      name: fileName, short: "Session upload", category: "Uploaded CSV \u00b7 in-browser analysis",
      kind: "upload", upload: true,
      source: "Browser upload (not written to disk)", url: "",
      file: fileName, path: "(browser memory)", sizeBytes: text.length,
      downloaded: today,
      filters: `${rows.length.toLocaleString()} rows parsed${parsed.truncated ? " (capped at " + MAX_ROWS.toLocaleString() + " for analysis)" : ""} \u00b7 ${header.length} columns`,
      description: `A CSV uploaded in this browser session. The active measure is ${measureCol.name}; the comparison grouping is ${groupCol ? groupCol.name : "not available"}.`,
      caveat: "Uploaded data exists only in this browser tab. Nothing is uploaded to a server. Statistical flags are review prompts, not fraud determinations.",
      rows: rows.length, cols: header.length, mappedCols: header.length,
      schema,
      fieldMap: [],
      measure: {
        column: measureCol.name, label: measureCol.name, currency: "",
        n: pos.length, note: "Positive values only for digit extraction; zero and negative values are retained and counted separately."
      },
      quality, suitability, benford, groups, anomalies, peers,
      model: null,
      available: ["benford", "anomaly", "peers", "quality"],
      columns: header,
      preview: rows.slice(0, 8),
      groupColumn: groupCol ? groupCol.name : null,
      dateColumn: dateCol ? dateCol.name : null,
      labelColumn: labelCol ? labelCol.name : null,
      truncated: parsed.truncated
    };
  }

  function screenPeers(rows, measureCol, groupCol, dateCol, cols) {
    const eligible = [];
    rows.forEach((r, i) => {
      const v = parseNumber(r[measureCol.index]);
      if (!isFinite(v) || v <= 0) return;
      eligible.push({ row: r, i, v, log: log10(v), g: groupCol ? (r[groupCol.index] || "(missing)") : "All records" });
    });
    const groups = new Map();
    eligible.forEach((d) => {
      if (!groups.has(d.g)) groups.set(d.g, []);
      groups.get(d.g).push(d);
    });
    const stats = new Map();
    groups.forEach((arr, g) => {
      const lv = arr.map((d) => d.log).sort((a, b) => a - b);
      const med = quantile(lv, 0.5), q1 = quantile(lv, 0.25), q3 = quantile(lv, 0.75);
      const iqr = q3 - q1;
      const mad = median(lv.map((v) => Math.abs(v - med)));
      stats.set(g, { n: arr.length, med, q1, q3, iqr, mad, lower: q1 - 1.5 * iqr, upper: q3 + 1.5 * iqr });
    });
    const sigs = new Map(), amountCounts = new Map();
    eligible.forEach((d) => {
      const r = d.row;
      const sig = [d.g, d.v.toFixed(2), dateCol ? r[dateCol.index] : "", r[0], r[1]].join("|");
      sigs.set(sig, (sigs.get(sig) || 0) + 1);
      const ak = d.g + "|" + d.v.toFixed(2);
      amountCounts.set(ak, (amountCounts.get(ak) || 0) + 1);
    });
    const groupRound = new Map();
    groups.forEach((arr, g) => {
      groupRound.set(g, arr.filter((d) => d.v >= 1000 && d.v % 1000 === 0).length / arr.length);
    });
    const records = [];
    const family = { magnitude: 0, rounding: 0, duplication: 0, context: 0 };
    let high = 0;
    eligible.forEach((d) => {
      const s = stats.get(d.g);
      const rounded = d.v >= 1000 && d.v % 1000 === 0;
      const sig = [d.g, d.v.toFixed(2), dateCol ? d.row[dateCol.index] : "", d.row[0], d.row[1]].join("|");
      const sigCount = sigs.get(sig) || 1;
      const amountCount = amountCounts.get(d.g + "|" + d.v.toFixed(2)) || 1;
      const z = s.mad > 0 ? 0.6745 * (d.log - s.med) / s.mad : null;
      const pct = s.n > 1 ? (d.log - s.q1) / Math.max(1e-9, s.q3 - s.q1) : 0.5;
      const outside = d.log > s.upper || d.log < s.lower;
      const zFlag = z != null && Math.abs(z) >= 3.5;
      const roundFlag = rounded && (groupRound.get(d.g) || 0) <= 0.2;
      const dupFlag = sigCount > 1 || amountCount >= 5;
      if (!zFlag && !outside && !roundFlag && !dupFlag) return;
      if (zFlag || outside) family.magnitude++;
      if (roundFlag) family.rounding++;
      if (dupFlag) family.duplication++;
      const reasons = [];
      if (zFlag) reasons.push(`Modified Z = ${z.toFixed(2)} against ${s.n} peers; peer median is ${Math.pow(10, s.med).toPrecision(3)}.`);
      if (outside) reasons.push(`Outside the peer 1.5\u00d7IQR fence (log scale).`);
      if (roundFlag) reasons.push(`Round-thousand amount; only ${(100 * (groupRound.get(d.g) || 0)).toFixed(0)}% of this group is round-thousand.`);
      if (dupFlag) reasons.push(`Repeated signature across ${sigCount} record(s); the same amount appears ${amountCount} time(s) in the group.`);
      const sev = Math.max(
        z != null ? Math.min(1, Math.max(0, (Math.abs(z) - 3.5) / 4)) : 0,
        outside ? 0.7 : 0, roundFlag ? 0.58 : 0, dupFlag ? 0.8 : 0
      );
      const score = Math.min(99, Math.round(100 * sev + 4 * ((zFlag || outside ? 1 : 0) + (roundFlag ? 1 : 0) + (dupFlag ? 1 : 0) - 1)));
      if (score >= 60) high++;
      const ref = d.row[0] ? String(d.row[0]) : `row ${d.i + 2}`;
      records.push({
        ref, amount: d.v, date: dateCol ? String(d.row[dateCol.index]) : "",
        agency: groupCol ? d.g : "Uploaded data", subagency: "",
        award: d.row[0] || "", recipient: "", naics: "", description: "",
        peer: d.g, peerLevel: groupCol ? groupCol.name : "All records", peerN: s.n,
        median: Math.pow(10, s.med), mad: s.mad, z, percentile: 100 * Math.min(1, Math.max(0, pct)),
        trailingZeros: 0, round1k: roundFlag, sigCount, awardAmountCount: amountCount,
        score, families: [zFlag || outside ? "magnitude" : null, roundFlag ? "rounding" : null, dupFlag ? "duplication" : null].filter(Boolean),
        reasons
      });
    });
    records.sort((a, b) => b.score - a.score || b.amount - a.amount);
    return {
      available: true,
      method: groupCol ? `Log-scale robust screening within ${groupCol.name}` : "Log-scale robust screening across all records",
      eligible: eligible.length, candidates: records.length, highPriority: high,
      families: family,
      scoreBins: binScores(records.map((r) => r.score)),
      peerLevels: [eligible.length, 0, 0, 0],
      peerLevelLabels: [groupCol ? groupCol.name : "All records", "", "", ""],
      sample: records.slice(0, 300),
      thresholds: { z: 3.5, iqr: 1.5, minPeer: 30, roundShare: 0.2 }
    };
  }

  function binScores(scores) {
    const bins = Array(10).fill(0);
    scores.forEach((s) => { bins[Math.max(0, Math.min(9, Math.floor(s / 10)))]++; });
    return bins;
  }

  function buildPeers(rows, measureCol, groupCol, dateCol) {
    const by = new Map();
    rows.forEach((r) => {
      const v = parseNumber(r[measureCol.index]);
      if (!isFinite(v) || v <= 0) return;
      const g = groupCol ? (r[groupCol.index] || "(missing)") : "All records";
      if (!by.has(g)) by.set(g, []);
      by.get(g).push(v);
    });
    const allLogs = [];
    by.forEach((vals) => vals.forEach((v) => allLogs.push(log10(v))));
    let lo = Math.min(...allLogs), hi = Math.max(...allLogs);
    if (!isFinite(lo) || !isFinite(hi) || lo === hi) { lo = 0; hi = 1; }
    const edges = Array.from({ length: 25 }, (_, i) => lo + (hi - lo) * i / 24);
    const groups = [];
    by.forEach((vals, g) => {
      const lv = vals.map(log10).sort((a, b) => a - b);
      const med = quantile(lv, 0.5), q1 = quantile(lv, 0.25), q3 = quantile(lv, 0.75);
      const mad = median(lv.map((v) => Math.abs(v - med)));
      const hist = Array(24).fill(0);
      lv.forEach((v) => {
        let idx = Math.floor((v - lo) / (hi - lo) * 24);
        idx = Math.max(0, Math.min(23, idx)); hist[idx]++;
      });
      groups.push({
        label: g, n: vals.length, median: Math.pow(10, med), q1: Math.pow(10, q1), q3: Math.pow(10, q3),
        mad, upper: Math.pow(10, q3 + 1.5 * (q3 - q1)), lower: Math.pow(10, q1 - 1.5 * (q3 - q1)),
        flagged: 0, hist
      });
    });
    groups.sort((a, b) => b.n - a.n);
    let trend = null;
    if (dateCol) {
      const m = new Map();
      rows.forEach((r) => {
        const v = parseNumber(r[measureCol.index]);
        if (!isFinite(v)) return;
        let key = String(r[dateCol.index] || "").slice(0, 10);
        if (!key) return;
        if (/^\d{4}$/.test(key)) key = key;
        else if (/^\d/.test(key) && key.length >= 7) key = key.slice(0, 7);
        if (!m.has(key)) m.set(key, { count: 0, value: 0 });
        const o = m.get(key); o.count++; o.value += v;
      });
      const keys = Array.from(m.keys()).sort();
      trend = {
        labels: keys, count: keys.map((k) => m.get(k).count),
        value: keys.map((k) => m.get(k).value), flagged: null,
        label: "Aggregate by " + dateCol.name, unit: ""
      };
    }
    return {
      levels: groupCol ? [groupCol.name] : ["All records"],
      levelCounts: {}, groups: groups.slice(0, 40), histEdges: edges, trend,
      series: groups.slice(0, 12).map((g) => ({ label: g.label, labels: [], values: [] }))
    };
  }

  window.KitAnalysis = {
    parseCSV, buildProfile, parseNumber, benfordTest, groupBenford, pAdjust,
    chi2sf, quantile, median, mean, sd, skew, countDigits, benfordProbs, digitsOf
  };
})();
