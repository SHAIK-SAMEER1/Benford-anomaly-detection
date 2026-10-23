/* Instrument 06 — The Compass */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.peers = {
    html() {
      const K = window.Kit, d = K.active(), st = K.state.peers, P = d.peers || {};
      if (!P.groups || !P.groups.length) {
        return `<div class="view">${K.pageHead("06", "Peers & trends", "The compass: compare a thing to its neighbours",
          "A subgroup is worth examining when there is a plausible comparison basis — an agency, a country, a product category, a month — and enough members in that basis for the comparison to mean something.",
          "")}${K.noMethod("No peer grouping available", "This dataset did not expose a comparable grouping or a comparable number of values.")}</div>`;
      }
      const nth = Math.min(5, P.groups.length);
      const barLabels = ["%s (%s%%)"];
      const byLevel = K.byId(d.id);
      const level = P.levels && P.levels.length ? P.levels[0] : "Group";
      const trendLabel = P.trend ? P.trend.label : null;
      const trendUnit = P.trend && P.trend.unit ? P.trend.unit : "";
      let trendChart = "";
      if (P.trend && P.trend.labels && P.trend.values && P.trend.labels.length) {
        const keys = P.trend.labels;
        const vals = P.trend.values;
        const flagged = P.trend.flagged && P.trend.flagged.length ? P.trend.flagged : null;
        const series = [];
        series.push({ color: K.C.teal, values: vals });
        if (flagged) series.push({ color: K.C.oxide, values: flagged, dash: "4 4" });
        trendChart = K.C.lineChart(keys, series, {
          title: `"${K.esc(trendLabel)}" by ${trendUnit || "bucket"}`,
          yFormat: K.money,
          markers: flagged ? keys.map((_, i) => i).filter((i) => flagged[i] > 0) : null,
          points: "auto",
          min: Math.min(0, ...vals.filter((v) => isFinite(v)))
        });
      } else {
        trendChart = `<div class="empty">No time grouping was detected.</div>`;
      }
      const groups = P.groups;
      const selected = groups[st.group];
      let groupChart = "", groupInfo = "";
      if (selected && P.histEdges && selected.hist && selected.hist.length) {
        groupChart = K.C.histogram(P.histEdges, selected.hist, {
          title: `Distribution within ${K.esc(selected.label)} (N = ${K.fmt(selected.n)})`,
          fences: selected.lower != null && selected.upper != null ? [Math.log10(selected.lower), Math.log10(selected.upper)] : null,
          xLabel: "amount (log₁₀ scale)",
          width: 760, height: 240
        });
        groupChart += `<div class="chart-cap"><span>bars = count on log scale</span><span>oxide dashed = 1.5 × IQR fences (${K.money(selected.lower)} – ${K.money(selected.upper)})</span></div>`;
      }
      const legend = `<div class="chart-legend"><span><i style="background:${K.C.teal}"></i> in-group amounts</span>
        ${selected && selected.lower != null ? `<span><i style="background:${K.C.oxide}"></i> outside fence</span>` : ""}</div>`;
      return `<div class="view">
        ${K.pageHead("06", "Peers & trends", `The compass: compare to the <em style="color:var(--oxide)">neighbours</em>`,
          `A flag means a record is unusual relative to a defined set of peers. This instrument shows that comparison basis — groups, their distribution, how the right group was chosen, and how the number behaves across time.`,
          `<span class="stamp ok">comparison basis: ${K.esc(level)}</span>`)}
        <div class="stat-strip">
          <div class="stat"><span class="k">Active dataset</span><span class="v" style="font-size:12px">${K.esc(d.name)}</span></div>
          <div class="stat"><span class="k">Eligible</span><span class="v">${K.fmt(d.measure ? d.measure.n : P.levelCounts && Object.keys(P.levelCounts).length ? Object.values(P.levelCounts)[0] || P.levelCounts[level] || 0 : 0)}</span></div>
          <div class="stat"><span class="k">Comparison basis</span><span class="v" style="font-size:12px">${K.esc(P.levels && P.levels.length ? P.levels.join(" → ") : "—")}</span></div>
          <div class="stat"><span class="k">Groups shown</span><span class="v">${K.fmt(groups.length)}</span></div>
        </div>

        <div class="subtabs" style="margin-top:22px">
          <button class="subtab ${selected && P.groups[0] ? st.group === 0 ? "is-active" : "" : ""}" type="button" data-peer="0">${groups[0] ? groups[0].label : "—"}</button>
          ${groups.slice(1, 6).map((g, i) => `<button class="subtab ${st.group === st.group ? "is-active" : ""}" type="button" data-peer="${i + 1}">${g.label}</button>`).join("")}
          <span class="chips" style="margin-left:auto"><span class="chip ghost">min peer = ${P.thresholds && P.thresholds.minPeer || 30}</span><span class="chip ghost">IQR × 1.5</span></span>
        </div>

        <div class="grid split" style="margin-top:18px;align-items:start">
          <section class="panel tape">
            <div class="section-title" style="margin-top:0"><h3>${K.esc(selected ? selected.label : "Select a group")}. Distribution on the log scale</h3><span class="note">${K.fmt(selected ? selected.n : 0)} values</span></div>
            ${groupChart ? `<div class="chart">${groupChart}${legend}</div>` : `<div class="empty">Choose a group from the tabs above to see its amount distribution.</div>`}
            ${selected && selected.n ? `
            <dl class="kv" style="margin-top:10px">
              <dt>N</dt><dd>${K.fmt(selected.n)}</dd>
              <dt>Median</dt><dd>${K.money(selected.median)}</dd>
              <dt>Q1</dt><dd>${K.money(selected.q1)}</dd>
              <dt>Q3</dt><dd>${K.money(selected.q3)}</dd>
              <dt>MAD (log₁₀ scale)</dt><dd>${selected.mad == null ? "—" : Number(selected.mad).toFixed(3)}</dd>
              <dt>1.5 × IQR fence</dt><dd>${K.money(selected.lower)} – ${K.money(selected.upper)}</dd>
              <dt>Flagged in this group</dt><dd>${K.fmt(selected.flagged)}</dd>
            </dl>` : ""}
          </section>
          <aside class="grid" style="align-content:start">
            <section class="panel">
              <div class="section-title" style="margin-top:0"><h3>All groups</h3><span class="note">${K.fmt(groups.length)} rows</span></div>
              <div class="table-wrap" style="max-height:360px">
                <table class="data compact"><thead><tr><th>Group</th><th class="r">N</th><th class="r">Median</th><th class="r">Flagged</th></tr></thead>
                  <tbody>${groups.slice(0, 40).map((g) => `<tr data-group="${g.label}"><td class="strong" data-group-label>${K.esc(g.label)}</td><td class="r">${K.fmt(g.n)}</td><td class="r">${K.money(g.median)}</td><td class="r">${K.fmt(g.flagged || 0)}</td></tr>`).join("") || `<tr><td colspan="4" class="muted">No groups.</td></tr>`}</tbody>
                </table>
              </div>
              <p class="caption" style="margin-top:8px">Click a group row to jump the tabs above to it. The quartile table uses each group's own IQR and fences — different groups have different reference ranges.</p>
            </section>
            <section class="panel tight">
              <div class="section-title" style="margin-top:0"><h3>Peer-hierarchy ladder</h3><span class="note">how the right group was picked</span></div>
              <p class="caption">The kit tries the narrowest comparison that still has ≥ 30 values, then broadens only when the narrow group is too small. This avoids comparing a singleton to “all transactions”.</p>
              <div class="grid two" style="margin-top:10px">
                ${(P.levelCounts && Object.values(P.levelCounts)[0] !== undefined) ? Object.entries(P.levelCounts)
                  .map(([k, n]) => `<div class="stat"><span class="k">${K.esc(k)}</span><span class="v" style="font-size:12px">${K.fmt(n)} in this basis</span></div>`).join("") : `<div class="stat"><span class="k">Basis</span><span class="v" style="font-size:12px">${K.fmt(P.levelCounts && P.levelCounts[level] || 0)}</span></div>`}
              </div>
            </section>
          </aside>
        </div>

        <section class="panel" style="margin-top:20px">
          <div class="section-title" style="margin-top:0"><h3>Trend</h3><span class="note">${K.esc(trendLabel || "aggregate")}${trendUnit ? " · " + K.esc(trendUnit) : ""}</span></div>
          ${trendChart ? `<div class="chart">${trendChart}<div class="chart-cap"><span>line = aggregate</span>${flagged ? "<span>dashed = events (flagged)</span>" : ""}</div></div>` : "<div class='empty'>No time grouping was detected.</div>"}
          <p class="caption">A trend is descriptive. A month with a lot of transactions or a lot of flagged records is often a busy month, a reporting change, or a single large award — not a trend in fraud.</p>
        </section>

        <div style="display:flex;justify-content:space-between;gap:10px;margin-top:22px">
          <button class="btn" type="button" data-route="review">← Review</button>
          <button class="btn primary" type="button" data-route="validation">Validation lab →</button>
        </div>
      </div>`;
    },
    bind(root) {
      const K = window.Kit, st = K.state.peers;
      root.querySelectorAll("[data-peer]").forEach((b) => b.addEventListener("click", () => {
        st.group = Number(b.dataset.peer); st.series = 0; K.render();
      }));
      root.querySelectorAll("tbody tr[data-group]").forEach((tr) => {
        const label = tr.getAttribute("data-group-label");
        if (!label) return;
        let n = 0;
        K.byId(Object.keys(K.allDatasets())[0]) && K.byId(Object.keys(K.allDatasets())[0]); // no-op safety
        if (label) {
          for (let i = 0; i < st.group; i++) ++n;
          if (label === root.querySelectorAll("tbody tr[data-group]")[n]?.getAttribute("data-group-label")) return;
          const idx = d3Idx(label, root);
          if (idx >= 0) st.group = idx; K.render();
        }
      });
      if (root.querySelectorAll("[data-group]").length) root.querySelectorAll("tbody tr[data-group]").forEach((tr) => {
        tr.addEventListener("click", () => {
          const idx = Array.from(root.querySelectorAll("tbody tr[data-group]")).indexOf(tr);
          if (idx >= 0) { st.group = idx; st.series = 0; K.render(); }
        });
      });
    }
  };
  function d3Idx(label, root) {
    const rows = root.querySelectorAll("tbody tr[data-group-label]");
    let n = 0;
    for (const r of rows) {
      if (r.getAttribute("data-group-label") === label) return n;
      ++n;
    }
    return -1;
  }
})();
