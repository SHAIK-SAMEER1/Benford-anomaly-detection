/* Instrument 04 — The Ruler */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  const KIND_META = {
    first: { label: "First digit", gate: 110, note: "9 categories · df = 8" },
    first2: { label: "First two digits", gate: 1150, note: "90 categories · df = 89" },
    second: { label: "Second digit", gate: 110, note: "10 categories · df = 9" }
  };
  function withAdjusted(groups, method) {
    const A = window.KitAnalysis;
    const out = groups.map((g) => Object.assign({}, g));
    const fams = new Map();
    groups.forEach((g, i) => {
      const f = g.family || "family";
      if (!fams.has(f)) fams.set(f, []);
      fams.get(f).push({ i, p: g.p });
    });
    fams.forEach((arr, fam) => {
      const adj = A.pAdjust(arr.map((x) => x.p), method);
      arr.forEach((x, j) => {
        out[x.i].pAdj = method === "raw" ? x.p : adj[j];
        out[x.i].familySize = arr.length;
        out[x.i].familyLabel = fam;
        out[x.i]._index = x.i;
      });
    });
    return out;
  }
  function groupDecision(g, alpha, kind) {
    if (!g || g.tier === "Not run" || g.pAdj == null) return "Not assessed - insufficient sample";
    if (g.pAdj >= alpha) return "No significant deviation detected";
    if (kind === "first" && g.mad != null && g.mad <= 0.006) return "Statistically significant but small deviation";
    return "Statistical deviation: significant AND practically material";
  }
  function groupStamp(g) {
    if (!g || g.tier === "Not run" || g.pAdj == null) return `<span class="chip ghost">not assessed</span>`;
    if (g.pAdj < 0.05) return `<span class="chip oxide">adjusted p < .05</span>`;
    return `<span class="chip ghost">no signal</span>`;
  }

  window.KitViews.benford = {
    html() {
      const K = window.Kit, d = K.active(), st = K.state.benford, C = K.C;
      const kind = st.kind, bt = d.benford ? d.benford[kind] : null;
      if (!bt) return `<div class="view">${K.pageHead("04", "Benford screening", "The ruler", "No digit result was supplied for this dataset.", "")}${K.noMethod("No Benford result", "This dataset does not expose a usable numerical measure.")}</div>`;
      const meta = KIND_META[kind];
      const alpha = st.alpha;
      const groupsAll = (d.groups && d.groups[kind]) || [];
      const adjustedAll = withAdjusted(groupsAll, st.adjust);
      const families = Array.from(new Set(adjustedAll.map((g) => g.family)));
      const shown = adjustedAll.filter((g) => st.family === "all" || g.family === st.family);
      const sig = bt.p != null && bt.p < alpha;
      const material = sig && bt.mad != null && bt.mad > 0.006;
      const stamp = bt.tier === "Not run" ? "Not assessed" : sig ? (material ? "Material deviation" : "Significant, small") : "No significant deviation";
      const stampCls = bt.tier === "Not run" ? "" : sig ? (material ? "" : "ok") : "ok";
      const minN = meta.gate;
      let chart = "", extra = "";
      if (kind === "first") {
        chart = C.benfordBars(bt.counts, bt.probs, { highlight: st.digit, showValues: true });
        extra = `<section class="panel tape" style="margin-top:16px">
          <div class="section-title" style="margin-top:0"><h3>Digit inspector</h3><span class="note">one category at a time</span></div>
          <div class="digit-list">${bt.probs.map((p, i) => `<button class="digit-btn ${st.digit === i + 1 ? "is-active" : ""}" type="button" data-digit="${i + 1}">${i + 1}</button>`).join("")}</div>
          <div class="grid three" style="margin-top:12px">
            ${K.stat("P(d)", (bt.probs[st.digit - 1] * 100).toFixed(2) + "%", "log₁₀(1 + 1/" + st.digit + ")")}
            ${K.stat("Observed", bt.N ? (100 * bt.counts[st.digit - 1] / bt.N).toFixed(2) + "%" : "—", K.fmt(bt.counts[st.digit - 1]) + " records")}
            ${K.stat("Standardised residual", bt.residuals[st.digit - 1] == null ? "—" : Number(bt.residuals[st.digit - 1]).toFixed(2), Math.abs(bt.residuals[st.digit - 1]) > 1.96 ? "outside ±1.96" : "inside ±1.96", Math.abs(bt.residuals[st.digit - 1]) > 1.96 ? "accent" : "good")}
          </div>
          <p class="caption" style="margin-top:10px">The inspector is descriptive. One category being high or low does not create 9 independent tests; the chi-square test and the adjusted group table carry the inferential weight.</p>
        </section>
        <div class="chart" style="margin-top:16px">${C.residualBars(bt.residuals)}<div class="chart-cap"><span>standardised Pearson residuals</span><span>±1.96 reference · bar colour darkens with distance</span></div></div>`;
      } else if (kind === "first2") {
        chart = C.firstTwoGrid(bt.counts, bt.probs, {});
        extra = `<div class="note-card" style="margin-top:12px"><b>Extended digits.</b> A first-two-digit test has 90 categories. It needs roughly 1,150 eligible values before every expected count can reach 5; with ${K.fmt(bt.N)} values this test is <b>${K.esc(bt.tier)}</b>. The heat grid is descriptive and should not be read as 90 separate evidence items.</div>`;
      } else {
        chart = C.categoryBars(bt.counts, bt.probs, ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"], { title: "Second-digit distribution" });
        extra = `<div class="note-card" style="margin-top:12px"><b>Second digit.</b> This tests positions two of the mantissa. It is not a replacement for the first-digit test and is not used as an independent transaction-level signal.</div>`;
      }
      const countsNote = `${K.fmt(bt.N)} eligible values · minimum gate ${K.fmt(minN)}`;

      return `<div class="view">
        ${K.pageHead("04", "Benford screening", `The ruler: <em style="color:var(--oxide)">does the group keep the promise?</em>`,
          `Observed leading digits against P(d) = log₁₀(1 + 1/d). Every test carries its validity tier, MAD and effect size. Extended digits live here as a sub-instrument, not as another page.`,
          `<span class="stamp ${stampCls}">${K.esc(stamp)}</span>`)}
        <div class="stat-strip">
          ${K.stat("N eligible", K.fmt(bt.N), K.esc(d.measure ? d.measure.label : "measure"))}
          ${K.stat("Chi-square", bt.chi2 == null ? "—" : Number(bt.chi2).toFixed(2), "df " + bt.df)}
          ${K.stat("p-value", K.pval(bt.p), "alpha " + alpha)}
          ${K.stat("Validity", bt.tier, bt.min_E == null ? "" : "min expected " + Number(bt.min_E).toFixed(1))}
          ${K.stat("MAD", bt.mad == null ? "—" : Number(bt.mad).toFixed(4), bt.band || "first-digit bands only")}
          ${K.stat("Cohen's w", bt.cohen_w == null ? "—" : Number(bt.cohen_w).toFixed(3), "effect size")}
        </div>

        <div class="subtabs" style="margin-top:22px">
          ${Object.entries(KIND_META).map(([k, m]) => `<button class="subtab ${kind === k ? "is-active" : ""}" type="button" data-kind="${k}">${m.label}<span class="badge">${d.groups && d.groups[k] ? d.groups[k].length : 0}</span></button>`).join("")}
        </div>

        <div class="grid split" style="align-items:start">
          <section class="panel tape">
            <div class="section-title" style="margin-top:0"><h3>${K.esc(meta.label)} distribution</h3><span class="note">${countsNote}</span></div>
            <div class="chart">${chart}
              <div class="chart-cap"><span>bars = observed · dashed line &amp; brass dots = Benford</span><span>${meta.note}</span></div>
            </div>
            <div class="kit-stamp-row">
              <span class="chip ${bt.tier === "Reliable" ? "teal" : bt.tier === "Caution" ? "brass" : "oxide"}">${K.esc(bt.tier)}</span>
              <span class="chip ghost">min expected ${bt.min_E == null ? "—" : Number(bt.min_E).toFixed(1)}</span>
              <span class="chip ghost">alpha ${alpha}</span>
              <span class="chip ghost">${sig ? "reject H₀" : "fail to reject H₀"}</span>
            </div>
            <p class="caption">${K.esc(bt.decision || "")}</p>
            <div class="note-card ${sig ? "oxide" : "teal"}" style="margin-top:10px"><b>${sig ? "What this does not mean." : "What this means."}</b>
              ${sig ? "A significant chi-square says the digit pattern is unusual given the reference. It does not say which record, which person, or which intent. With a very large N, tiny and practically irrelevant gaps become significant — hence MAD and group-level validity." : "No significant departure was detected at the selected alpha. This is not proof of honesty; it means this test did not find a digit-pattern signal."}</div>
          </section>
          <aside class="grid" style="align-content:start">
            <section class="panel tight">
              <p class="eyebrow">Test settings</p>
              <div class="field"><label for="bfAlpha">Significance alpha</label>
                <select id="bfAlpha"><option value="0.01" ${alpha === 0.01 ? "selected" : ""}>0.01</option><option value="0.05" ${alpha === 0.05 ? "selected" : ""}>0.05</option><option value="0.10" ${alpha === 0.10 ? "selected" : ""}>0.10</option></select></div>
              <div class="field"><label for="bfAdjust">Multiple-testing method</label>
                <select id="bfAdjust">
                  <option value="bh" ${st.adjust === "bh" ? "selected" : ""}>Benjamini–Hochberg</option>
                  <option value="holm" ${st.adjust === "holm" ? "selected" : ""}>Holm</option>
                  <option value="raw" ${st.adjust === "raw" ? "selected" : ""}>Raw p (for display)</option>
                </select></div>
              <div class="field"><label for="bfFamily">Family filter</label>
                <select id="bfFamily"><option value="all">All declared families</option>${families.map((f) => `<option value="${K.esc(f)}" ${st.family === f ? "selected" : ""}>${K.esc(f)}</option>`).join("")}</select></div>
              <p class="caption">Adjustment is applied inside each declared family, not across the whole table after looking at results.</p>
            </section>
            <section class="panel">
              <p class="eyebrow">Validity gate</p>
              <div class="note-card ${bt.tier === "Not run" ? "oxide" : bt.tier === "Caution" ? "" : "teal"}">
                <b>${K.esc(bt.tier)}.</b> ${K.esc(bt.note || "")}
              </div>
              <dl class="kv" style="margin-top:10px">
                <dt>Minimum N</dt><dd>${K.fmt(minN)}</dd>
                <dt>Cells with E &lt; 5</dt><dd>${bt.pct_E_lt5 == null ? "—" : (100 * bt.pct_E_lt5).toFixed(1) + "%"}</dd>
                <dt>Minimum expected</dt><dd>${bt.min_E == null ? "—" : Number(bt.min_E).toFixed(2)}</dd>
                <dt>Groups tested</dt><dd>${K.fmt(groupsAll.length)}</dd>
              </dl>
            </section>
            <section class="panel tight">
              <p class="eyebrow">Interpretation</p>
              <p class="caption">The chi-square p-value is computed only when the expected-count condition is met. When the tier is “Not run”, the kit suppresses the p-value and says so; it does not call the group anomalous.</p>
            </section>
          </aside>
        </div>

        ${extra}

        <section class="panel" style="margin-top:20px">
          <div class="section-title" style="margin-top:0"><h3>Group-level tests</h3><span class="note">${K.fmt(shown.length)} of ${K.fmt(groupsAll.length)} groups · ${K.esc(st.adjust === "raw" ? "raw p" : st.adjust === "holm" ? "Holm" : "BH")} inside family</span></div>
          <div class="filters">
            <span class="chip ghost">${K.esc(meta.label)}</span>
            <span class="chip ghost">min N ${K.fmt(minN)}</span>
            <span class="count">${K.fmt(shown.filter((g) => g.tier === "Not run").length)} not assessed</span>
          </div>
          <div class="table-wrap" style="max-height:460px">
            <table class="data">
              <thead><tr><th>Family</th><th>Group</th><th class="r">N</th><th class="r">χ²</th><th class="r">p adj.</th><th class="r">MAD</th><th>Validity</th><th>Assessment</th><th></th></tr></thead>
              <tbody>${shown.length ? shown.map((g, i) => {
                const decision = groupDecision(g, alpha, kind);
                return `<tr>
                  <td class="grp">${K.esc((g.family || "").replace(" (first digit)", "").replace(" (first two digits)", "").replace(" (second digit)", ""))}</td>
                  <td class="strong">${K.esc(g.group)}</td>
                  <td class="r">${K.fmt(g.n)}</td>
                  <td class="r">${g.chi2 == null ? "—" : Number(g.chi2).toFixed(1)}</td>
                  <td class="r">${g.pAdj == null ? "—" : K.pval(g.pAdj)}</td>
                  <td class="r">${g.mad == null ? "—" : Number(g.mad).toFixed(4)}</td>
                  <td>${K.tierChip(g.tier)}</td>
                  <td>${groupStamp(g)} <span class="caption">${K.esc(decision.replace("Statistical deviation: significant AND practically material", "material deviation").replace("Statistically significant but small deviation", "significant, small"))}</span></td>
                  <td><button class="rowbtn" type="button" data-group="${g._index}">inspect</button></td>
                </tr>`;
              }).join("") : `<tr><td colspan="9" class="muted">No groups available for this digit class.</td></tr>`}</tbody>
            </table>
          </div>
          <p class="caption" style="margin-top:8px">p adj. is the selected correction inside the row's declared family. For raw p, the table is descriptive; the default BH-adjusted column is the one used for flags.</p>
        </section>

        <div style="display:flex;justify-content:space-between;gap:10px;margin-top:22px">
          <button class="btn" type="button" data-route="quality">← Quality</button>
          <button class="btn primary" type="button" data-route="review">Record-level evidence →</button>
        </div>
      </div>`;
    },
    bind(root) {
      const K = window.Kit, st = K.state.benford, d = K.active();
      root.querySelectorAll("[data-kind]").forEach((b) => b.addEventListener("click", () => {
        st.kind = b.dataset.kind; st.digit = 1; st.family = "all"; K.render();
      }));
      root.querySelectorAll("[data-digit]").forEach((b) => b.addEventListener("click", () => {
        st.digit = Number(b.dataset.digit); K.render();
      }));
      const a = root.querySelector("#bfAlpha"); if (a) a.addEventListener("change", () => { st.alpha = Number(a.value); K.render(); });
      const m = root.querySelector("#bfAdjust"); if (m) m.addEventListener("change", () => { st.adjust = m.value; K.render(); });
      const f = root.querySelector("#bfFamily"); if (f) f.addEventListener("change", () => { st.family = f.value; K.render(); });
      root.querySelectorAll("[data-group]").forEach((b) => b.addEventListener("click", () => {
        const gi = Number(b.dataset.group);
        const groups = (d.groups && d.groups[st.kind]) || [];
        const g = groups[gi];
        if (!g) return;
        const bt = d.benford[st.kind];
        const adjusted = withAdjusted(groups, st.adjust)[gi];
        const labels = st.kind === "first" ? ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
          : st.kind === "second" ? ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
          : Array.from({ length: 90 }, (_, i) => String(i + 10).padStart(2, "0"));
        const chart = st.kind === "first" ? K.C.benfordBars(g.counts, bt.probs, {})
          : st.kind === "second" ? K.C.categoryBars(g.counts, bt.probs, labels, {})
          : K.C.firstTwoGrid(g.counts, bt.probs, {});
        K.openDrawer("Group-level test", g.group, `
          <div class="chips"><span class="chip ghost">${K.esc(g.family)}</span>${K.tierChip(g.tier)}<span class="chip ghost">N ${K.fmt(g.n)}</span></div>
          <div class="grid three" style="margin-top:12px">
            ${K.stat("Chi-square", g.chi2 == null ? "—" : Number(g.chi2).toFixed(2), "df " + g.df)}
            ${K.stat("Adjusted p", adjusted.pAdj == null ? "—" : K.pval(adjusted.pAdj), "family size " + (adjusted.familySize || 0))}
            ${K.stat("MAD", g.mad == null ? "—" : Number(g.mad).toFixed(4), g.band || "")}
          </div>
          <h3>Distribution</h3>
          <div class="chart">${chart}<div class="chart-cap"><span>observed vs Benford</span><span>${K.esc(labels.length + " categories")}</span></div></div>
          <h3>Validity note</h3>
          <div class="note-card ${g.tier === "Not run" ? "oxide" : g.tier === "Caution" ? "" : "teal"}">${K.esc(g.tier)}. Minimum expected count ${g.min_E == null ? "—" : Number(g.min_E).toFixed(2)}. ${g.tier === "Not run" ? "No valid p-value is reported." : "The expected-count condition is satisfied at the selected tier."}</div>
          <h3>Assessment</h3>
          <div class="note-card">${K.esc(groupDecision(adjusted, st.alpha, st.kind))}</div>
          <p class="caption" style="margin-top:10px">A group-level deviation is context for records in this group, not an independent transaction-level charge.</p>
          <div class="drawer-actions"><button class="btn" type="button" id="gDone">Close</button></div>`);
        const c = document.querySelector("#gDone"); if (c) c.addEventListener("click", K.closeDrawer);
      }));
    }
  };
})();
