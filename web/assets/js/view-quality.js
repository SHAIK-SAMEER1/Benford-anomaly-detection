/* Instrument 03 — The Caliper */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.quality = {
    html() {
      const K = window.Kit, d = K.active(), q = d.quality || {}, s = d.suitability || {};
      const schema = (d.schema || []).slice().sort((a, b) => (b.missingPct || 0) - (a.missingPct || 0)).slice(0, 12);
      const maxMiss = Math.max(0.01, ...schema.map((x) => x.missingPct || 0));
      const groups = d.groups && d.groups.first ? d.groups.first.slice(0, 12) : [];
      const eligible = d.measure ? d.measure.n : 0;
      const excluded = Math.max(0, (q.rows || d.rows) - eligible);
      const bars = [
        { label: "input rows", value: d.rows, color: "var(--ink-3)" },
        { label: "numeric amount", value: (q.rows || d.rows) - (q.missingAmount || 0), color: "var(--teal)" },
        { label: "positive", value: eligible, color: "var(--teal)" },
        { label: "zero / non-positive", value: excluded, color: "var(--brass)" }
      ];
      const maxBar = Math.max(...bars.map((b) => b.value), 1);
      const caveats = [];
      if (q.zeroAmounts) caveats.push(`${K.fmt(q.zeroAmounts)} zero amounts are retained and excluded from digit extraction.`);
      if (q.negativeAmounts) caveats.push(`${K.fmt(q.negativeAmounts)} negative values are retained; they are analysed by magnitude only where the dataset policy allows, and never silently converted to positive spending.`);
      if (q.duplicateRows) caveats.push(`${K.fmt(q.duplicateRows)} exact duplicate rows (${(q.duplicateRowPct || 0).toFixed(1)}%) — retained in the source, reported separately.`);
      if (q.signatureDuplicates) caveats.push(`${K.fmt(q.signatureDuplicates)} repeated transaction signatures. A repeat can be legitimate; it is a review candidate, not a classification.`);
      if (q.missingCustomersPct) caveats.push(`${q.missingCustomersPct.toFixed(1)}% of retail lines have no customer identifier, so customer-level peer comparison is not attempted.`);
      if (q.cancellations) caveats.push(`${K.fmt(q.cancellations)} invoice lines carry a cancellation marker. Cancellation is an accounting state, not a fraud label.`);
      if (d.kind === "labelled") caveats.push("Labels are benchmark outcomes used only for held-out model evaluation; they are never used as transaction-level anomaly evidence.");
      if (d.kind === "unlabelled") caveats.push("No outcome label exists. The kit therefore reports screening candidates and their reasons, not accuracy or fraud probabilities.");
      if (!caveats.length) caveats.push("No additional caveat was recorded for this dataset.");

      return `<div class="view">
        ${K.pageHead("03", "Quality & suitability", `Before the test, <em style="color:var(--oxide)">the gate.</em>`,
          `A chi-square statistic is meaningless if the sample or expected counts cannot support it. This instrument records what was missing, what was excluded, which groups are large enough, and whether Benford is the right reference at all.`,
          `<span class="stamp ${s.verdict === "Suitable" ? "ok" : ""}">${K.esc(s.verdict || "Not assessed")}</span>`)}
        <div class="stat-strip">
          ${K.stat("Rows", K.fmt(q.rows || d.rows), K.esc(d.file))}
          ${K.stat("Missing cells", q.missingPct == null ? "—" : q.missingPct.toFixed(2) + "%", K.fmt(q.missingCells) + " of " + K.fmt(q.cells))}
          ${K.stat("Eligible values", K.fmt(eligible), "positive, finite, non-zero")}
          ${K.stat("Excluded from digits", K.fmt(excluded), "counted, not deleted")}
          ${K.stat("Duplicate rows", K.fmt(q.duplicateRows), q.duplicateRowPct == null ? "" : q.duplicateRowPct.toFixed(2) + "%")}
          ${K.stat("Repeated signatures", K.fmt(q.signatureDuplicates), "duplicate evidence only")}
        </div>

        <div class="grid split" style="margin-top:18px;align-items:start">
          <section class="panel tape brass-edge">
            <div class="section-title" style="margin-top:0"><h3>Suitability screen</h3><span class="note">${K.esc(s.label || "measure")}</span></div>
            <div style="display:flex;gap:12px;flex-wrap:wrap;align-items:center;margin-bottom:12px">
              ${K.verdictChip(s.verdict || "Not assessed")}
              <span class="chip ghost">N ${K.fmt(s.n)}</span>
              <span class="chip ghost">range ${s.rangeOrders == null ? "—" : Number(s.rangeOrders).toFixed(2)} orders</span>
              <span class="chip ghost">unique ${s.uniqueShare == null ? "—" : (100 * s.uniqueShare).toFixed(0) + "%"}</span>
            </div>
            <div class="grid" style="gap:7px">
              ${(s.checks || []).map((c) => `<div class="note-card ${c.ok ? "teal" : "oxide"}" style="display:flex;gap:10px;align-items:flex-start">
                <span class="mono" style="font-weight:700">${c.ok ? "PASS" : "HOLD"}</span>
                <span><b>${K.esc(c.key)}.</b> ${K.esc(c.detail)}</span></div>`).join("") || `<div class="empty">No suitability screen was supplied.</div>`}
            </div>
            <div class="note-card" style="margin-top:12px">Benford gates used here: first and second digit require N ≥ 110 so every expected count can reach 5; first-two-digit requires N ≈ 1,150 for all 90 categories. The actual expected counts are checked, not just the sample size.</div>
          </section>

          <section class="panel">
            <div class="section-title" style="margin-top:0"><h3>Missingness, by field</h3><span class="note">top 12</span></div>
            <div class="bar-list">
              ${schema.map((x) => `<div class="bar-row"><span class="bar-label" title="${K.esc(x.name)}">${K.esc(x.name)}</span>
                <span class="bar-track"><span class="bar-fill ${x.role === "measure" ? "oxide" : ""}" style="width:${Math.max(1, 100 * (x.missingPct || 0) / maxMiss)}%"></span></span>
                <span class="bar-val">${x.missingPct == null ? "—" : x.missingPct.toFixed(1) + "%"}</span></div>`).join("") || `<div class="empty">No schema entries.</div>`}
            </div>
            <hr class="rule">
            <p class="caption">A missing count is not a quality failure by itself. It matters when it removes a group identifier, an amount, or a date that the screening needs. Every exclusion is counted in the export.</p>
          </section>
        </div>

        <div class="grid split-rev" style="margin-top:18px;align-items:start">
          <section class="panel tight">
            <div class="section-title" style="margin-top:0"><h3>Record accounting</h3><span class="note">source → eligible</span></div>
            <div class="bar-list" style="padding:4px 2px">
              ${bars.map((b) => `<div class="bar-row"><span class="bar-label">${K.esc(b.label)}</span>
                <span class="bar-track"><span class="bar-fill" style="background:${b.color};width:${100 * b.value / maxBar}%"></span></span>
                <span class="bar-val">${K.fmt(b.value)}</span></div>`).join("")}
            </div>
            <div class="grid two" style="margin-top:12px">
              ${K.stat("Positive", K.fmt(q.positiveAmounts), "used for digit tests")}
              ${K.stat("Zero", K.fmt(q.zeroAmounts), "excluded from digits")}
              ${K.stat("Negative", K.fmt(q.negativeAmounts), "sign preserved")}
              ${K.stat("ID duplicates", K.fmt(q.idDuplicates), "exact identifier repeats")}
            </div>
          </section>
          <section class="panel">
            <div class="section-title" style="margin-top:0"><h3>Group eligibility</h3><span class="note">first-digit tests</span></div>
            <div class="table-wrap" style="max-height:340px">
              <table class="data compact"><thead><tr><th>Group</th><th class="r">N</th><th class="r">MAD</th><th>Validity</th><th>Gate</th></tr></thead>
                <tbody>${groups.map((g) => `<tr><td class="strong">${K.esc(g.group)}</td><td class="r">${K.fmt(g.n)}</td><td class="r">${g.mad == null ? "—" : Number(g.mad).toFixed(4)}</td><td>${K.tierChip(g.tier)}</td><td>${g.n >= 110 ? `<span class="chip ghost">eligible</span>` : `<span class="chip oxide">too small</span>`}</td></tr>`).join("") || `<tr><td colspan="5" class="muted">No group tests.</td></tr>`}</tbody>
              </table>
            </div>
            <p class="caption" style="margin-top:8px">Groups below 110 observations are labelled insufficient; they are never called anomalous merely because no test was possible.</p>
          </section>
        </div>

        <section class="panel oxide-edge" style="margin-top:18px">
          <div class="section-title" style="margin-top:0"><h3>Data-quality caveats</h3><span class="note">read before interpreting any flag</span></div>
          <div class="grid two">${caveats.map((c) => `<div class="note-card">${K.esc(c)}</div>`).join("")}</div>
          <div class="note-card oxide" style="margin-top:12px"><b>Boundary.</b> ${K.esc(K.D.method.boundary)}</div>
        </section>

        <div style="display:flex;justify-content:space-between;gap:10px;margin-top:22px">
          <button class="btn" type="button" data-route="data">← Data desk</button>
          <button class="btn primary" type="button" data-route="benford">Open the ruler →</button>
        </div>
      </div>`;
    },
    bind() {}
  };
})();
