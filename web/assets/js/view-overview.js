/* Instrument 01 — The Case */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.overview = {
    html() {
      const K = window.Kit, d = K.active(), C = K.C;
      const q = d.quality || {}, an = d.anomalies || {}, m = d.model;
      const eligible = d.measure ? d.measure.n : 0;
      const groups = (d.groups && d.groups.first ? d.groups.first.length : 0);
      const flagged = an.available ? an.candidates : m ? m.split.test : null;
      const flaggedLabel = an.available ? "review candidates" : m ? "held-out test records" : "—";
      const first = d.benford && d.benford.first;
      const mini = first ? C.benfordBars(first.counts, first.probs, {}) : "";
      return `<div class="view">
        ${K.pageHead("01", "The case", `Unusual numbers, <em style="color:var(--oxide)">explained</em> before accused.`,
          `An explainable screening kit for transaction data. Two layers — group digit distributions and record-level peer evidence — kept distinct, reported with their uncertainty, and never dressed up as a fraud verdict.`,
          `<span class="stamp ok">Review, not verdict</span>`)}
        <div class="hero">
          <div class="hero-copy">
            <p class="page-kicker">Explainable anomaly detection</p>
            <h2>Most numbers keep a quiet <em>promise.</em></h2>
            <p class="hero-lead">Benford's Law is the promise: across many natural, multi-scale quantities, the leading digit 1 appears about 30% of the time, 2 about 18%, and so on. When a group of transactions breaks that pattern, or a record sits far outside its peers, the kit marks it for review — with the evidence and the caveat attached.</p>
            <div class="hero-actions">
              <button class="btn primary" type="button" data-route="benford">Open the ruler</button>
              <button class="btn" type="button" data-route="data">Choose a dataset</button>
              <button class="btn ghost" type="button" data-route="review">See what gets flagged</button>
            </div>
            <div class="kit-stamp-row">
              <span class="chip teal">group layer</span>
              <span class="chip brass">record layer</span>
              <span class="chip ghost">labelled benchmarks separated</span>
              <span class="chip ghost">no invented labels</span>
            </div>
          </div>
          <aside class="hero-card">
            <p class="eyebrow">Active dossier</p>
            <h3>${K.esc(d.name)}</h3>
            <p>${K.esc(d.category)} · ${K.esc(d.source)}</p>
            <div class="hero-figure">
              ${K.stat("Eligible values", K.fmt(eligible), K.esc(d.measure ? d.measure.label : "—"), "accent")}
            </div>
            <div class="stat-strip" style="margin-top:8px">
              ${K.stat("Rows", K.fmt(d.rows), d.kind)}
              ${K.stat(an.available ? "Candidates" : "Label", an.available ? K.fmt(an.candidates) : (m ? m.target : "—"), an.available ? "screening prompts" : (m ? "benchmark target" : ""))}
            </div>
            <div class="kit-stamp-row" style="margin-bottom:0">
              <button class="btn on-dark small" type="button" data-route="quality">Quality</button>
              <button class="btn on-dark small" type="button" data-route="export">Audit file</button>
            </div>
          </aside>
        </div>

        <div class="stat-strip" style="margin:18px 0 6px">
          ${K.stat("Datasets in the case", K.fmt(Object.keys(K.allDatasets()).length), "each analysed independently")}
          ${K.stat("Records in active set", K.fmt(d.rows), K.esc(d.file), "")}
          ${K.stat("Group tests", K.fmt(groups), "first-digit groups")}
          ${K.stat(flaggedLabel, flagged == null ? "—" : K.fmt(flagged), an.available ? "a prompt, not a finding" : "original prevalence")}
          ${K.stat("Suitability", d.suitability ? d.suitability.verdict : "—", d.suitability ? d.suitability.label : "")}
        </div>

        <div class="grid split" style="margin-top:18px">
          <section class="panel tape brass-edge">
            <div class="section-title" style="margin-top:0"><h3>The law, in one line</h3><span class="note">Fig. 01 · first-digit reference</span></div>
            <div class="law">
              <div class="formula">P(d) = log<sub>10</sub>(1 + <span class="frac"><span>1</span><span class="den">d</span></span>)</div>
              <div class="caption" style="text-align:right">d = 1, …, 9<br>E(d) = N · P(d)<br>X² = Σ (O − E)² / E<br>df = 8</div>
            </div>
            <p style="margin-top:12px">The same law, drawn as bars: observe against expectation. Colour is not a verdict; it marks the size of the gap. A statistically significant gap is only a reason to look, and a large sample makes tiny gaps significant.</p>
            <div class="chart">${mini}<div class="chart-cap"><span>observed share</span><span>dashed = Benford expectation · brass dots</span></div></div>
          </section>
          <div class="grid" style="align-content:start">
            <section class="panel oxide-edge">
              <p class="eyebrow">The two layers</p>
              <h3>Group distribution vs record evidence</h3>
              <div class="timeline" style="margin-top:10px">
                <div class="step"><span class="dot">A</span><div><h4>Group screening</h4><p>Does a peer group's digit distribution differ from Benford? Chi-square, validity tier, MAD, residuals, Holm/BH.</p></div></div>
                <div class="step"><span class="dot">B</span><div><h4>Record screening</h4><p>Is one amount unusual relative to comparable transactions? Log IQR, modified Z, percentile, rounding, duplicates.</p></div></div>
                <div class="step"><span class="dot">C</span><div><h4>Supervised, where labels exist</h4><p>Separate benchmark models, separate test sets, no transfer between datasets.</p></div></div>
              </div>
            </section>
            <section class="panel tight">
              <p class="eyebrow">The open case</p>
              <div class="contents">
                ${K.TOOLS.filter((t) => t.id !== "overview").map((t) => `<a href="#${t.id}" data-route="${t.id}"><span class="c-no">${t.no}</span><span><span class="c-name">${K.esc(t.name)}</span><span class="c-sub">${K.esc(t.sub)}</span></span><span class="c-arrow">→</span></a>`).join("")}
              </div>
            </section>
          </div>
        </div>

        <div class="grid split-rev" style="margin-top:18px">
          <section class="panel teal-edge">
            <p class="eyebrow">What the kit refuses to say</p>
            <h3>“Fraud confirmed.”</h3>
            <p>No algorithm in this case can say that. Benford's Law describes digit patterns, not intent. A robust Z-score describes distance from peers, not dishonesty. A repeated signature can be a legitimate batch correction.</p>
            <div class="stamp">Review candidate · not a finding</div>
            <p class="caption">The correct output is a ranked, explained list for a human to investigate — with the limitations printed next to it.</p>
          </section>
          <section class="panel">
            <div class="section-title" style="margin-top:0"><h3>Dossier note</h3><span class="note">active source</span></div>
            <dl class="kv">
              <dt>File</dt><dd>${K.esc(d.file)}</dd>
              <dt>Filters</dt><dd>${K.esc(d.filters)}</dd>
              <dt>Measure</dt><dd>${K.esc(d.measure ? d.measure.label : "—")}</dd>
              <dt>Label</dt><dd>${d.model ? K.esc(d.model.target + " · positive " + d.model.positiveClass) : "none — unlabelled"}</dd>
              <dt>Peers</dt><dd>${K.esc(d.peers && d.peers.levels ? d.peers.levels.join(" → ") : "—")}</dd>
              <dt>Missing cells</dt><dd>${q.missingPct == null ? "—" : q.missingPct.toFixed(2) + "%"}</dd>
              <dt>Caveat</dt><dd>${K.esc(d.caveat)}</dd>
            </dl>
            <div class="note-card oxide" style="margin-top:12px"><b>Boundary.</b> ${K.esc(K.D.method.boundary)}</div>
          </section>
        </div>
      </div>`;
    },
    bind() {}
  };
})();
