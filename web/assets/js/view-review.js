/* Instrument 05 — The Loupe */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.review = {
    html() {
      const K = window.Kit, d = K.active(), st = K.state.review;
      const an = d.anomalies || {}, m = d.model;
      if (an.available && an.sample && an.sample.length) {
        const rows = an.sample.slice(st.page * 40, st.page * 40 + 40);
        const some = K.byId(d.id);
        const famSet = new Set(an.sample.flatMap((r) => r.families || []));
        const note = an.families && an.families.magnitude ? `${K.fmt(an.families.magnitude)} magnitude  ·  ${K.fmt(an.families.rounding)} rounding  ·  ${K.fmt(an.families.duplication)} duplication  ·  ${K.fmt(an.families.context)} quality` : "";
        let familyFilter = "";
        [{ v: "all", l: "all (magnitude + rounding + duplication)" }, ...Array.from(famSet).map((f) => ({ v: f, l: f }))].forEach((o) => {
          familyFilter += `<option value="${K.esc(o.v)}" ${st.family === o.v ? "selected" : ""}>${K.esc(o.l)}</option>`;
        });
        let groupFilter = "";
        if (d.peers && d.peers.groups && d.peers.groups.length) {
          d.peers.groups.forEach((gg) => { groupFilter += `<option value="${K.esc(gg.label)}" ${st.group === gg.label ? "selected" : ""}>${K.esc(gg.label)}</option>`; });
        } else { groupFilter = `<option value="all">all</option>`; }
        const rowsHtml = rows.length ? rows.map((r, i) => `
          <tr data-record="${i}">
            <td class="strong">${K.esc((r.ref || "").slice(0, 28))}<button type="button" class="rowbtn" data-record="${st.page * 40 + i}">open</button></td>
            <td>${K.esc((r.date || "").slice(0, 12))}</td>
            <td class="r">${K.money(r.amount)}</td>
            <td><span class="chip ghost">${K.esc((r.peer || "").slice(0, 24))}</span></td>
            <td class="r">${r.score}</td>
            <td><span class="chips">${(r.families || []).map((f) => `<span class="chip ${f === "magnitude" ? "oxide" : f === "rounding" ? "brass" : f === "duplication" ? "plum" : "ghost"}">${K.esc(f)}</span>`).join("")}</span></td>
          </tr>`).join("") : `<tr><td colspan="6" class="empty">No more candidates fit the current filter.</td></tr>`;
        return `<div class="view">
          ${K.pageHead("05", "Record-level evidence", `The loupe: <em style="color:var(--oxide)">why does this one stand out?</em>`,
            `For unlabelled data, a ranked list of screening candidates with the evidence behind each. For labelled benchmarks, held-out model predictions and a separate confusion-matrix promise are shown instead. Nothing here is a fraud determination.`,
            `<span class="stamp">${K.fmt(an.candidates)} candidates · ${K.fmt(an.highPriority)} high priority</span>`)}
          <div class="stat-strip">
            ${K.stat("Eligible values", K.fmt(an.eligible), d.measure ? d.measure.label : "")}
            ${K.stat("Candidates", K.fmt(an.candidates), "review prompts")}
            ${K.stat("High priority (≥60)", K.fmt(an.highPriority), "strongest signal")}
            ${K.stat("Method", K.esc(an.method || ""), "")}
            ${K.stat("Min peer size", K.fmt(an.thresholds && an.thresholds.minPeer), "30 · stratified by group")}
          </div>

          <div class="note-card oxide" style="margin-top:14px"><b>Keep the layers separate.</b> A candidate can be flagged on magnitude, rounding, duplication, or data quality. Each family is reported once. Combined forces would inflate the apparent evidence.</div>

          <div class="filters" style="margin-top:14px">
            <label class="field" style="width:180px"><span>Family filter</span>
              <select id="rFamily">${familyFilter}</select></label>
            <label class="field" style="width:170px"><span>Peer group</span>
              <select id="rGroup">${groupFilter}</select></label>
            <label class="field grow"><span>Search reference</span><input id="rQ" type="text" value="${K.esc(st.q)}" placeholder="reference or recipient"></label>
            <label class="field" style="width:90px"><span>Min priority</span><input id="rScore" type="number" min="0" max="99" step="5" value="${st.score}"></label>
            <span class="count">${K.fmt(rows.length)} shown · page ${st.page + 1}</span>
          </div>

          <div class="table-wrap" style="max-height:420px">
            <table class="data">
              <thead><tr><th>Reference</th><th>Date</th><th class="r">Amount</th><th>Peer group</th><th class="r">Priority</th><th>Families</th><th></th></tr></thead>
              <tbody>${rowsHtml}</tbody>
            </table>
          </div>
          <div class="cards" style="display:flex;flex-wrap:wrap;gap:8px;margin-top:8px;justify-content:space-between">
            <button class="btn" type="button" id="rPrev" ${st.page === 0 ? "disabled" : ""}>← previous</button>
            <button class="btn" type="button" id="rNext" ${rows.length < 40 ? "disabled" : ""}>next →</button>
            <button class="btn ghost small" type="button" id="rReset">Reset filter</button>
          </div>

          <div class="divider"></div>
          <h3>What is a priority index?</h3>
          <p class="caption">${K.fmt(d.rows)} positive records were compared, ${K.fmt(an.candidates)} surfaced. Priority = max(severity × 100) + 4 × (extra families beyond the first one), capped at 99. It is a transparent ranking aid, not a probability or a score of dishonesty.</p>
          <div class="stat-strip" style="margin-top:8px">
            <button class="btn on-dark small" type="button" data-route="export">Export candidates CSV</button>
            <button class="btn ghost small" type="button" id="rBoundary">Interpretation boundary</button>
          </div>
        </div>`;
      }
      if (m && m.available) {
        const logModel = m.models.logistic, rfModel = m.models.forest;
        const sample = m.sample || [];
        const tab = st.tab;
        const a = tab === "predictions" ? rowsHtmlPred() : rowsHtmlBenchmark();
        let confHtml = logModel.curve ? K.C.confusion(logModel.metrics) : "";
        const predHtml = sample.length ? sample.map((r) => `<tr data-record="${r.row}">
            <td>${K.esc((r.ref || "").slice(0, 28))}<button type="button" class="rowbtn" data-record="${r.row}">detail</button></td>
            <td>${K.esc(r.date || "")}</td>
            <td class="r">${K.money(r.amount)}</td>
            <td>${K.esc(r.extra || "")}</td>
            <td class="r"><span class="chip ${r.trueLabel === 1 ? "plum" : "ghost"}">true ${r.trueLabel}</span></td>
            <td class="r">${K.pval(r.pLogistic)}</td>
            <td class="r">${K.pval(r.pForest)}</td>
            <td><span class="chips">${(r.drivers || []).map((dr) => `<span class="chip ghost" style="font-size:9px">${K.esc(dr.feature)} ${dr.contribution >= 0 ? "+" : ""}${dr.contribution.toFixed(2)}</span>`).join(" ")}</span></td>
          </tr>`).join("") : `<tr><td colspan="8" class="empty">No sample rows.</td></tr>`;
        let sampleRows = `<div class="table-wrap"><table class="data compact"><thead><tr><th>Reference</th><th>Date</th><th class="r">Amount</th><th>Type</th><th>label</th><th class="r">pLog</th><th class="r">pRF</th><th>Top drivers</th></tr></thead>
          <tbody>${predHtml}</tbody></table></div>`;
        return `<div class="view">
          ${K.pageHead("05", "Supervised benchmarks", `Two models, one dataset, one <em>product</em>.`,
            `For labelled benchmarks we report held-out performance with its own split, its own confusion matrix and its own limitations. The test set keeps its original prevalence; it is never balanced to flatter the numbers.`,
            `<span class="stamp ok">${K.esc(m.dataset)} · ${K.esc(m.label)}</span>`)}
          <div class="stat-strip">
            ${K.stat("Sample size", K.fmt(m.split.train + m.split.validation + m.split.test), K.esc(m.split.strategy))}
            ${K.stat("Test set", K.fmt(m.split.test), "prevalence " + (m.split.testPrevalence * 100).toFixed(2) + "%")}
            ${K.stat("Label", K.esc(m.target + " = " + m.positiveClass), "prevalence " + (m.prevalence * 100).toFixed(2) + "% overall")}
            ${K.stat("Features", K.fmt(m.features.length), "excluded: " + K.esc(m.excluded.length ? m.excluded.join(", ") : "none"))}
            ${K.stat("Seed", "2025", "fixed for the run")}
          </div>

          <div class="subtabs" style="margin-top:22px">
            <button class="subtab ${tab === "predictions" ? "is-active" : ""}" type="button" data-tab="predictions">Model predictions</button>
            <button class="subtab ${tab === "benchmark" ? "is-active" : ""}" type="button" data-tab="benchmark">Benchmark evaluation</button>
          </div>
          ${a}
          ${tab === "benchmark" ? `<div class="divider"></div>
            <div class="grid split">
              <div class="panel olive-edge" style="background:rgba(255,253,246,.9)">
                <h3 style="margin-top:0">${K.esc(m.dataset)} — ${K.esc(m.label)}</h3>
                <div class="split" style="margin-top:10px;align-items:start">
                  <div class="grid three">
                    ${K.stat("Precision", K.fmt(logModel.metrics.precision), "TP / (TP+FP)")}
                    ${K.stat("Recall", K.fmt(logModel.metrics.recall), "TP / (TP+FN)")}
                    ${K.stat("F1", K.fmt(logModel.metrics.f1), logModel.threshold != null ? "thr " + (logModel.threshold * 100).toFixed(0) + "%" : "")}
                  </div>
                  <div class="grid three">
                    ${K.stat("Precision", K.fmt(rfModel.metrics.precision), "TP / (TP+FP)")}
                    ${K.stat("Recall", K.fmt(rfModel.metrics.recall), "TP / (TP+FN)")}
                    ${K.stat("F1", K.fmt(rfModel.metrics.f1), rfModel.threshold != null ? "thr " + (rfModel.threshold * 100).toFixed(0) + "%" : "")}
                  </div>
                </div>
                <div class="split" style="margin-top:14px">
                  <div class="chart" style="padding:0;background:transparent">${confHtml}</div>
                  <div class="grid two" style="gap:12px">
                    <div class="chart">${(logModel.curve && logModel.curve.roc) ? K.C.rocCurve(logModel.curve.roc, logModel.metrics.roc_auc) : "<div class='empty'>No curve</div>"}<div class="chart-cap"><span>ROC</span><span>AUC ${K.fmt(logModel.metrics.roc_auc)}</span></div></div>
                    <div class="chart">${(logModel.curve && logModel.curve.pr) ? K.C.prCurve(logModel.curve.pr, logModel.metrics.pr_auc) : "<div class='empty'>No curve</div>"}<div class="chart-cap"><span>PR</span><span>PR AUC ${K.fmt(logModel.metrics.pr_auc)}</span></div></div>
                  </div>
                </div>
                <div class="stat-strip" style="margin-top:16px">
                  <div class="stat" style="border-left-color:var(--teal)"><span class="k">Split strategy</span><span class="v" style="font-size:12px">${K.esc(m.split.strategy)}</span></div>
                  <div class="stat" style="border-left-color:var(--teal)"><span class="k">Test FPR vs baseline</span><span class="v" style="font-size:12px">${rfModel.metrics.fp} FP vs ${(m.split.test - m.split.testFraud)} negatives</span></div>
                </div>
              </div>
              <div class="panel">
                <h3 style="margin-top:0">${K.esc(logModel.name)} — important features</h3>
                ${(logModel.importance && logModel.importance.length) ? K.C.barsH(logModel.importance.slice(0, 10).map((x, i) => ({ label: x.name, value: +x.value, display: "+${(+x.value).toFixed(3)}", color: K.C.teal }))) : "<div class='empty'>No coefficients.</div>"}
                <p class="caption" style="margin:12px 0 0">${K.esc(logModel.importanceLabel || "")} · ${K.esc(logModel.note || "")}</p>
                <h3>${K.esc(rfModel.name)} — variable importance</h3>
                ${(rfModel.importance && rfModel.importance.length) ? K.C.barsH(rfModel.importance.slice(0, 10).map((x, i) => ({ label: x.name, value: +x.value, display: (+x.value).toFixed(3), color: K.C.blue }))) : "<div class='empty'>No importance.</div>"}
              </div>
            </div>
            <section class="panel oxide-edge" style="margin-top:14px">
              <h3>Limitations — read alongside the metric row</h3>
              ${m.limitations ? m.limitations.map((l) => `<div class="note-card">○ ${K.esc(l)}</div>`).join("") : ""}
              <div class="note-card oxide"><b>Boundary.</b> ${K.esc(K.D.method.boundary)}</div>
            </section>
          </div>` : `<div class="divider"></div>
            <h3>Compare with another supervised benchmark</h3>
            <p class="caption">Models are dataset-specific. ${K.esc(m.target) === "Class" ? "Open " : "Browse "}BankSim, PaySim or the credit-card benchmark on its own dataset.</p>
            <div class="chips">
              ${["creditcard", "paysim"].filter((id) => K.D.datasets[id]).map((id) => `<button class="btn on-dark small" type="button" data-stage="${id}">${K.esc(K.D.datasets[id].name)}</button>`).join("")}
            </div>
          </div>`;
        function rowsHtmlBenchmark() { return ""; }
        function rowsHtmlPred() { return sampleRows; }
      }
      return `<div class="view">${K.pageHead("05", "Review", "The loupe",
        "No labelled model and no labelled anomaly output were supplied for this dataset.",
        "")}${K.noMethod("No review output", d.kind === "labelled" ? "This built-in dataset has no supervised model in this static build." : "This dataset has no record-level screening output.")}</div>`;
    },
    bind(root) {
      const K = window.Kit, st = K.state.review;
      if (root.querySelector("#rFamily")) root.querySelector("#rFamily").addEventListener("change", (e) => { st.family = e.target.value; st.page = 0; K.render(); });
      if (root.querySelector("#rGroup")) root.querySelector("#rGroup").addEventListener("change", (e) => { st.group = e.target.value; st.page = 0; K.render(); });
      if (root.querySelector("#rQ")) root.querySelector("#rQ").addEventListener("change", (e) => { st.q = e.target.value.trim(); st.page = 0; K.render(); });
      if (root.querySelector("#rScore")) root.querySelector("#rScore").addEventListener("change", (e) => { st.score = Number(e.target.value) || 0; st.page = 0; K.render(); });
      if (root.querySelector("#rPrev")) root.querySelector("#rPrev").addEventListener("click", () => { if (st.page > 0) { st.page--; K.render(); } });
      if (root.querySelector("#rNext")) root.querySelector("#rNext").addEventListener("click", () => { ++st.page; K.render(); });
      if (root.querySelector("#rReset")) root.querySelector("#rReset").addEventListener("click", () => { K.state.review = { family: "all", score: 0, q: "", group: "all", page: 0, tab: "records", model: "logistic", predQ: "" }; K.render(); });
      if (root.querySelector("#rBoundary")) root.querySelector("#rBoundary").addEventListener("click", () => K.openModal("Interpretation boundary", "What this kit will not say", K.boundaryHtml()));
      root.querySelectorAll("[data-record]").forEach((b) => b.addEventListener("click", () => {
        const reco = K.active().anomalies.sample[Number(b.dataset.record)];
        if (reco) K.openRecord(reco);
      }));
      root.querySelectorAll("[data-tab]").forEach((b) => b.addEventListener("click", () => { st.tab = b.dataset.tab; K.render(); }));
    }
  };
})();
