/* Instrument 02 — The Data Desk */
(function () {
  "use strict";
  window.KitViews = window.KitViews || {};
  window.KitViews.data = {
    html() {
      const K = window.Kit, d = K.active(), st = K.state;
      const all = Object.values(K.allDatasets());
      const staged = st.stagedId ? K.byId(st.stagedId) : null;
      const card = (x) => {
        const isActive = x.id === d.id;
        const isStaged = x.id === st.stagedId;
        return `<article class="panel tight ${isActive ? "brass-edge" : ""}" style="${isStaged && !isActive ? "outline:2px dashed var(--oxide);outline-offset:2px" : ""}">
          <div style="display:flex;justify-content:space-between;gap:10px;align-items:flex-start">
            <div>
              <div class="chips" style="margin-bottom:5px">
                <span class="chip ${x.kind === "labelled" ? "plum" : x.upload ? "brass" : "teal"}">${K.esc(x.kind)}</span>
                ${isActive ? `<span class="chip brass">active</span>` : ""}
                ${isStaged && !isActive ? `<span class="chip oxide">staged</span>` : ""}
              </div>
              <h3 style="margin:0;font-size:17px">${K.esc(x.name)}</h3>
              <p class="caption" style="margin-top:2px">${K.esc(x.source)}</p>
            </div>
            <span class="mono" style="font-size:9px;color:var(--ink-3);text-align:right">${K.fmt(x.rows)}<br>rows</span>
          </div>
          <dl class="kv tight" style="margin:9px 0 10px">
            <dt>Measure</dt><dd>${K.esc(x.measure ? x.measure.label : "—")}</dd>
            <dt>Grouping</dt><dd>${K.esc(x.peers && x.peers.levels ? x.peers.levels[0] : "—")}</dd>
            <dt>Label</dt><dd>${x.model ? K.esc(x.model.target + " = " + x.model.positiveClass) : "none (unlabelled)"}</dd>
            <dt>File</dt><dd>${K.esc((x.file || "").slice(0, 46))}</dd>
          </dl>
          <div class="chips" style="margin-bottom:10px">${(x.available || []).map((a) => `<span class="chip ghost">${K.esc(a)}</span>`).join("")}</div>
          <div style="display:flex;gap:7px;flex-wrap:wrap">
            <button class="btn small ${isActive ? "" : "primary"}" type="button" data-stage="${x.id}">${isActive ? "Preview active" : "Preview & stage"}</button>
            ${isActive ? `<button class="btn small ghost" type="button" data-route="quality">Audit quality</button>` : ""}
          </div>
        </article>`;
      };
      return `<div class="view">
        ${K.pageHead("02", "Data desk", `Every instrument reads one <em style="color:var(--oxide)">active</em> dataset.`,
          `A preview is not a load. Staging changes nothing until you commit; when you commit, the source chip, every chart, table and export switch together. No raw file is modified.`,
          `<span class="stamp ok">${K.fmt(d.rows)} rows active</span>`)}
        <section class="panel dark" style="margin-bottom:16px">
          <div style="display:flex;flex-wrap:wrap;gap:18px;justify-content:space-between;align-items:flex-start">
            <div style="min-width:240px;flex:1">
              <p class="eyebrow">Now reading</p>
              <h3 style="color:#fff6df;font-size:26px;margin:2px 0 3px">${K.esc(d.name)}</h3>
              <p style="margin:0;font-size:12px;color:rgba(243,237,218,.7)">${K.esc(d.source)} · ${K.esc(d.filters)}</p>
            </div>
            <div class="stat-strip" style="flex:1;min-width:300px">
              <div class="stat" style="background:rgba(255,255,255,.05);border-color:rgba(201,163,75,.35)"><span class="k" style="color:rgba(201,163,75,.8)">File</span><span class="v" style="color:#f3edda;font-size:13px">${K.esc(d.file)}</span></div>
              <div class="stat" style="background:rgba(255,255,255,.05);border-color:rgba(201,163,75,.35)"><span class="k" style="color:rgba(201,163,75,.8)">Rows × cols</span><span class="v" style="color:#f3edda;font-size:17px">${K.fmt(d.rows)} × ${K.fmt(d.cols)}</span></div>
              <div class="stat" style="background:rgba(255,255,255,.05);border-color:rgba(201,163,75,.35)"><span class="k" style="color:rgba(201,163,75,.8)">Measure</span><span class="v" style="color:#f3edda;font-size:12px">${K.esc(d.measure ? d.measure.label : "—")}</span></div>
            </div>
          </div>
          <div class="chips" style="margin-top:12px">
            <span class="chip brass">LOADED</span>
            <span class="chip ghost" style="color:#f3edda">${d.upload ? "session-only upload" : "verified local file"}</span>
            <span class="chip ghost" style="color:#f3edda">${K.esc(d.kind)}</span>
            <span class="chip ghost" style="color:#f3edda">${d.sourceCheck || "source preserved"}</span>
          </div>
        </section>

        ${staged && staged.id !== d.id ? `<section class="panel oxide-edge" style="margin-bottom:16px">
          <div style="display:flex;flex-wrap:wrap;gap:14px;justify-content:space-between;align-items:center">
            <div><p class="eyebrow">Staged · not active</p><h3 style="margin:2px 0">${K.esc(staged.name)}</h3>
              <p class="caption">The dashboard still reads <b>${K.esc(d.name)}</b>. Loading commits the switch.</p></div>
            <div style="display:flex;gap:8px;flex-wrap:wrap">
              <button class="btn primary" type="button" id="loadStagedInline">Load this dataset</button>
              <button class="btn" type="button" id="previewStaged">Preview details</button>
              <button class="btn ghost" type="button" id="discardStagedInline">Discard</button>
            </div>
          </div></section>` : ""}

        <div class="grid split" style="align-items:start">
          <div>
            <div class="section-title" style="margin-top:0"><h3>Dataset registry</h3><span class="note">${all.length} independently analysed sources</span></div>
            <div class="grid two">${all.map(card).join("")}</div>
          </div>
          <aside class="grid" style="align-content:start">
            <section class="panel tape">
              <p class="eyebrow">Add a file</p>
              <h3>Analyse a CSV in this tab</h3>
              <p class="caption">Up to 30 MB and 200,000 rows for in-browser analysis. The file stays in memory; nothing is uploaded to a server. Larger or Excel files belong in the reproducible R pipeline.</p>
              <label class="dropzone" id="dropzone" for="csvFile">
                <span class="dz-icon"><svg viewBox="0 0 24 24"><path d="M4 16v4h16v-4M12 3v12M7 8l5-5 5 5"/></svg></span>
                <b>Drop a CSV here</b>
                <span>or click to choose · header row required</span>
                <input id="csvFile" type="file" accept=".csv,.txt" hidden>
              </label>
              <div class="note-card" style="margin-top:10px"><b>No silent labels.</b> A detected binary label is shown, but the static build does not train a model on an upload. Built-in labelled benchmarks have their own held-out evaluations.</div>
            </section>
            <section class="panel">
              <p class="eyebrow">State rules</p>
              <h3>Stage → load → screen</h3>
              <div class="timeline" style="margin-top:8px">
                <div class="step"><span class="dot">1</span><div><h4>Select</h4><p>The preview panel opens. The active source and every result remain unchanged.</p></div></div>
                <div class="step"><span class="dot">2</span><div><h4>Load</h4><p>One dataset becomes active. The source chip, tables, charts and exports all switch.</p></div></div>
                <div class="step"><span class="dot">3</span><div><h4>Screen</h4><p>Every instrument reads the same active dataset until another is loaded.</p></div></div>
              </div>
              <div class="note-card oxide">If parsing fails, the previous active dataset is preserved and the error is shown. Refreshing the page restores the last built-in source; session uploads do not persist.</div>
            </section>
            <section class="panel tight">
              <p class="eyebrow">Scope note</p>
              <p class="caption">Datasets are never combined into one table. A model trained on one benchmark is never applied to another dataset. Unlabelled sources receive no fabricated outcome labels.</p>
            </section>
          </aside>
        </div>
      </div>`;
    },
    bind(root) {
      const K = window.Kit;
      const dz = root.querySelector("#dropzone");
      const input = root.querySelector("#csvFile");
      if (input) input.addEventListener("change", () => K.handleFiles(input.files));
      if (dz) {
        ["dragenter", "dragover"].forEach((ev) => dz.addEventListener(ev, (e) => { e.preventDefault(); dz.classList.add("drag"); }));
        ["dragleave", "drop"].forEach((ev) => dz.addEventListener(ev, (e) => { e.preventDefault(); dz.classList.remove("drag"); }));
        dz.addEventListener("drop", (e) => K.handleFiles(e.dataTransfer.files));
      }
      const l = root.querySelector("#loadStagedInline"); if (l) l.addEventListener("click", K.loadStaged);
      const p = root.querySelector("#previewStaged"); if (p) p.addEventListener("click", () => K.openDatasetDrawer(K.state.stagedId));
      const x = root.querySelector("#discardStagedInline"); if (x) x.addEventListener("click", K.discardStaged);
    }
  };
})();
