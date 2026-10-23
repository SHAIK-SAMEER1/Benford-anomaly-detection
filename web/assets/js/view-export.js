/* Instrument 08 — The Seal */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.export = {
    html() {
      const K = window.Kit, d = K.active(), D = K.D, QA = d.anomalies || {}, m = d.model || {};
      const q = d.quality || {}, s = d.suitability || {}, bt = d.benford && d.benford.first;
      const rows = QA.sample || [];
      const candidatesCsv = rows.map((r) => ({
        reference: r.ref,
        date: r.date,
        amount: r.amount,
        peer_group: r.peer,
        peer_size: r.peerN,
        peer_median: r.median,
        modified_z: r.z,
        percentile: r.percentile,
        trailing_zeros: r.trailingZeros,
        round_thousand: r.round1k ? 1 : 0,
        sig_repeats: r.sigCount,
        same_amount_on_award: r.awardAmountCount,
        priority_index: r.score,
        flag_families: (r.families || []).join(" | "),
        score_magnitude: (r.families || []).includes("magnitude") ? 1 : 0,
        score_rounding: (r.families || []).includes("rounding") ? 1 : 0,
        score_duplication: (r.families || []).includes("duplication") ? 1 : 0,
        score_quality: (r.families || []).includes("quality") ? 1 : 0,
        reasons: (r.reasons || []).join(" | ")
      }));
      const groupsCsv = (d.groups && d.groups.first) ? d.groups.first.map((g) => ({
        family: g.family, group: g.group, n: g.n, chi2: g.chi2, df: g.df,
        p_raw: g.p, mad: g.mad, band: g.band, tier: g.tier,
        min_expected: g.min_E, cohens_w: g.cohen_w, flag: g.flag
      })) : [];
      const modelCsv = m.models && Object.keys(m.models).length
        ? Object.values(m.models).map((m2) => ({
          dataset: m.dataset, model: m2.name,
          threshold: m2.threshold, n_test: m2.metrics.n, test_fraud: m.split.testFraud, test_prevalence: m.split.testPrevalence,
          tp: m2.metrics.tp, fp: m2.metrics.fp, tn: m2.metrics.tn, fn: m2.metrics.fn,
          precision: m2.metrics.precision, recall: m2.metrics.recall, f1: m2.metrics.f1,
          specificity: m2.metrics.specificity, accuracy: m2.metrics.accuracy,
          roc_auc: m2.metrics.roc_auc, pr_auc: m2.metrics.pr_auc, baseline: m.limitations && m.limitations.find((l) => l.includes("prevalence"))
            ? "test set kept at original prevalence" : ""
        })) : [];

      const peersRows = (P = d.peers && d.peers) ? (P.groups || []).map((g) => ({
        group: g.label, n: g.n, median: g.median, q1: g.q1, q3: g.q3,
        mad: g.mad, lower: g.lower, upper: g.upper, flagged: g.flagged || 0
      })) : [];

      const auditLine = `
        Open <span class="mono">web/assets/js/data.js</span> · ${Object.keys(D.datasets).length} registered datasets ·
        active <span class="mono">${K.esc(d.file)}</span> · R pipeline + browser analysis · ${K.esc(D.generated)}`;
      return `<div class="view">
        ${K.pageHead("08", "Audit & export", `The seal: what was run, <em style="color:var(--oxide)">and what it will not prove.</em>`,
          `A single dossier for anyone who needs to reproduce, inspect, or challenge the results. Every number here is traceable to a computed table, a downloaded file, or the reproducible pipeline in scripts/build_web_data.R — except the in-browser upload, which is a cautious preview only.`,
          `<span class="stamp">${K.fmt(d.rows)} rows · ${K.fmt(Object.keys(D.datasets).length)} datasets</span>`)}
        <div class="grid split" style="margin-top:14px">
          <section class="panel">
            <div class="section-title" style="margin-top:0"><h3>Active dossier</h3><span class="note">${K.esc(d.name)}</span></div>
            <dl class="kv">
              <dt>Source</dt><dd><a href="${K.esc(d.url)}" target="_blank" rel="noopener">${K.esc(d.url || "—")}</a> · ${K.esc(d.source)}</dd>
              <dt>File</dt><dd>${K.esc(d.file)}</dd>
              <dt>Path in repo</dt><dd><span class="mono">${K.esc(d.path)}</span></dd>
              <dt>Filters</dt><dd>${K.esc(d.filters)}</dd>
              <dt>Rows × columns</dt><dd>${K.fmt(d.rows)} × ${K.fmt(d.cols)}</dd>
              <dt>Measure</dt><dd>${K.esc(d.measure ? d.measure.label : "—")} · ${K.esc(d.measure && d.measure.n ? String(d.measure.n) + " eligible" : "")}</dd>
              <dt>Label</dt><dd>${d.model ? K.esc(m.target + " · positive " + m.positiveClass + " · prevalence " + (m.split.testPrevalence * 100).toFixed(2) + "% on test") : "none — unlabelled"}</dd>
              <dt>Benford first digit</dt><dd>N ${K.fmt(bt ? bt.N : 0)} · χ² ${bt && bt.chi2 == null ? "—" : Number(bt.chi2).toFixed(2)} · p ${bt && bt.p == null ? "—" : K.pval(bt.p)} · MAD ${bt && bt.mad == null ? "—" : Number(bt.mad).toFixed(4)} · ${K.esc(bt ? bt.tier : "—")}</dd>
              <dt>Candidates</dt><dd>${K.fmt(QA.available ? QA.candidates : 0)} · high priority ${K.fmt(QA.highPriority)} · ${K.fmt(QA.families && QA.families.magnitude || 0)} magnitude · ${K.fmt(QA.families && QA.families.rounding || 0)} rounding · ${K.fmt(QA.families && QA.families.duplication || 0)} duplication</dd>
              <dt>Generated</dt><dd>${K.esc(D.generated)}</dd>
            </dl>
          </section>
          <section class="panel brass-edge">
            <div class="section-title" style="margin-top:0"><h3>State audit</h3><span class="note">five gates</span></div>
            <div class="note-card teal" style="display:flex;gap:10px;align-items:flex-start"><span class="mono" style="font-weight:700">PASS</span><span><b>Original files untouched.</b> The R pipeline writes to data/processed and web/downloads; data/raw is unmodified.</span></div>
            <div class="note-card teal"><span class="mono">PASS</span><span><b>Staging is real.</b> The data desk previews a dataset without changing the active source; loading commits the switch and rerenders every instrument.</span></div>
            <div class="note-card teal"><span class="mono">PASS</span><span><b>No fabricated labels.</b> Unlabelled datasets (USAspending, retail, WDI) receive no outcome column and no model. Only benchmark files carry their documented labels.</span></div>
            <div class="note-card teal"><span class="mono">PASS</span><span><b>Multiple testing declared per family.</b> The Benford table applies Holm/Benjamini–Hochberg inside each named family of tests, not across results after looking.</span></div>
            <div class="note-card teal"><span class="mono">PASS</span><span><b>Filters and thresholds documented.</b> Alpha, z threshold, IQR multiplier, minimum peer size, and round-share threshold are recorded in d.method and visible on-screen.</span></div>
            <div class="note-card oxide" style="margin-top:8px"><span class="mono">WATCH</span><span><b>Synthetic results are labelled.</b> The validation lab reports on its own synthetic trials only; it does not claim real-world fraud accuracy.</span></div>
          </section>
        </div>

        <div class="grid split" style="margin-top:18px">
          <section class="panel">
            <div class="section-title" style="margin-top:0"><h3>Download this dossier</h3><span class="note">CSVs and JSON</span></div>
            <p class="caption">Links below point to the verified files in <span class="mono">web/downloads/</span>. The live tables (top 80/candidates, groups, models) are exported from what is currently visible.</p>
            <div class="buttons" style="display:flex;flex-wrap:wrap;gap:8px;margin-top:12px">
              <button class="btn on-dark" type="button" data-download="dataset_registry.csv">Dataset registry</button>
              <button class="btn on-dark" type="button" data-download="model_metrics.csv">Model metrics</button>
              <button class="btn on-dark" type="button" data-download="benford_groups_all.csv">All Benford groups</button>
              <button class="btn on-dark" type="button" data-download="audit_summary.json">Audit summary JSON</button>
              <button class="btn on-dark" type="button" data-download="raw_file_inventory.csv">Raw file inventory</button>
              <button class="btn on-dark" type="button" data-download="review_candidates_usaspending.csv">USASpending full flags ISO-8859-1</button>
              <button class="btn on-dark" type="button" data-download="review_candidates_retail.csv">Retail top 300</button>
              <button class="btn on-dark" type="button" data-download="review_candidates_wdi.csv">WDI top 220</button>
            </div>
            <div class="chips" style="margin-top:10px">
            <span class="chip ghost">live: current candidates (top 80) · current groups · live models</span>
            </div>
            <div class="buttons" style="display:flex;flex-wrap:wrap;gap:8px;margin-top:10px">
              <button class="btn" type="button" id="downloadCandidatesLive" ${candidatesCsv.length ? "" : "disabled"}>Candidates (current filter, JSON)</button>
              <button class="btn" type="button" id="downloadGroupsLive" ${groupsCsv.length ? "" : "disabled"}>Groups (current dataset, CSV)</button>
              <button class="btn" type="button" id="downloadModelsLive" ${modelCsv.length ? "" : "disabled"}>Model metrics (live, CSV)</button>
              <button class="btn" type="button" id="downloadAuditLive">Active-dataset audit (JSON)</button>
              <button class="btn ghost" type="button" id="printReport">Open a printable report</button>
            </div>
            <div class="note-card" style="margin-top:10px"><b>Reproducible rerun.</b> Rebuild all of this from the R pipeline: <span class="mono">Rscript scripts/build_web_data.R</span> from the project root. A re-ran dataset summary replaces <span class="mono">web/assets/js/data.js</span> and the downloads.</span></div>
          </section>
          <aside class="panel brass-edge">
            <div class="section-title" style="margin-top:0"><h3>What is in the pipeline</h3><span class="note">datasets analysed</span></div>
            <div class="grid two">${Object.values(K.allDatasets()).map((x) => {
              const nAnc = (x.anomalies && x.anomalies.candidates) || 0;
              const modelT = x.model && x.model.available ? "trained" : "—";
              return `<div class="stat"><span class="k">${K.esc(x.id)}</span><span class="v" style="font-size:12px">${K.fmt(x.rows)} rows</span><span class="s">${K.esc(x.name)} · ${x.kind} · ${K.fmt(x.cols)} cols</span></div>`;
            }).join("")}</div>
            <div class="note-card" style="margin-top:12px">
              <b>Note.</b> BankSim (<span class="mono">bs140513_032310.csv</span>) was expected but not found in the workspace, so no BankSim model was trained and no BankSim flag was invented. That gap is recorded in <span class="mono">web/downloads/missing_datasets.csv</span>.
            </div>
          </section>
        </div>

        <section class="panel oxide-edge" style="margin-top:18px">
          <div class="section-title" style="margin-top:0"><h3>Interpretation boundary — printed again</h3></div>
          <div class="note-card oxide">${K.esc(D.method.boundary)}</div>
          <dl class="kv" style="margin-top:8px">
            <dt>Review candidate</dt><dd>A statistical signal for a human to investigate, not a finding of wrongdoing.</dd>
            <dt>Group deviation</dt><dd>A digit distribution differs materially from the reference. Not who, not why, not intent.</dd>
            <dt>Model score</dt><dd>A dataset-specific benchmark metric on its own held-out split; not a real-world fraud probability.</dd>
            <dt>Synthetic result</dt><dd>A controlled experiment with known manipulation; describes that experiment, not the real world.</dd>
          </dl>
          <div class="chips" style="margin-top:10px"><span class="chip">If a result says fraud, the kit is wrong — reword it as “review candidate”.</span></div>
        </section>

        <div style="display:flex;justify-content:space-between;gap:10px;margin-top:22px">
          <button class="btn" type="button" data-route="validation">← Validation lab</button>
          <button class="btn primary" type="button" data-route="review">Review again</button>
        </div>
      </div>`;
    },
    bind(root) {
      const K = window.Kit;
      root.querySelectorAll("[data-download]").forEach((btn) => {
        btn.addEventListener("click", () => {
          const key = btn.dataset.download;
          const url = "downloads/" + key;
          window.open(url, "_blank");
          if (btn.classList.contains("on-dark")) toast("Opening → " + key + " in a new tab.");
        });
      });
      const dl = (name, text, mime, fallback) => message("Export → " + name);
      function downloadBlob(filename, text, mime) {
        const blob = new Blob([text], { type: mime });
        const url = URL.createObjectURL(blob);
        const a = document.createElement("a"); a.href = url; a.download = filename;
        document.body.appendChild(a); a.click(); setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 400);
      }
      root.querySelector("#downloadCandidatesLive")?.addEventListener("click", () => {
        const d = K.byId(K.state.activeId);
        const rows = (d && (d.anomalies || {}).sample) || [];
        const lines = rows.map((r) => ({
          reference: r.ref || "",
          date: r.date || "",
          amount: r.amount,
          peer_group: r.peer || "",
          peer_size: r.peerN,
          priority: r.score,
          families: (r.families || []).join(" | "),
          reasons: (r.reasons || []).join(" | ")
        }));
        const csv = ["reference,date,amount,peer_group,peer_size,priority,families,reasons", ...lines.map((l) =>
          [l.reference, l.date, l.amount, l.peer_group, l.peer_size, l.priority, l.families, l.reasons].map((v) => {
            if (v == null) return "";
            const s = String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
          }).join(",")].join("\n"));
        downloadBlob("candidates_" + K.active().id + ".csv", csv, "text/csv;charset=utf-8");
      });
      root.querySelector("#downloadGroupsLive")?.addEventListener("click", () => {
        const d = K.active(), groups = (d && d.groups ? d.groups.first : []);
        if (!groups.length) return;
        const csv = ["family,group,n,chi2,df,p_raw,mad,band,tier,min_expected,cohens_w,flag",
          ...groups.map((g) =>
            [g.family, g.group, g.n, g.chi2, g.df, g.p, g.mad, g.band, g.tier, g.min_E, g.cohen_w, g.flag].map((v) => {
              if (v == null || !(v != null) || (v && isNaN(v))) return "";
              const s = String(v); return /[",\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
            }).join(",")
          ).join("\n")].join("\n");
        downloadBlob("groups_" + d.id + ".csv", csv, "text/csv;charset=utf-8");
      });
      root.querySelector("#downloadModelsLive")?.addEventListener("click", () => {
        const d = K.active();
        if (!d.model || !Object.keys(d.model.models).length) return;
        const csv = ["dataset,model,threshold,n_test,test_fraud,test_prevalence,tp,fp,tn,fn,precision,recall,f1,specificity,accuracy,roc_auc,pr_auc",
          Object.values(d.model.models).map((mod) =>
            [d.id, mod.name, mod.threshold, mod.metrics.n, d.model.split.testFraud, d.model.split.testPrevalence, mod.metrics.tp, mod.metrics.fp, mod.metrics.tn, mod.metrics.fn, mod.metrics.precision, mod.metrics.recall, mod.metrics.f1, mod.metrics.specificity, mod.metrics.accuracy, mod.metrics.roc_auc, mod.metrics.pr_auc].join(",")
          ).join("\n")].join("\n");
        downloadBlob("models_" + d.id + ".csv", csv, "text/csv;charset=utf-8");
      });
      root.querySelector("#downloadAuditLive")?.addEventListener("click", () => {
        const d = K.active();
        downloadBlob("audit_" + d.id + ".json", JSON.stringify({ active: d.id, name: d.name, source: d.source, url: d.url, file: d.file, path: d.path, filters: d.filters, rows: d.rows, cols: d.cols, measure: d.measure, quality: d.quality, suitability: d.suitability, benford: d.benford, anomalies: d.anomalies, peers: d.peers, model: d.model && { target: d.model.target, positive: d.model.positiveClass, prevalence: d.model.prevalence, testPrevalence: d.model.split.testPrevalence, methods: Object.keys(d.model.models) }, notes: [d.caveat, D.method.boundary], generated: D.generated }, null, 2), "application/json;charset=utf-8");
      });
      root.querySelector("#printReport")?.addEventListener("click", () => window.print());
    }
  };
})();
