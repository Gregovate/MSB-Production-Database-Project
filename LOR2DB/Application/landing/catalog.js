/* #81 restricted official preview catalog publication. No filesystem paths from browser. */
(function () {
  'use strict';
  const panel = document.getElementById('catalog-panel');
  const review = document.getElementById('catalog-review');
  const publish = document.getElementById('catalog-publish');
  const approve = document.getElementById('catalog-approve');
  const status = document.getElementById('catalog-status');
  const details = document.getElementById('catalog-details');
  let proposal = null;
  let busy = false;
  function controls() {
    review.disabled = busy;
    publish.disabled = busy || !proposal || !proposal.can_publish || !approve.checked;
  }
  async function api(path, body) {
    const options = {credentials: 'same-origin', cache: 'no-store'};
    if (body !== undefined) Object.assign(options, {method: 'POST', headers: {'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const response = await fetch('preflight/api/' + path, options);
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Catalog request failed');
    return data;
  }
  approve.addEventListener('change', controls);
  review.addEventListener('click', async () => {
    proposal = null; approve.checked = false; busy = true; controls();
    status.textContent = 'Checking the master files against the accepted database contract…';
    details.textContent = '';
    try {
      proposal = await api('catalog/review', {});
      status.textContent = proposal.can_publish
        ? 'Review ready. Publication updates preview distribution evidence only; no database ingest.'
        : 'STOP: changes outside the permitted preview metadata require database-contract review. Nothing published.';
      const lines = ['Database baseline: Run ' + proposal.baseline_run_id, 'Reviewed master digest: ' + proposal.master_digest];
      for (const change of proposal.changes) {
        lines.push('', change.filename, change.database_contract_review_required ? 'Database-contract review required' : 'Preview metadata / presentation change');
        for (const item of change.metadata_changes) lines.push(item.prop_id + ' · ' + item.field + ': ' + JSON.stringify(item.before) + ' → ' + JSON.stringify(item.after));
      }
      if (!proposal.changes.length) lines.push('', 'Master matches the registered database baseline. Initial registration is ready.');
      details.textContent = lines.join('\n');
    } catch (error) { proposal = null; status.textContent = error.message; }
    finally { busy = false; controls(); }
  });
  publish.addEventListener('click', async () => {
    if (busy || !proposal || !proposal.can_publish || !approve.checked) return;
    busy = true; controls();
    try {
      const result = await api('catalog/publish', {review_id: proposal.review_id, confirm_publish: true});
      status.textContent = 'Official catalog published. Programmers can update their PCs. Catalog: ' + result.source.evidence_id;
    } catch (error) { status.textContent = error.message + ' Review again before retrying.'; }
    finally { proposal = null; approve.checked = false; busy = false; controls(); }
  });
  api('dashboard').then(data => { panel.hidden = !data.access?.can_publish_catalog; })
    .catch(() => { panel.hidden = true; });
  controls();
})();
