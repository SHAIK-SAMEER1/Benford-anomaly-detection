/* ==========================================================================
   app.js — the case shell: routing, state, staging, drawer, shared UI
   ========================================================================== */
(function () {
  "use strict";

  const D = window.BENFORD_DATA;
  const C = window.KitCharts;
  const A = window.KitAnalysis;
  const V = window.KitViews || {};
  if (!D) {
    document.getElementById("view").innerHTML = `<div class="error-card">
      <h2>The data payload is missing</h2>
      <p>Open <code>web/assets/js/data.js</code>. If it is absent, run
      <code>Rscript scripts/build_web_data.R</code> from the project root.</p></div>`;
    return;
  }

  const TOOLS = [
    { id: "overview", no: "01", name: "The Case", sub: "objective & contents", icon: "case" },
    { id: "data", no: "02", name: "Data Desk", sub: "stage, inspect, load", icon: "square" },
    { id: "quality", no: "03", name: "The Caliper", sub: "quality & suitability", icon: "caliper" },
    { id: "benford", no: "04", name: "The Ruler", sub: "digit distribution", icon: "ruler" },
    { id: "review", no: "05", name: "The Loupe", sub: "record-level evidence", icon: "loupe" },
    { id: "peers", no: "06", name: "The Compass", sub: "peers & trends", icon: "compass" },
    { id: "validation", no: "07", name: "The Pencil", sub: "controlled validation", icon: "pencil" },
    { id: "export", no: "08", name: "The Seal", sub: "audit & export", icon: "seal" }
  ];

  const ICONS = {
    case: `<path d="M4 8h16v11H4zM9 8V5h6v3M4 12h16M9 12v2h6v-2"/>`,
    square: `<path d="M5 3h10l4 4v14H5zM15 3v5h5M8 12h8M8 16h5"/>`,
    caliper: `<path d="M4 4v16M4 8h16M20 8v12M8 8v4M12 8v6M16 8v4M4 20h16"/>`,
    ruler: `<path d="M3 9h18v6H3zM7 9v3M11 9v4M15 9v3M19 9v4"/>`,
    loupe: `<circle cx="10" cy="10" r="6"/><path d="M14.5 14.5L21 21M8 10h4M10 8v4"/>`,
    compass: `<circle cx="12" cy="12" r="8"/><path d="M12 4v2M12 18v2M4 12h2M18 12h2M15.5 8.5l-2 5-5 2 2-5z"/>`,
    pencil: `<path d="M4 20l4-1 11-11-3-3L5 16zM14 7l3 3M4 20l1-4"/>`,
    seal: `<circle cx="12" cy="10" r="6"/><path d="M9 15l-1 6 4-2 4 2-1-6M9.5 10l1.5 1.5 3.5-3.5"/>`
  };
  const icon = (name, cls) => `<svg class="${cls || ""}" viewBox="0 0 24 24" aria-hidden="true">${ICONS[name] || ICONS.case}</svg>`;

  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));
  const esc = C.esc;
  const fmt = (v, d = 0) => (v == null || !isFinite(v)) ? "—" : Number(v).toLocaleString("en-US", { maximumFractionDigits: d, minimumFractionDigits: d });
  const pct = (v, d = 1) => (v == null || !isFinite(v)) ? "—" : (100 * v).toFixed(d) + "%";
  const pval = (p) => {
    if (p == null || !isFinite(p)) return "—";
    if (p === 0) return "< 1e-300";
    if (p < 0.0001) return p.toExponential(1).replace("e", "e");
    return p.toFixed(4);
  };
  const money = C.money;
  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  const byId = (id) => allDatasets()[id];

  const stored = (() => {
    try { return sessionStorage.getItem("bfk.active"); } catch (e) { return null; }
  })();
  const state = {
    route: "overview",
    activeId: (D.datasets[stored] ? stored : D.defaultDataset) || Object.keys(D.datasets)[0],
    stagedId: null,
    uploads: {},
    benford: { kind: "first", family: "all", adjust: "bh", digit: 1, alpha: 0.05 },
    review: { family: "all", score: 0, q: "", group: "all", page: 0, tab: "records", model: "logistic", predQ: "" },
    peers: { group: 0, series: 0 },
    validation: { mechanism: "round_number", n: 2000, rate: 0.2, seed: 2025, trials: 40, result: null, sweep: null, running: false },
    export: {}
  };

  function allDatasets() {
    return Object.assign({}, D.datasets, state.uploads);
  }
  function active() {
    return allDatasets()[state.activeId] || D.datasets[D.defaultDataset] || Object.values(D.datasets)[0];
  }

  /* -------------------------------------------------------------- router */
  function normalizeRoute(hash) {
    const r = String(hash || "").replace(/^#\/?/, "").split("/")[0];
    return TOOLS.some((t) => t.id === r) ? r : "overview";
  }
  function navigate(route, opts = {}) {
    if (!route) return;
    if (state.route === route && !opts.force) { window.scrollTo({ top: 0, behavior: "smooth" }); return; }
    state.route = route;
    if (location.hash.replace(/^#\/?/, "") !== route) {
      try { history.pushState(null, "", "#" + route); } catch (e) { location.hash = route; }
    }
    render();
    const view = $("#view");
    if (view) view.scrollTop = 0;
    if (!opts.silent) window.scrollTo({ top: 0, behavior: "smooth" });
  }

  function stageDataset(id) {
    if (!allDatasets()[id]) return;
    state.stagedId = id;
    render();
    openDatasetDrawer(id);
  }
  function loadStaged() {
    const id = state.stagedId;
    if (!id || !allDatasets()[id]) { toast("Nothing is staged. Choose a dataset first."); return; }
    state.activeId = id;
    state.stagedId = null;
    if (D.datasets[id]) {
      try { sessionStorage.setItem("bfk.active", id); } catch (e) { /* private mode */ }
    }
    closeDrawer();
    toast(`<b>Loaded:</b> ${esc(allDatasets()[id].name)}. Every instrument now reads this dataset.`);
    render();
  }
  function discardStaged() {
    state.stagedId = null;
    closeDrawer();
    render();
    toast("Staged selection discarded. The active dataset did not change.");
  }

  /* -------------------------------------------------------------- chrome */
  function renderNav() {
    const nav = $("#tray");
    nav.innerHTML = TOOLS.map((t, i) => `
      <button class="tool ${t.id === state.route ? "is-active" : ""}" type="button"
        data-route="${t.id}" aria-current="${t.id === state.route ? "page" : "false"}"
        title="${esc(t.name)} — ${esc(t.sub)} (${i + 1})">
        <span class="num">${t.no}</span>
        <span class="tool-icon">${icon(t.icon)}</span>
        <span class="tool-name">${esc(t.name)}</span>
        <span class="pin" aria-hidden="true"></span>
        <span class="tool-sub">${esc(t.sub)}</span>
      </button>`).join("") + `
      <div class="tray-foot">
        <b>Active source</b><br>${esc(active().short)}<br>
        ${fmt(active().rows)} rows · ${fmt(active().cols)} cols<br>
        <span style="color:rgba(201,163,75,.55)">stage → load → screen</span>
      </div>`;
  }
  function renderSource() {
    const d = active();
    const el = $("#activeSource");
    el.innerHTML = `
      <div class="as-row"><span class="as-title">${esc(d.name)}</span><span>ACTIVE</span></div>
      <div class="as-row"><span>${fmt(d.rows)} rows · ${fmt(d.cols)} cols</span><span>${esc(d.kind)}</span></div>
      <div class="as-row"><span>${esc(d.measure ? d.measure.label : "no measure")}</span><span>${d.upload ? "session" : "verified file"}</span></div>`;
    el.title = `${d.source} — ${d.filters}`;
  }
  function renderAuditLine() {
    $("#auditLine").innerHTML = `<b>Dossier built</b> ${esc(D.generated)} · ${Object.keys(D.datasets).length} registered datasets · active: ${esc(active().short)} · no record leaves this browser`;
  }
  function render() {
    renderNav();
    renderSource();
    renderAuditLine();
    const view = $("#view");
    const def = V[state.route];
    view.innerHTML = def ? def.html() : `<div class="empty"><b>Instrument not found</b></div>`;
    if (def && def.bind) {
      try { def.bind(view); } catch (e) { console.error(e); toast("An instrument hit an error: " + esc(e.message)); }
    }
    view.focus({ preventScroll: true });
  }

  /* -------------------------------------------------------------- drawer */
  let lastFocus = null;
  function openDrawer(kicker, title, html) {
    lastFocus = document.activeElement;
    $("#drawerKicker").textContent = kicker;
    $("#drawerTitle").textContent = title;
    $("#drawerBody").innerHTML = html;
    $("#drawer").classList.add("is-open");
    $("#drawer").setAttribute("aria-hidden", "false");
    $("#scrim").hidden = false;
    document.body.style.overflow = "hidden";
    setTimeout(() => { const b = $("#drawer .btn.primary"); if (b) b.focus(); }, 80);
  }
  function closeDrawer() {
    $("#drawer").classList.remove("is-open");
    $("#drawer").setAttribute("aria-hidden", "true");
    if ($("#modal").hidden) { $("#scrim").hidden = true; document.body.style.overflow = ""; }
    if (lastFocus) { try { lastFocus.focus(); } catch (e) {} }
  }
  function openModal(kicker, title, html) {
    $("#modalKicker").textContent = kicker;
    $("#modalTitle").textContent = title;
    $("#modalBody").innerHTML = html;
    $("#modal").hidden = false;
    document.body.style.overflow = "hidden";
    setTimeout(() => { const b = $("#modalClose"); if (b) b.focus(); }, 40);
  }
  function closeModal() {
    $("#modal").hidden = true;
    if (!$("#drawer").classList.contains("is-open")) document.body.style.overflow = "";
  }
  function toast(html, ms = 3600) {
    const el = $("#toast");
    el.innerHTML = html;
    el.classList.add("is-on");
    clearTimeout(toast._t);
    toast._t = setTimeout(() => el.classList.remove("is-on"), ms);
  }

  function datasetDrawer(d) {
    const q = d.quality || {};
    const methods = (d.available || []).map((m) => `<span class="chip ghost">${esc(m)}</span>`).join(" ");
    const schema = (d.schema || []).slice(0, 18).map((s) => `<tr>
      <td class="strong">${esc(s.name)}</td><td><span class="chip ghost">${esc(s.role)}</span></td>
      <td>${esc(s.type)}</td><td class="r">${s.missingPct == null ? "—" : s.missingPct.toFixed(1) + "%"}</td>
      <td class="muted">${esc(s.sample || "")}</td></tr>`).join("");
    let preview = "";
    if (d.preview && d.preview.length) {
      const cols = (d.columns || []).slice(0, 7);
      preview = `<h3>First rows (not yet active)</h3><div class="table-wrap"><table class="data compact">
        <thead><tr>${cols.map((c) => `<th>${esc(c)}</th>`).join("")}</tr></thead>
        <tbody>${d.preview.slice(0, 6).map((r) => `<tr>${(d.columns || []).slice(0, 7).map((c, i) => `<td>${esc(String(r[i] == null ? "" : r[i]).slice(0, 38))}</td>`).join("")}</tr>`).join("")}</tbody></table></div>`;
    } else if (d.anomalies && d.anomalies.sample && d.anomalies.sample.length) {
      preview = `<h3>Highest-priority records in this file</h3><div class="table-wrap"><table class="data compact">
        <thead><tr><th>Reference</th><th class="r">Amount</th><th>Peer group</th><th class="r">Priority</th></tr></thead>
        <tbody>${d.anomalies.sample.slice(0, 5).map((r) => `<tr><td>${esc((r.ref || "").slice(0, 30))}</td><td class="r">${money(r.amount)}</td><td class="muted">${esc((r.peer || "").slice(0, 32))}</td><td class="r">${fmt(r.score)}</td></tr>`).join("")}</tbody></table></div>`;
    }
    openDrawer("Staged dataset · not yet active", d.name, `
      <div class="note-card oxide"><b>Preview only.</b> The analysis still uses
        <b>${esc(active().name)}</b>. Load this dataset to commit the switch.</div>
      <div class="grid two" style="margin-top:14px">
        <div class="stat"><span class="k">Rows</span><span class="v">${fmt(d.rows)}</span></div>
        <div class="stat"><span class="k">Columns</span><span class="v">${fmt(d.cols)}</span></div>
        <div class="stat"><span class="k">Measure</span><span class="v" style="font-size:12px">${esc(d.measure ? d.measure.label : "—")}</span></div>
        <div class="stat"><span class="k">Kind</span><span class="v" style="font-size:12px">${esc(d.kind)}</span></div>
      </div>
      <h3>Provenance</h3>
      <dl class="kv">
        <dt>Source</dt><dd>${esc(d.source)}</dd>
        <dt>File</dt><dd>${esc(d.file)}</dd>
        <dt>Path</dt><dd>${esc(d.path)}</dd>
        <dt>Filters</dt><dd>${esc(d.filters)}</dd>
        <dt>Label</dt><dd>${d.model ? esc(d.model.target + " · positive = " + d.model.positiveClass) : "no fraud label"}</dd>
        <dt>Missing cells</dt><dd>${q.missingPct == null ? "—" : q.missingPct.toFixed(2) + "%"}</dd>
        <dt>Methods</dt><dd>${methods}</dd>
      </dl>
      <h3>Interpretation caveat</h3>
      <div class="note-card">${esc(d.caveat)}</div>
      ${preview}
      <h3>Fields (first 18)</h3>
      <div class="table-wrap"><table class="data compact">
        <thead><tr><th>Column</th><th>Role</th><th>Type</th><th class="r">Missing</th><th>Example</th></tr></thead>
        <tbody>${schema || `<tr><td colspan="5" class="muted">No schema supplied.</td></tr>`}</tbody></table></div>
      <div class="drawer-actions">
        <button class="btn primary" type="button" id="loadStagedBtn">Load this dataset</button>
        <button class="btn" type="button" id="discardStagedBtn">Cancel</button>
      </div>`);
    const lb = $("#loadStagedBtn");
    if (lb) lb.addEventListener("click", loadStaged);
    const db = $("#discardStagedBtn");
    if (db) db.addEventListener("click", discardStaged);
  }

  /* -------------------------------------------------------------- upload */
  const MAX_UPLOAD = 30 * 1024 * 1024;
  let uploadBusy = false;
  function handleFiles(files) {
    if (!files || !files.length || uploadBusy) return;
    const file = files[0];
    if (!/\.(csv|txt)$/i.test(file.name)) { toast("Choose a .csv or .txt file. Excel workbooks are read by the R pipeline, not the browser."); return; }
    if (file.size > MAX_UPLOAD) { toast(`That file is ${(file.size / 1048576).toFixed(1)} MB. The browser analyser accepts up to 30 MB; larger files belong in the R pipeline.`); return; }
    uploadBusy = true;
    toast(`<b>Reading</b> ${esc(file.name)} — parsing in this tab.`);
    const reader = new FileReader();
    reader.onload = () => {
      setTimeout(() => {
        try {
          const profile = A.buildProfile(file.name, String(reader.result), {});
          state.uploads[profile.id] = profile;
          state.stagedId = profile.id;
          render();
          datasetDrawer(profile);
          toast(`<b>Preview ready.</b> ${fmt(profile.rows)} rows parsed. Nothing is active until you load it.`);
        } catch (e) {
          console.error(e);
          toast(`<b>Could not analyse that CSV.</b> ${esc(e.message)}`);
        } finally { uploadBusy = false; }
      }, 60);
    };
    reader.onerror = () => { uploadBusy = false; toast("The browser could not read that file."); };
    reader.readAsText(file);
  }

  /* -------------------------------------------------------------- downloads */
  function downloadText(filename, text, mime = "text/plain;charset=utf-8") {
    const blob = new Blob([text], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = filename;
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 500);
  }
  function csvCell(v) {
    if (v == null) return "";
    const s = Array.isArray(v) ? v.join(" | ") : String(v);
    return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }
  function downloadCSV(filename, rows) {
    if (!rows || !rows.length) { toast("Nothing to export for this selection."); return; }
    const cols = Array.from(new Set(rows.flatMap((r) => Object.keys(r))));
    const text = [cols.join(",")].concat(rows.map((r) => cols.map((c) => csvCell(r[c])).join(","))).join("\r\n");
    downloadText(filename, text, "text/csv;charset=utf-8");
  }
  function downloadJSON(filename, obj) {
    downloadText(filename, JSON.stringify(obj, null, 2), "application/json");
  }

  /* -------------------------------------------------------------- shared pieces */
  function pageHead(no, kicker, title, lead, side) {
    return `<header class="page-head">
      <div>
        <p class="page-kicker">Instrument ${no} · ${esc(kicker)}</p>
        <h2>${title}</h2>
        ${lead ? `<p class="lead">${lead}</p>` : ""}
      </div>
      <div class="head-side">
        <span class="page-no" aria-hidden="true">${no}</span>
        ${side || ""}
      </div>
    </header>`;
  }
  function stat(k, v, s, cls = "") {
    return `<div class="stat ${cls}"><span class="k">${esc(k)}</span><span class="v">${v}</span>${s ? `<span class="s">${s}</span>` : ""}</div>`;
  }
  function section(title, note, fig) {
    return `<div class="section-title"><h3>${title}</h3><span class="note">${fig ? `<span class="fig">${fig}</span> · ` : ""}${note || ""}</span></div>`;
  }
  function tierChip(tier) {
    const cls = tier === "Reliable" ? "teal" : tier === "Caution" ? "brass" : "oxide";
    return `<span class="chip ${cls}">${esc(tier || "Not run")}</span>`;
  }
  function flagChip(flag) {
    if (!flag) return `<span class="chip ghost">—</span>`;
    if (/^No significant/.test(flag)) return `<span class="chip ghost">no significant deviation</span>`;
    if (/^Not assessed/.test(flag)) return `<span class="chip ghost">not assessed</span>`;
    if (/material/.test(flag)) return `<span class="chip oxide">material deviation</span>`;
    if (/small/.test(flag)) return `<span class="chip brass">significant, small</span>`;
    return `<span class="chip">${esc(flag)}</span>`;
  }
  function verdictChip(verdict) {
    const cls = /^Suitable/.test(verdict) ? "teal" : /caution/i.test(verdict) ? "brass" : /Insufficient/i.test(verdict) ? "ghost" : "oxide";
    return `<span class="chip ${cls} lg">${esc(verdict)}</span>`;
  }
  function methodBoundary() {
    return `<div class="note-card oxide"><b>Interpretation boundary.</b> A review candidate is not proof of fraud.
      Statistical deviation, a high robust score, a round amount, or a repeated signature are screening prompts.
      They require human review and independent evidence. This kit never labels a transaction fraudulent.</div>`;
  }
  function noMethod(title, reason) {
    return `<div class="empty"><b>${esc(title)}</b>${esc(reason)}</div>`;
  }
  function openRecord(record) {
    const d = active();
    const groupContext = (d.groups && d.groups.first || []).find((g) =>
      (record.subagency && g.group === record.subagency) ||
      (record.peer && g.group === record.peer) ||
      (record.agency && g.group === record.agency));
    const reasons = record.reasons || [];
    const fam = record.families || [];
    const contextLine = groupContext
      ? `<div class="note-card ${/No significant/.test(groupContext.flag) ? "" : "oxide"}">
          <b>Group-level Benford context.</b> ${esc(groupContext.group)} has N = ${fmt(groupContext.n)},
          ${groupContext.p == null ? "no valid chi-square p-value" : "raw p = " + pval(groupContext.p)} and
          MAD = ${groupContext.mad == null ? "—" : groupContext.mad.toFixed(4)} (${esc(groupContext.tier)}).
          This is context for the record, not an independent transaction-level charge.</div>`
      : `<div class="note-card"><b>No matching group-level test.</b> The record's peer group is too specific or too small for a valid digit test.</div>`;
    openDrawer("Record-level evidence", record.ref || "Review candidate", `
      <div class="stamp">Review candidate · not a verdict</div>
      <div class="grid three" style="margin-top:12px">
        ${stat("Amount", money(record.amount), esc(record.date || ""))}
        ${stat("Priority", fmt(record.score), "0–99 · not a probability")}
        ${stat("Peer group", "N " + fmt(record.peerN), esc(record.peerLevel || ""))}
      </div>
      <h3>Why it surfaced</h3>
      <div class="bar-list">${reasons.length ? reasons.map((r) => `<div class="note-card">${esc(r)}</div>`).join("") : `<div class="note-card">No explanation is attached.</div>`}</div>
      <h3>Evidence families</h3>
      <div class="chips">${["magnitude", "rounding", "duplication", "quality"].map((f) =>
        `<span class="chip ${fam.includes(f) ? "oxide" : "ghost"}">${f}: ${fam.includes(f) ? "present" : "not flagged"}</span>`).join("")}</div>
      <div class="note-card" style="margin-top:10px">Families are displayed separately on purpose. A magnitude flag and a rounding flag are not two independent pieces of proof.</div>
      <h3>Peer statistics</h3>
      <dl class="kv">
        <dt>Peer group</dt><dd>${esc(record.peer || "—")}</dd>
        <dt>Comparison size</dt><dd>${fmt(record.peerN)}</dd>
        <dt>Peer median</dt><dd>${money(record.median)}</dd>
        <dt>Modified Z</dt><dd>${record.z == null ? "—" : Number(record.z).toFixed(2)}</dd>
        <dt>Peer percentile</dt><dd>${record.percentile == null ? "—" : Number(record.percentile).toFixed(1) + "%"}</dd>
        <dt>Signature repeats</dt><dd>${fmt(record.sigCount)}</dd>
        <dt>Same amount on award</dt><dd>${fmt(record.awardAmountCount)}</dd>
      </dl>
      ${contextLine}
      <h3>Metadata</h3>
      <dl class="kv">
        <dt>Agency</dt><dd>${esc(record.agency || "—")}</dd>
        <dt>Subagency</dt><dd>${esc(record.subagency || "—")}</dd>
        <dt>Award</dt><dd>${esc(record.award || "—")}</dd>
        <dt>Recipient</dt><dd>${esc(record.recipient || "—")}</dd>
        <dt>Code</dt><dd>${esc(record.naics || "—")}</dd>
        <dt>Description</dt><dd>${esc(record.description || "—")}</dd>
      </dl>
      <h3>What would change this assessment</h3>
      <div class="note-card teal">A documented contract modification, a matched de-obligation and re-obligation pair,
        a unit-price schedule that explains the amount, or evidence that the repeated signature is a batch correction.
        Without that, the correct conclusion is “worth a look”, not “fraud”.</div>
      <div class="drawer-actions"><button class="btn" type="button" id="drawerDone">Close</button></div>`);
    const b = $("#drawerDone"); if (b) b.addEventListener("click", closeDrawer);
  }

  function helpHtml() {
    return `<p class="muted" style="font:400 11px var(--mono)">Keyboard: <b>1–8</b> instruments · <b>D</b> data desk · <b>?</b> this note · <b>Esc</b> close.</p>
      <h3>The two layers</h3>
      <ul>
        <li><b>Group screening.</b> Does a group's digit distribution differ from Benford? Uses chi-square, expected-count validity, MAD, residuals and multiple-testing correction.</li>
        <li><b>Record screening.</b> Is a transaction unusual relative to peers? Uses log-scale IQR, modified Z, percentiles, rounding and duplicate signatures.</li>
      </ul>
      <p>These layers answer different questions. A group can look unusual while no individual record is exceptional; a record can be unusual while its group looks normal.</p>
      <h3>What the stamps mean</h3>
      <ul>
        <li><span class="chip teal">Reliable</span> every expected count ≥ 5.</li>
        <li><span class="chip brass">Caution</span> Cochran's rule is met; interpret with care.</li>
        <li><span class="chip oxide">Not run</span> the sample or expected counts cannot support a valid test. This is not evidence of anomaly.</li>
      </ul>
      <h3>What this kit refuses to do</h3>
      <ul>
        <li>It does not call a record fraudulent.</li>
        <li>It does not use identifiers, PCA components, category codes or bounded percentages as Benford inputs.</li>
        <li>It does not use a model trained on one benchmark to score another dataset.</li>
        <li>It does not present a review priority as a calibrated probability.</li>
      </ul>
      <div class="note-card oxide"><b>Boundary.</b> ${esc(D.method.boundary)}</div>`;
  }

  function boundaryHtml() {
    return `<p>${esc(D.method.boundary)}</p>
      <h3>Why Benford is not a fraud detector</h3>
      <p>Benford's Law describes the leading digits of many naturally occurring, multi-scale positive quantities. A deviation can come from caps, price thresholds, rounding, revisions, constrained ranges, or a non-multiplicative process. It cannot identify who altered what, and it cannot establish intent.</p>
      <h3>What the evidence in this kit can support</h3>
      <ul>
        <li>“This group's digit distribution differs materially from the reference.”</li>
        <li>“This record is unusually large relative to its peer group.”</li>
        <li>“This signature is repeated, which may be a legitimate batch event.”</li>
        <li>“The data are insufficient for a reliable test.”</li>
      </ul>
      <h3>What it cannot support</h3>
      <ul>
        <li>“This transaction is fraudulent.”</li>
        <li>“This recipient is dishonest.”</li>
        <li>“The model's score is a probability of fraud in the real world.”</li>
      </ul>`;
  }

  /* -------------------------------------------------------------- global events */
  document.addEventListener("click", (e) => {
    const routeBtn = e.target.closest("[data-route]");
    if (routeBtn) { e.preventDefault(); navigate(routeBtn.dataset.route); return; }
    const stageBtn = e.target.closest("[data-stage]");
    if (stageBtn) { e.preventDefault(); stageDataset(stageBtn.dataset.stage); return; }
    if (e.target.closest("#openDataBtn")) { navigate("data"); return; }
    if (e.target.closest("#helpBtn") || e.target.closest("#boundaryBtn")) {
      if (e.target.closest("#boundaryBtn")) openModal("Interpretation boundary", "What this kit will not say", boundaryHtml());
      else openModal("Field notes", "How to read this kit", helpHtml());
      return;
    }
    if (e.target.closest("#drawerClose")) { closeDrawer(); return; }
    if (e.target.closest("#modalClose") || e.target === $("#modal")) { closeModal(); return; }
    if (e.target === $("#scrim")) { closeDrawer(); closeModal(); }
  });

  $("#scrim").hidden = true;
  document.addEventListener("keydown", (e) => {
    const tag = (e.target.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea" || tag === "select" || e.target.isContentEditable) return;
    if (e.key === "Escape") { closeDrawer(); closeModal(); return; }
    if (e.key === "?" || (e.shiftKey && e.key === "/")) { openModal("Field notes", "How to read this kit", helpHtml()); return; }
    if (e.key.toLowerCase() === "d") { navigate("data"); return; }
    const n = parseInt(e.key, 10);
    if (n >= 1 && n <= 8) navigate(TOOLS[n - 1].id);
  });
  window.addEventListener("hashchange", () => {
    const r = normalizeRoute(location.hash);
    if (r !== state.route) { state.route = r; render(); }
  });

  /* -------------------------------------------------------------- expose */
  window.Kit = {
    D, C, A, V, TOOLS, state, icon, esc, fmt, pct, pval, money, clamp, byId,
    active, allDatasets, navigate, stageDataset, loadStaged, discardStaged,
    render, toast, openDrawer, closeDrawer, openModal, closeModal,
    openDatasetDrawer: datasetDrawer, handleFiles, downloadCSV, downloadJSON, downloadText,
    pageHead, stat, section, tierChip, flagChip, verdictChip, methodBoundary, noMethod, openRecord,
    helpHtml, boundaryHtml
  };

  /* -------------------------------------------------------------- boot */
  state.route = normalizeRoute(location.hash);
  if (!location.hash) { try { history.replaceState(null, "", "#overview"); } catch (e) {} }
  if (!window.KitViews) {
    $("#view").innerHTML = `<div class="error-card"><h2>The view modules did not load</h2>
      <p>Check that <code>views_a.js</code> and <code>views_b.js</code> are present next to <code>app.js</code>.</p></div>`;
    return;
  }
  render();
})();
