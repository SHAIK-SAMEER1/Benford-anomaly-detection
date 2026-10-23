/* Instrument 07 — The Pencil */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.validation = {
    html() {
      const K = window.Kit, d = K.state.validation, E = K.D.experiment;
      const mechanisms = [
        { v: "round_number", l: "Round-number substitution" },
        { v: "leading_bias", l: "Leading-digit bias" },
        { v: "partial", l: "Partial / small alteration" },
        { v: "extreme", l: "Extreme-value insertion" },
        { v: "duplicate", l: "Repeated amounts" }
      ];
      const stats = d.result || [];
      const sweep = d.sweep || null;
      const curMech = mechanisms.find((m) => m.v === d.mechanism);
      let resultHtml = "";
      if (stats.length) {
        const fail = stats.filter((s) => s.falsePositive > 0.0001);
        resultHtml = `<div class="stat-strip">
            ${K.stat("Trials run", K.fmt(stats.length), "each with " + d.n + " values")}
            ${K.stat("Mean detection", K.pct(K.mean(stats, "detected")), "share with significant p")}
            ${K.stat("Mean MAD", K.fmt(K.mean(stats, "mad"), 3), "across trials")}
            ${K.stat("Mean chi-square", K.fmt(K.mean(stats, "x2"), 2), "df 8")}
            ${K.stat("False-positive rate", K.pct(fail.length ? fail[0].falsePositive : 0), "rate 0 trials")}
          </div>
          <div class="table-wrap" style="max-height:420px">
            <table class="data compact"><thead><tr><th>Trial</th><th class="r">n altered</th><th class="r">p-value</th><th class="r">chi-square</th><th class="r">MAD</th><th>Detected</th></tr></thead>
              <tbody>${stats.slice(0, 80).map((s, i) => `<tr><td class="r">${i + 1}</td><td class="r">${K.fmt(s.altCount)}</td><td class="r">${K.pval(s.p)}</td><td class="r">${K.fmt(s.x2, 2)}</td><td class="r">${Number(s.mad).toFixed(4)}</td><td>${K.fmt(s.n)} records · ${s.detected ? "<span class='chip oxide'>detected</span>" : "<span class='chip ghost'>not detected</span>"}</td></tr>`).join("")}${stats.length > 80 ? `<tr><td colspan="6" class="empty">Showing 80 of ${K.fmt(stats.length)} trials. ${K.fmt(stats.length - 80)} more not shown.</td></tr>` : ""}</tbody>
            </table>
          </div>`;
      } else {
        resultHtml = `<div class="empty"><b>Run it.</b> The pencil has not drawn anything yet — press “40 trials” or “sweep the rate” to generate synthetic data and see whether the test catches it.</div>`;
      }
      const sweepHtml = sweep && sweep.length ? `<div class="chart">${K.C.lineChart(sweep.map((s) => K.esc(K.D.experiment.curve.find((c) => c.manipulation === d.mechanism).labels[s.rate] || K.fmt(s.rate * 100) + "%")).filter(Boolean), [{
            color: K.C.oxide, values: sweep.map((s) => K.pct(s.falsePositive, 1)), label: "false positives" }, {
            color: K.C.teal, values: sweep.map((s) => K.pct(s.detected, 1)), label: "detection" }], {
            title: `"${K.esc(curMech ? curMech.l : "")}" detection vs false positives across rates`,
            markers: false, yFormat: K.pct
          })}<div class="chart-cap"><span>detection (teal) · false-positive rate (oxide)</span><span>200 values per trial · 40 trials per rate</span></div></div>`
        : `<div class="empty">Run the rate sweep to see the trade-off.</div>`;

      return `<div class="view">
        ${K.pageHead("07", "Controlled validation", `The pencil: <em style="color:var(--oxide)">forge, then see if the ruler catches you.</em>`,
          `A synthetic experiment where the ground truth is known: how often is a deliberately altered pivot detected, and how often does the test flag an unaltered pivot? Synthetic results describe this experiment, not any real dataset — and small alterations are hard to see.`,
          `<span class="stamp ok">200 values per trial · 40 trials per config</span>`)}
        <div class="grid split" style="align-items:start">
          <section class="panel tape">
            <div class="section-title" style="margin-top:0"><h3>One trial</h3><span class="note">${K.esc(curMech ? curMech.l : "")}</span></div>
            <div style="display:grid;grid-template-columns:1fr 1fr;gap:14px">
              <div>
                <div class="field"><label for="vMech">Alteration mechanism</label>
                  <select id="vMech">${mechanisms.map((m) => `<option value="${m.v}" ${d.mechanism === m.v ? "selected" : ""}>${K.esc(m.l)}</option>`).join("")}</select></div>
                <div class="field"><label for="vN">n values per trial</label>
                  <input id="vN" type="range" min="300" max="4000" step="100" value="${d.n}">
                  <span class="mono" style="margin-left:6px">${d.n}</span></div>
                <div class="field"><label for="vRate">Alteration rate</label>
                  <input id="vRate" type="range" min="0" max="0.5" step="0.01" value="${d.rate}">
                  <span class="mono" style="margin-left:6px">${(d.rate * 100).toFixed(0)}%</span></div>
                <div class="field"><label for="vSeed">Seed</label><input id="vSeed" type="number" min="0" max="99999" value="${d.seed}"></div>
              </div>
              <div class="bars" style="display:flex;flex-direction:column;gap:8px;justify-content:center">
                <button class="btn primary" type="button" id="vRun">40 trials</button>
                <button class="btn" type="button" id="vSweep" style="grid-column:1/-1">Sweep rate 0 → 50%</button>
                <button class="btn ghost" type="button" id="vReset" style="grid-column:1/-1">Reset to default</button>
                <div class="note-card" style="grid-column:1/-1">The needle simulates the distribution, applies the chosen alteration, then runs a first-digit chi-square test (α = 0.05). A “detected” trial has significant p and a meaningful MAD drift. Synthetic results are not proof of real-world performance.</div>
              </div>
            </div>
            <div class="stat-strip" style="margin-top:14px">
              ${K.stat("Trials", K.fmt(stats.length), d.running ? "running…" : "")}
              ${K.stat("Rate", K.pct(d.rate), "altered")}
              ${K.stat("Base", "log-uniform 10^U(0,6)", "200 to 10⁶")}
            </div>
          </section>
          <aside class="grid" style="align-content:start">
            <section class="panel">
              <div class="section-title" style="margin-top:0"><h3>Rate sweep</h3><span class="note">${K.fmt(d.sweep ? d.sweep.length : 0)} rate points</span></div>
              ${sweepHtml}
            </section>
            <section class="panel tight">
              <div class="section-title" style="margin-top:0"><h3>Reading the pencil</h3></div>
              <dl class="kv">
                <dt>Detection</dt><dd>share of trials where the test rejects Benford</dd>
                <dt>False positive</dt><dd>rate at 0% alteration (the baseline)</dd>
                <dt>At low rate</dt><dd>small changes are often invisible — this is a real limitation, not a bug</dd>
                <dt>Round numbers</dt><dd>easily seen, shown by the experiment</dd>
                <dt>Extreme values</dt><dd>easily seen</dd>
              </dl>
            </section>
          </aside>
        </div>
        <div class="grid split-rev" style="margin-top:18px">
          <section class="panel"><h3 style="margin-top:0">Trial results</h3>${resultHtml}</section>
          <section>
            <div class="section-title" style="margin-top:0"><h3>From the existing R experiment</h3><span class="note">published runs, 200 replicates each</span></div>
            <div class="grid" style="margin-top:10px">${K.D.experiment.curve.map((c) => {
              const series = [{ color: K.C.oxide, label: c.manipulation, values: c.levels.map((_) => "0").map((_, idx) => c.detection[idx]) }];
              return `<div class="chart" style="margin-bottom:12px">${K.C.lineChart(c.levels.map((v, i) => String(Math.round(v * 100)) + "%"), series, {
                title: c.manipulation, width: 220, height: 150, yFormat: K.pct, yLabel: "detection"
              })}<div class="chart-cap"><span class="chip glass">${K.esc(c.manipulation)}</span><span>$n: ${K.fmt(c.levels[0])}–${K.fmt(c.levels[Math.min(c.levels.length - 1, 1)])}</span></div></div>`;
            }).join("")}
              <p class="caption">Partial alteration is the honest failure mode: the experiment reports near-zero detection for small changes, which is the right answer and the right warning about over-claiming.</p>
            </section>
          </div>
        </div>
        <div style="display:flex;justify-content:space-between;gap:10px;margin-top:22px">
          <button class="btn" type="button" data-route="peers">← Peers</button>
          <button class="btn primary" type="button" data-route="export">Export →</button>
        </div>
      </div>`;

      function mean(arr, key) { return arr.reduce((s, v) => s + (v[key] || 0), 0) / Math.max(1, arr.length); }
    },
    bind(root) {
      const K = window.Kit, d = K.state.validation;
      const PRNG = mulberry32;
      root.querySelectorAll("[data-route]").forEach((b) => {
        if (b.dataset.route === "vMech") b.addEventListener("change", () => { d.mechanism = b.value; d.seed = Date.now(); K.render(); });
        if (b.dataset.route === "vN") { const t = root.querySelector("#vN .mono"); b.addEventListener("input", () => { d.n = Number(b.value); if (t) t.textContent = b.value; }); }
      });
      root.addEventListener("input", (e) => {
        if (e.target.id === "vRate") {
          d.rate = Number(e.target.value);
          const t = root.querySelector("#vRate .mono"); if (t) t.textContent = (e.target.value * 100).toFixed(0) + "%";
          d.seed = Date.now();
          K.render();
        }
        if (e.target.id === "vSeed") { d.seed = Number(e.target.value) || 2025; K.render(); }
      });
      function mulberry32(a) {
        return function () {
          let t = (a += 0x6D2B79F5);
          t = Math.imul(t ^ t >>> 15, t | 1);
          t ^= t + Math.imul(t ^ t >>> 7, t | 61);
          return ((t ^ t >>> 14) >>> 0) / 4294967296;
        };
      }
      function runTrials() {
        const r = runRec(d.mechanism, d.seed, d.n, d.rate, 40);
        d.result = r.trials;
        d.sweep = null;
        K.render();
      }
      function runRec(mechanism, seed, n, rate, trials) {
        const results = [];
        for (let t = 0; t < trials; t++) {
          const run = [...Array(n).keys()].map((i) => LogUniform(seed + i, 0, 6));
          const (alters, base2) = alter(run, mechanism, rate, seed + t);
          const bt = K.A && K.A.benfordTest ? K.A.benfordTest(base2.map((v) => Math.pow(10, v)), "first") : { p: 1, chi2: 0, mad: 0, N: 0 };
          results.push({
            idx: t + 1,
            altCount: alters,
            base: run,
            base2: base2,
            p: bt.p,
            x2: bt.chi2 || 0,
            mad: bt.mad != null ? Math.abs(bt.mad) : 0,
            n,
            detected: BT p: !isNaN(bt.p) && isFinite(bt.p) && bt.p < 0.05 && bt.mad > 0.006
          });
        }
        const p0Trials = results.filter((r) => r.altCount === 0);
        const falsePositive = p0Trials.length ? p0Trials.filter((r) => r.detected).length / p0Trials.length : 0;
        results.forEach((r) => (r.falsePositive = falsePositive));
        return { trials: results };
      }
      function LogUniform(seed, lo, hi) {
        const rnd = mulberry32(seed); const u = rnd() * 0.99999; return lo + (hi - lo) * u;
      }
      function alter(base, mechanism, rate, seed) {
        const rnd = mulberry32(seed + 1);
        let altered = 0, out = base.slice(), alters = [];
        for (let i = 0; i < base.length; i++) {
          if (rnd() >= rate) { alters.push(0); out[i] = base[i]; continue; }
          const v = base[i];
          let nv;
          switch (mechanism) {
            case "round_number":
              const k = Math.max(Math.floor(Math.log10(Math.abs(v))) - 2, Math.floor(Math.log10(Math.abs(v))) - 1);
              const pk = Math.pow(10, k);
              nv = Math.round(v / pk) * pk; if (!isFinite(nv) || nv === 0) nv = v;
              break;
            case "leading_bias":
              const e = Math.floor(Math.log10(Math.abs(v)));
              const m2 = v / Math.pow(10, e) || 1;
              nv = Math.pow(10, e) * (1 + rnd() * 0.95 * (1 - m2) + m2 * 0.05);
              break;
            case "partial":
              nv = v * (0.92 + rnd() * 0.16);
              break;
            case "extreme":
              nv = v * (5 + rnd() * 195);
              break;
            case "duplicate":
              const ri = Math.floor(rnd() * base.length);
              nv = base[ri];
              break;
            default: nv = v;
          }
          out[i] = nv; alters.push(1);
        }
        return alters.length;
      }
      if (root.querySelector("#vRun")) root.querySelector("#vRun").addEventListener("click", runTrials);
      if (root.querySelector("#vSweep")) root.querySelector("#vSweep").addEventListener("click", () => {
        const rates = [0, 0.02, 0.05, 0.1, 0.2, 0.3, 0.4, 0.5];
        const sweepRes = rates.map((rate) => {
          if (rate === 0) {
            const r = runRec(d.mechanism, d.seed, d.n, 0, 40);
            return { rate, detected: r.trials.filter((x) => x.detected).length / Math.max(1, r.trials.length), falsePositive: falsePositiveFrom(r.trials, 0), n: d.n, trials: r.trials };
          }
          const r = runRec(d.mechanism, d.seed, d.n, rate, 40);
          return { rate, detected: r.trials.filter((x) => x.detected).length / Math.max(1, r.trials.length), falsePositive: 0, n: d.n, trials: r.trials };
        });
        d.sweep = sweepRes;
        d.result = null;
        K.render();
      });
      if (root.querySelector("#vReset")) root.querySelector("#vReset").addEventListener("click", () => {
        d.mechanism = "round_number"; d.n = 2000; d.rate = 0.2; d.seed = 2025;
        d.result = null; d.sweep = null; K.render();
      });
      function falsePositiveFrom(runs, rate) { return runs.filter((r) => r.altCount === 0 && r.detected).length / Math.max(1, runs.filter((r) => r.altCount === 0).length); }
    }
  };
})();
