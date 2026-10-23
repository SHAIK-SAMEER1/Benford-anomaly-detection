/* ==========================================================================
   charts.js — dependency-free SVG instruments
   Every chart returns an SVG string so views stay declarative.
   ========================================================================== */
(function () {
  "use strict";
  const C = {
    ink: "#1c1b17", ink3: "#6a6557", line: "#cfc6b0", paper: "#fbf7ec",
    oxide: "#b3422d", teal: "#2e6b62", brass: "#c9a34b", plum: "#6a405c",
    blue: "#2f4c6e", green: "#3c6b45"
  };
  const esc = (s) => String(s == null ? "" : s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
  const nf = (v, d = 0) => {
    if (v == null || !isFinite(v)) return "—";
    return Number(v).toLocaleString("en-US", { maximumFractionDigits: d, minimumFractionDigits: d });
  };
  const compact = (v) => {
    if (v == null || !isFinite(v)) return "—";
    const a = Math.abs(v);
    if (a >= 1e12) return (v / 1e12).toFixed(1) + "T";
    if (a >= 1e9) return (v / 1e9).toFixed(1) + "B";
    if (a >= 1e6) return (v / 1e6).toFixed(1) + "M";
    if (a >= 1e3) return (v / 1e3).toFixed(1) + "K";
    if (a >= 10) return v.toFixed(0);
    if (a >= 1) return v.toFixed(1);
    return v.toFixed(a < 0.01 ? 4 : 2);
  };
  const money = (v) => {
    if (v == null || !isFinite(v)) return "—";
    return "$" + compact(v);
  };
  const pct = (v, d = 1) => (v == null || !isFinite(v)) ? "—" : (100 * v).toFixed(d) + "%";
  const pow = (v) => {
    if (v == null || !isFinite(v)) return "—";
    const e = Math.round(v);
    return "10" + (e === 0 ? "" : "<tspan baseline-shift='super' font-size='8'>" + e + "</tspan>");
  };

  function frame(w, h, inner, label) {
    return `<svg viewBox="0 0 ${w} ${h}" role="img" aria-label="${esc(label || "chart")}">${inner}</svg>`;
  }
  function txt(x, y, s, opt = {}) {
    const anchor = opt.anchor || "start";
    const size = opt.size || 10;
    const fill = opt.fill || C.ink3;
    const weight = opt.weight || 400;
    const family = opt.mono === false ? "var(--serif)" : "var(--mono)";
    const rot = opt.rotate ? ` transform="rotate(${opt.rotate} ${x} ${y})"` : "";
    return `<text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${family}" font-size="${size}" font-weight="${weight}" fill="${fill}"${rot}>${s}</text>`;
  }
  function line(x1, y1, x2, y2, opt = {}) {
    return `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${opt.stroke || C.line}" stroke-width="${opt.width || 1}" ${opt.dash ? `stroke-dasharray="${opt.dash}"` : ""} opacity="${opt.opacity == null ? 1 : opt.opacity}"/>`;
  }

  /* ------------------------------------------------------------- Benford */
  function benfordBars(counts, probs, opts = {}) {
    const w = 760, h = 304, l = 46, r = 14, t = 18, b = 38;
    const pw = w - l - r, ph = h - t - b;
    const n = counts.reduce((a, b2) => a + b2, 0) || 1;
    const obs = counts.map((v) => v / n);
    const maxV = Math.max(0.36, ...obs, ...probs) * 1.06;
    const ymax = Math.ceil(maxV * 10) / 10;
    const y = (v) => t + ph - (v / ymax) * ph;
    const bw = (pw / 9) * 0.54;
    let g = "";
    for (let k = 0; k <= 4; k++) {
      const val = (ymax / 4) * k;
      g += line(l, y(val), w - r, y(val), { stroke: C.line, width: 1 });
      g += txt(l - 6, y(val) + 3, (val * 100).toFixed(0) + "%", { anchor: "end", size: 8.5 });
    }
    let dots = "";
    for (let i = 0; i < 9; i++) {
      const cx = l + (i + 0.5) * (pw / 9);
      const dev = Math.abs(obs[i] - probs[i]);
      const col = dev <= 0.012 ? C.teal : dev <= 0.03 ? C.brass : C.oxide;
      const bh = Math.max(0, (obs[i] / ymax) * ph);
      g += `<g><title>Digit ${i + 1}: observed ${pct(obs[i], 1)}, Benford ${pct(probs[i], 1)}, deviation ${(100 * (obs[i] - probs[i])).toFixed(1)} pp</title>`;
      g += `<rect x="${cx - bw / 2}" y="${y(obs[i])}" width="${bw}" height="${bh}" fill="${col}" fill-opacity="0.22" stroke="${col}" stroke-width="1.6"/>`;
      g += `<rect x="${cx - bw / 2}" y="${y(obs[i])}" width="${bw}" height="${Math.min(6, bh)}" fill="${col}" fill-opacity="0.85"/>`;
      if (opts.highlight === i + 1) g += `<rect x="${cx - bw / 2 - 4}" y="${t - 2}" width="${bw + 8}" height="${ph + 4}" fill="none" stroke="${C.ink}" stroke-width="1.4" stroke-dasharray="3 3"/>`;
      g += `</g>`;
      g += txt(cx, h - 14, String(i + 1), { anchor: "middle", size: 12, weight: 700, fill: C.ink });
      if (opts.showValues) g += txt(cx, y(obs[i]) - 4, (obs[i] * 100).toFixed(1), { anchor: "middle", size: 7.5, fill: col, weight: 700 });
      dots += `${cx},${y(probs[i])} `;
    }
    g += `<polyline points="${dots.trim()}" fill="none" stroke="${C.ink}" stroke-width="1.6" stroke-dasharray="5 4"/>`;
    dots.trim().split(" ").forEach((pair) => {
      const [cx, cy] = pair.split(",");
      g += `<circle cx="${cx}" cy="${cy}" r="4.2" fill="${C.brass}" stroke="${C.ink}" stroke-width="1.3"/>`;
    });
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.3 });
    g += txt(l - 36, t + 7, "share", { size: 8, rotate: -90, anchor: "middle" });
    return frame(w, h, g, "Observed and Benford expected first-digit distribution");
  }

  function categoryBars(counts, probs, labels, opts = {}) {
    const w = 760, h = 304, l = 46, r = 14, t = 18, b = 40;
    const pw = w - l - r, ph = h - t - b;
    const n = counts.reduce((a, b2) => a + b2, 0) || 1;
    const obs = counts.map((v) => v / n);
    const ymax = Math.max(0.34, Math.ceil(Math.max(...obs, ...probs) * 1.12 * 10) / 10);
    const y = (v) => t + ph - (v / ymax) * ph;
    const step = pw / counts.length;
    const bw = step * 0.54;
    let g = "";
    for (let k = 0; k <= 4; k++) {
      const val = ymax * k / 4;
      g += line(l, y(val), w - r, y(val), { stroke: C.line, width: .8 });
      g += txt(l - 6, y(val) + 3, (val * 100).toFixed(0) + "%", { anchor: "end", size: 8 });
    }
    let dots = "";
    counts.forEach((c, i) => {
      const cx = l + (i + 0.5) * step;
      const dev = Math.abs(obs[i] - probs[i]);
      const col = dev <= 0.012 ? C.teal : dev <= 0.03 ? C.brass : C.oxide;
      g += `<g><title>${esc(labels[i])}: observed ${pct(obs[i], 1)}, expected ${pct(probs[i], 1)}</title>`;
      g += `<rect x="${cx - bw / 2}" y="${y(obs[i])}" width="${bw}" height="${(obs[i] / ymax) * ph}" fill="${col}" opacity=".24" stroke="${col}" stroke-width="1.5"/>`;
      g += `<rect x="${cx - bw / 2}" y="${y(obs[i])}" width="${bw}" height="4" fill="${col}" opacity=".9"/>`;
      g += `</g>`;
      g += txt(cx, h - 16, labels[i], { anchor: "middle", size: counts.length > 12 ? 6.6 : 10, weight: 700, fill: C.ink });
      dots += `${cx},${y(probs[i])} `;
    });
    g += `<polyline points="${dots.trim()}" fill="none" stroke="${C.ink}" stroke-width="1.5" stroke-dasharray="5 4"/>`;
    dots.trim().split(" ").forEach((p) => {
      const [cx, cy] = p.split(",");
      g += `<circle cx="${cx}" cy="${cy}" r="3.2" fill="${C.brass}" stroke="${C.ink}" stroke-width="1"/>`;
    });
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.2 });
    return frame(w, h, g, opts.title || "Observed and expected digit distribution");
  }

  function residualBars(residuals) {
    const w = 760, h = 150, l = 46, r = 14, t = 16, b = 26;
    const pw = w - l - r, ph = h - t - b;
    const maxA = Math.max(3, ...residuals.map((v) => Math.abs(v || 0)));
    const y0 = t + ph / 2;
    let g = line(l, y0, w - r, y0, { stroke: C.ink, width: 1.2 });
    g += line(l, t, w - r, t, { stroke: C.line, dash: "3 4" });
    g += line(l, t + ph, w - r, t + ph, { stroke: C.line, dash: "3 4" });
    g += txt(l - 6, t + 4, "+" + maxA.toFixed(0), { anchor: "end", size: 8 });
    g += txt(l - 6, t + ph + 4, "-" + maxA.toFixed(0), { anchor: "end", size: 8 });
    const bw = (pw / 9) * 0.5;
    residuals.forEach((v, i) => {
      const cx = l + (i + 0.5) * (pw / 9);
      const hh = Math.abs(v || 0) / maxA * (ph / 2);
      const col = Math.abs(v || 0) < 1.96 ? C.teal : Math.abs(v || 0) < 3 ? C.brass : C.oxide;
      g += `<rect x="${cx - bw / 2}" y="${v >= 0 ? y0 - hh : y0}" width="${bw}" height="${hh}" fill="${col}" opacity=".55" stroke="${col}" stroke-width="1"><title>Digit ${i + 1}: residual ${(v || 0).toFixed(2)}</title></rect>`;
      g += txt(cx, h - 8, String(i + 1), { anchor: "middle", size: 9, weight: 700 });
    });
    return frame(w, h, g, "Standardised Pearson residuals by first digit");
  }

  function firstTwoGrid(counts, probs, opts = {}) {
    const w = 760, h = 394, l = 36, r = 12, t = 32, b = 30;
    const cw = (w - l - r) / 10, ch = (h - t - b) / 9;
    const n = counts.reduce((a, b2) => a + b2, 0) || 1;
    const res = counts.map((c, i) => {
      const e = n * probs[i];
      return e > 0 ? (c - e) / Math.sqrt(e) : 0;
    });
    const maxA = Math.max(1.5, ...res.map(Math.abs));
    let g = "";
    g += txt(l + cw / 2, 14, "second digit", { anchor: "middle", size: 8.5, weight: 700 });
    for (let d2 = 0; d2 < 10; d2++) g += txt(l + (d2 + 0.5) * cw, t - 5, String(d2), { anchor: "middle", size: 8.5, weight: 700 });
    for (let d1 = 1; d1 <= 9; d1++) {
      for (let d2 = 0; d2 < 10; d2++) {
        const idx = (d1 - 1) * 10 + d2;
        const rr = res[idx];
        const t2 = Math.min(1, Math.abs(rr) / maxA);
        const col = rr >= 0 ? C.oxide : C.blue;
        const x = l + d2 * cw, y = t + (d1 - 1) * ch;
        const label = String(d1) + String(d2);
        g += `<g><title>${label}: observed ${counts[idx]}, expected ${(n * probs[idx]).toFixed(1)}, residual ${rr.toFixed(2)}</title>`;
        g += `<rect x="${x + 1}" y="${y + 1}" width="${cw - 2}" height="${ch - 2}" fill="${col}" fill-opacity="${0.06 + 0.64 * t2}" stroke="${C.line}" stroke-width=".6"/>`;
        g += txt(x + cw / 2, y + ch / 2 + 3, label, { anchor: "middle", size: 7.6, weight: 600, fill: t2 > 0.62 ? "#fffaf0" : C.ink3 });
        g += `</g>`;
      }
    }
    for (let d1 = 1; d1 <= 9; d1++) g += txt(l - 6, t + (d1 - 0.5) * ch + 3, String(d1), { anchor: "end", size: 8.5, weight: 700 });
    g += txt(12, t + (h - t - b) / 2, "first digit", { anchor: "middle", size: 8, rotate: -90, weight: 700 });
    g += txt(l, h - 8, "blue = below expected", { size: 8, fill: C.blue });
    g += txt(w - r, h - 8, "oxide = above expected", { size: 8, fill: C.oxide, anchor: "end" });
    return frame(w, h, g, "First-two-digit residual heat grid");
  }

  function madGauge(value, opts = {}) {
    const w = 360, h = 216, cx = 180, cy = 174, r = 126;
    const max = opts.max || 0.03;
    const bands = [
      { to: 0.006, color: C.teal, label: "close" },
      { to: 0.012, color: C.brass, label: "acceptable" },
      { to: 0.015, color: "#d58a3a", label: "marginal" },
      { to: max, color: C.oxide, label: "nonconformity" }
    ];
    const pol = (ang, rad) => {
      const a = Math.PI * (180 - ang) / 180;
      return [cx + rad * Math.cos(a), cy - rad * Math.sin(a)];
    };
    let g = "";
    let prev = 0;
    bands.forEach((band) => {
      const a1 = (prev / max) * 180, a2 = (band.to / max) * 180;
      const [x1, y1] = pol(a1, r), [x2, y2] = pol(a2, r);
      g += `<path d="M${x1} ${y1} A${r} ${r} 0 0 1 ${x2} ${y2}" fill="none" stroke="${band.color}" stroke-width="18" opacity=".82"/>`;
      const mid = (a1 + a2) / 2;
      const [tx, ty] = pol(mid, r + 17);
      g += txt(tx, ty + 3, band.label, { anchor: "middle", size: 6.6, fill: band.color, weight: 700 });
      prev = band.to;
    });
    for (let a = 0; a <= 180; a += 15) {
      const [x1, y1] = pol(a, r + 12), [x2, y2] = pol(a, r + (a % 45 === 0 ? 22 : 17));
      g += line(x1, y1, x2, y2, { stroke: C.ink, width: a % 45 === 0 ? 1.2 : 0.7, opacity: 0.55 });
    }
    for (let a = 0; a <= 180; a += 45) {
      const [tx, ty] = pol(a, r - 28);
      g += txt(tx, ty + 3, (max * a / 180).toFixed(3), { anchor: "middle", size: 6.5 });
    }
    const ang = Math.max(0, Math.min(180, (value / max) * 180));
    g += `<g transform="rotate(${ang} ${cx} ${cy})"><line x1="${cx}" y1="${cy}" x2="${cx - r + 16}" y2="${cy}" stroke="${C.ink}" stroke-width="3.4"/><polygon points="${cx - r + 7},${cy} ${cx - r + 19},${cy - 5} ${cx - r + 19},${cy + 5}" fill="${C.oxide}"/></g>`;
    g += `<circle cx="${cx}" cy="${cy}" r="8" fill="${C.ink}" stroke="${C.paper}" stroke-width="2"/>`;
    g += txt(cx, cy + 24, "MAD " + (value == null ? "—" : value.toFixed(4)), { anchor: "middle", size: 11, weight: 700, fill: C.ink });
    g += txt(cx, cy + 38, opts.band || "", { anchor: "middle", size: 8, fill: opts.bandColor || C.ink3 });
    return frame(w, h, g, "Mean absolute deviation gauge");
  }

  /* ------------------------------------------------------------- lines */
  function lineChart(labels, series, opts = {}) {
    const w = opts.width || 760, h = opts.height || 270;
    const l = 52, r = 16, t = 20, b = 42;
    const pw = w - l - r, ph = h - t - b;
    const all = series.flatMap((s) => s.values).filter((v) => isFinite(v));
    let lo = opts.min != null ? opts.min : Math.min(0, ...all);
    let hi = opts.max != null ? opts.max : Math.max(...all);
    if (!isFinite(lo) || !isFinite(hi)) { lo = 0; hi = 1; }
    if (hi === lo) hi = lo + 1;
    const pad = (hi - lo) * 0.08;
    if (opts.min == null && lo < 0) lo -= pad;
    if (opts.max == null) hi += pad;
    const x = (i) => l + (labels.length <= 1 ? pw / 2 : (i / (labels.length - 1)) * pw);
    const y = (v) => t + ph - ((v - lo) / (hi - lo)) * ph;
    let g = "";
    for (let k = 0; k <= 4; k++) {
      const v = lo + (hi - lo) * k / 4;
      const yy = y(v);
      g += line(l, yy, w - r, yy, { stroke: C.line, width: k === 0 ? 1.2 : 0.7 });
      g += txt(l - 7, yy + 3, opts.yFormat ? opts.yFormat(v) : compact(v), { anchor: "end", size: 8 });
    }
    const tickEvery = Math.max(1, Math.ceil(labels.length / 8));
    labels.forEach((lab, i) => {
      if (i % tickEvery !== 0 && i !== labels.length - 1) return;
      g += txt(x(i), h - 18, String(lab).slice(0, 12), { anchor: "middle", size: 7.5 });
    });
    if (opts.area && series[0]) {
      const pts = series[0].values.map((v, i) => `${x(i)},${y(v)}`).join(" ");
      g += `<polygon points="${l},${t + ph} ${pts} ${w - r},${t + ph}" fill="${series[0].color || C.teal}" opacity=".08"/>`;
    }
    series.forEach((s) => {
      const pts = s.values.map((v, i) => `${x(i)},${y(v)}`).join(" ");
      g += `<polyline points="${pts}" fill="none" stroke="${s.color || C.teal}" stroke-width="${s.width || 2}" ${s.dash ? `stroke-dasharray="${s.dash}"` : ""} stroke-linejoin="round"/>`;
      if (opts.points !== false) {
        s.values.forEach((v, i) => {
          if (!isFinite(v)) return;
          if (s.values.length > 40 && i % Math.ceil(s.values.length / 30) !== 0) return;
          g += `<circle cx="${x(i)}" cy="${y(v)}" r="2.3" fill="${s.color || C.teal}"/>`;
        });
      }
    });
    if (opts.markers) {
      opts.markers.forEach((mi) => {
        const s = series[0];
        if (!s || !isFinite(s.values[mi])) return;
        g += `<circle cx="${x(mi)}" cy="${y(s.values[mi])}" r="4.5" fill="${C.oxide}" stroke="${C.paper}" stroke-width="2"><title>${esc(labels[mi])}: flagged</title></circle>`;
      });
    }
    if (opts.vline != null) g += line(x(opts.vline), t, x(opts.vline), t + ph, { stroke: C.ink, width: 1, dash: "4 4" });
    if (opts.vlineLabel) g += txt(x(opts.vline), t - 6, opts.vlineLabel, { anchor: "middle", size: 7.5, fill: C.oxide });
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.2 });
    if (opts.yLabel) g += txt(13, t + ph / 2, opts.yLabel, { anchor: "middle", size: 8, rotate: -90 });
    return frame(w, h, g, opts.title || "line chart");
  }

  function histogram(edges, counts, opts = {}) {
    const w = opts.width || 760, h = opts.height || 250, l = 46, r = 16, t = 18, b = 42;
    const pw = w - l - r, ph = h - t - b;
    const maxC = Math.max(1, ...counts);
    const maxE = edges[0], maxX = edges[edges.length - 1];
    const x = (v) => l + ((v - maxE) / (maxX - maxE)) * pw;
    const y = (v) => t + ph - (v / maxC) * ph;
    let g = "";
    for (let k = 0; k <= 3; k++) {
      const v = maxC * k / 3;
      g += line(l, y(v), w - r, y(v), { stroke: C.line, width: 0.7 });
      g += txt(l - 6, y(v) + 3, compact(v), { anchor: "end", size: 7.5 });
    }
    counts.forEach((c, i) => {
      const x1 = x(edges[i]), x2 = x(edges[i + 1]);
      const inFence = opts.fences ? (edges[i] >= opts.fences[0] && edges[i + 1] <= opts.fences[1]) : true;
      g += `<rect x="${x1 + 1}" y="${y(c)}" width="${Math.max(1, x2 - x1 - 2)}" height="${t + ph - y(c)}" fill="${inFence ? C.teal : C.oxide}" opacity="${inFence ? 0.42 : 0.28}" stroke="${inFence ? C.teal : C.oxide}" stroke-width=".7"><title>${Math.pow(10, edges[i]).toPrecision(3)} to ${Math.pow(10, edges[i + 1]).toPrecision(3)}: ${c}</title></rect>`;
    });
    if (opts.fences) {
      opts.fences.forEach((f, i) => {
        if (f > maxE && f < maxX) {
          g += line(x(f), t, x(f), t + ph, { stroke: C.oxide, width: 1.4, dash: "5 4" });
          g += txt(x(f), t - 4, i === 0 ? "lower fence" : "upper fence", { anchor: "middle", size: 6.6, fill: C.oxide });
        }
      });
    }
    if (opts.marker != null && opts.marker > maxE && opts.marker < maxX) {
      g += line(x(opts.marker), t, x(opts.marker), t + ph, { stroke: C.ink, width: 2 });
      g += `<polygon points="${x(opts.marker)},${t} ${x(opts.marker) - 5},${t - 8} ${x(opts.marker) + 5},${t - 8}" fill="${C.ink}"/>`;
    }
    const ticks = 5;
    for (let k = 0; k <= ticks; k++) {
      const v = maxE + (maxX - maxE) * k / ticks;
      g += txt(x(v), h - 18, pow(v), { anchor: "middle", size: 8 });
    }
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.2 });
    g += txt(l, h - 3, opts.xLabel || "amount (log scale, base 10)", { size: 7.5 });
    return frame(w, h, g, opts.title || "Histogram on log scale");
  }

  function scoreHistogram(bins, opts = {}) {
    const w = 760, h = 170, l = 38, r = 12, t = 16, b = 32;
    const pw = w - l - r, ph = h - t - b;
    const maxC = Math.max(1, ...bins);
    let g = "";
    bins.forEach((c, i) => {
      const x = l + (i / bins.length) * pw;
      const bw = pw / bins.length - 3;
      const bh = (c / maxC) * ph;
      const col = i >= 6 ? C.oxide : i >= 3 ? C.brass : C.teal;
      g += `<rect x="${x + 1}" y="${t + ph - bh}" width="${bw}" height="${bh}" fill="${col}" opacity=".55" stroke="${col}" stroke-width=".8"><title>Priority ${i * 10}–${i * 10 + 9}: ${c} records</title></rect>`;
      g += txt(x + bw / 2, h - 16, String(i * 10), { anchor: "middle", size: 7.5 });
    });
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.1 });
    g += txt(l - 4, t + 4, compact(maxC), { anchor: "end", size: 7.5 });
    return frame(w, h, g, "Review priority distribution");
  }

  function rocCurve(roc, auc) {
    const w = 360, h = 300, l = 42, r = 12, t = 18, b = 38;
    const pw = w - l - r, ph = h - t - b;
    const x = (v) => l + v * pw, y = (v) => t + ph - v * ph;
    let g = "";
    for (let k = 0; k <= 4; k++) {
      g += line(l, y(k / 4), w - r, y(k / 4), { stroke: C.line, width: .7 });
      g += line(x(k / 4), t, x(k / 4), t + ph, { stroke: C.line, width: .7 });
    }
    g += line(l, t + ph, w - r, t, { stroke: C.ink3, dash: "4 4", width: 1 });
    const pts = (roc.fpr || []).map((v, i) => `${x(v)},${y((roc.tpr || [])[i])}`).join(" ");
    g += `<polyline points="${pts}" fill="none" stroke="${C.oxide}" stroke-width="2.2"/>`;
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.2 });
    g += line(l, t, l, t + ph, { stroke: C.ink, width: 1.2 });
    g += txt(l + pw / 2, h - 12, "false positive rate", { anchor: "middle", size: 8 });
    g += txt(13, t + ph / 2, "true positive rate", { anchor: "middle", size: 8, rotate: -90 });
    g += txt(w - r - 4, t + 12, "AUC " + (auc == null ? "—" : auc.toFixed(3)), { anchor: "end", size: 9, weight: 700, fill: C.oxide });
    return frame(w, h, g, "ROC curve");
  }

  function prCurve(pr, auc) {
    const w = 360, h = 300, l = 42, r = 12, t = 18, b = 38;
    const pw = w - l - r, ph = h - t - b;
    const x = (v) => l + v * pw, y = (v) => t + ph - v * ph;
    let g = "";
    for (let k = 0; k <= 4; k++) {
      g += line(l, y(k / 4), w - r, y(k / 4), { stroke: C.line, width: .7 });
      g += line(x(k / 4), t, x(k / 4), t + ph, { stroke: C.line, width: .7 });
    }
    const base = pr.baseline == null ? 0 : pr.baseline;
    g += line(l, y(base), w - r, y(base), { stroke: C.ink3, dash: "4 4", width: 1 });
    const pts = (pr.recall || []).map((v, i) => `${x(v)},${y((pr.precision || [])[i])}`).join(" ");
    g += `<polyline points="${pts}" fill="none" stroke="${C.teal}" stroke-width="2.2"/>`;
    g += line(l, t + ph, w - r, t + ph, { stroke: C.ink, width: 1.2 });
    g += line(l, t, l, t + ph, { stroke: C.ink, width: 1.2 });
    g += txt(l + pw / 2, h - 12, "recall", { anchor: "middle", size: 8 });
    g += txt(13, t + ph / 2, "precision", { anchor: "middle", size: 8, rotate: -90 });
    g += txt(w - r - 4, t + 12, "PR AUC " + (auc == null ? "—" : auc.toFixed(3)), { anchor: "end", size: 9, weight: 700, fill: C.teal });
    g += txt(w - r - 4, t + 25, "baseline " + (base * 100).toFixed(2) + "%", { anchor: "end", size: 7.5 });
    return frame(w, h, g, "Precision-recall curve");
  }

  function confusion(m) {
    const w = 360, h = 210, l = 78, t = 36, cw = 126, ch = 68;
    const c = (v) => nf(v);
    const cell = (x, y, val, label, fill) => `
      <rect x="${x}" y="${y}" width="${cw - 4}" height="${ch - 4}" fill="${fill}" opacity=".18" stroke="${fill}" stroke-width="1.2"/>
      ${txt(x + (cw - 4) / 2, y + 25, c(val), { anchor: "middle", size: 18, weight: 700, fill: C.ink })}
      ${txt(x + (cw - 4) / 2, y + 43, label, { anchor: "middle", size: 7.5, fill: C.ink3 })}`;
    let g = "";
    g += txt(l + cw, t - 9, "predicted genuine", { anchor: "middle", size: 7.5 });
    g += txt(l + 2 * cw, t - 9, "predicted fraud", { anchor: "middle", size: 7.5 });
    g += txt(l - 8, t + ch / 2, "genuine", { anchor: "end", size: 8, weight: 700 });
    g += txt(l - 8, t + ch + ch / 2, "fraud", { anchor: "end", size: 8, weight: 700 });
    g += cell(l, t, m.tn, "true negative", C.teal);
    g += cell(l + cw, t, m.fp, "false positive", C.oxide);
    g += cell(l, t + ch, m.fn, "false negative", C.brass);
    g += cell(l + cw, t + ch, m.tp, "true positive", C.teal);
    return frame(w, h, g, "Confusion matrix at the selected threshold");
  }

  function barsH(items, opts = {}) {
    const w = opts.width || 760;
    const rowH = 23;
    const h = Math.max(60, items.length * rowH + 22);
    const l = opts.labelWidth || 190, r = 64, t = 8, b = 14;
    const pw = w - l - r;
    const maxV = Math.max(...items.map((d) => Math.abs(d.value)), 0.000001);
    let g = "";
    items.forEach((d, i) => {
      const y = t + i * rowH;
      const bw = Math.max(1, Math.abs(d.value) / maxV * pw);
      const col = opts.colorFor ? opts.colorFor(d, i) : (d.color || C.teal);
      g += txt(l - 8, y + 12, esc(d.label).slice(0, opts.labelChars || 30), { anchor: "end", size: 9, fill: C.ink, weight: 500 });
      g += `<rect x="${l}" y="${y + 3}" width="${pw}" height="${rowH - 9}" fill="${C.line}" opacity=".22"/>`;
      g += `<rect x="${l}" y="${y + 3}" width="${bw}" height="${rowH - 9}" fill="${col}" opacity=".7" stroke="${col}" stroke-width=".6"><title>${esc(d.label)}: ${d.display || d.value}</title></rect>`;
      g += txt(l + bw + 5, y + 12, d.display || compact(d.value), { size: 8, fill: C.ink3 });
    });
    return frame(w, h, g, opts.title || "Horizontal bar chart");
  }

  function sparkline(values, opts = {}) {
    const w = opts.width || 120, h = opts.height || 32;
    const vals = values.filter((v) => isFinite(v));
    if (!vals.length) return `<svg viewBox="0 0 ${w} ${h}"></svg>`;
    const lo = Math.min(...vals), hi = Math.max(...vals);
    const x = (i) => 2 + i / Math.max(1, values.length - 1) * (w - 4);
    const y = (v) => h - 3 - ((v - lo) / Math.max(1e-9, hi - lo)) * (h - 6);
    const pts = values.map((v, i) => `${x(i)},${y(v)}`).join(" ");
    return `<svg viewBox="0 0 ${w} ${h}" aria-hidden="true"><polyline points="${pts}" fill="none" stroke="${opts.color || C.teal}" stroke-width="1.5"/></svg>`;
  }

  function stackedBars(items, opts = {}) {
    const w = opts.width || 760, h = 200, l = 110, r = 40, t = 12, b = 24;
    const pw = w - l - r, rowH = (h - t - b) / Math.max(1, items.length);
    const total = items.reduce((a, d) => a + d.value, 0) || 1;
    let g = "";
    items.forEach((d, i) => {
      const y = t + i * rowH;
      const bw = (d.value / total) * pw;
      g += txt(l - 8, y + rowH / 2 + 3, esc(d.label), { anchor: "end", size: 8.5, fill: C.ink });
      g += `<rect x="${l}" y="${y + 4}" width="${bw}" height="${rowH - 9}" fill="${d.color || C.teal}" opacity=".55" stroke="${d.color || C.teal}" stroke-width=".7"><title>${esc(d.label)}: ${d.value} (${(100 * d.value / total).toFixed(1)}%)</title></rect>`;
      g += txt(l + bw + 5, y + rowH / 2 + 3, (100 * d.value / total).toFixed(1) + "%", { size: 8 });
    });
    return frame(w, h, g, opts.title || "Composition");
  }

  window.KitCharts = {
    C, esc, nf, compact, money, pct, pow, frame, txt, line,
    benfordBars, categoryBars, residualBars, firstTwoGrid, madGauge,
    lineChart, histogram, scoreHistogram, rocCurve, prCurve, confusion, barsH,
    sparkline, stackedBars
  };
})();
