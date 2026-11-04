/* #81 restricted official preview catalog publication. No filesystem paths from browser. */
(function () {
  'use strict';
  const panel = document.getElementById('catalog-panel');
  const review = document.getElementById('catalog-review');
  const publish = document.getElementById('catalog-publish');
  const approve = document.getElementById('catalog-approve');
  const status = document.getElementById('catalog-status');
  const details = document.getElementById('catalog-details');
  // Preserve scene-by-scene diagnostics even when shared CSS resets pre tags.
  details.style.whiteSpace = 'pre-wrap';
  details.style.overflowWrap = 'anywhere';
  const disclosure = document.createElement('details');
  const disclosureTitle = document.createElement('summary');
  disclosureTitle.textContent = 'Show changes and support details';
  details.replaceWith(disclosure); disclosure.append(disclosureTitle, details);
  const complete = document.getElementById('catalog-complete');
  const completeMessage = document.getElementById('catalog-complete-message');
  const receipt = document.getElementById('catalog-receipt');
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
    details.textContent = ''; details.hidden = false; disclosure.open = false; complete.hidden = true;
    try {
      proposal = await api('catalog/review', {});
      status.textContent = proposal.database_contract_review_required
        ? 'STOP: changes outside the permitted preview metadata require database-contract review. Nothing published.'
        : proposal.can_publish ? 'Review ready. Publication updates preview distribution evidence only; no database ingest.'
        : 'The master matches the current published catalog. No publication is needed.';
      disclosure.open = !!proposal.database_contract_review_required;
      if (proposal.can_publish) status.textContent = proposal.parser_validation ? 'Ready to publish. Parser validation passed for these exact previews. No database ingest required.' : 'Ready to publish. No blockers. Database contract unchanged. No database ingest required.';
      const lines = ['Source master folder: ' + (proposal.source_folder || 'Not reported'), 'Catalog evidence destination: ' + (proposal.catalog_evidence_folder || 'Not reported'), '', 'Database baseline: Run ' + proposal.baseline_run_id, 'Reviewed master digest: ' + proposal.master_digest];
      if (proposal.minimum_updater_version) lines.push('Required PC updater: ' + proposal.minimum_updater_version);
      const registrations = proposal.changes.filter(change => change.image_registration_only);
      if (registrations.length) lines.push('', 'Existing image evidence registered for ' + registrations.length + ' unchanged previews. No preview content changed in these entries.');
      for (const change of proposal.changes) {
        if (change.image_registration_only) continue;
        lines.push('', change.filename, change.database_contract_review_required ? (change.comparison_status === 'BASELINE_EVIDENCE_MISSING' ? 'STOP: original comparison evidence unavailable; no field change has been proven.' : 'STOP: protected content differs from the original baseline.') : (proposal.parser_validation ? 'Parser-validated preview update; database ingest is separate.' : 'Sequencing / presentation change — database contract unchanged'));
        const images = change.background_changes || [];
        const existing = images.filter(item => item.action === 'VERIFY_LINKED_BACKGROUND');
        if (existing.length) lines.push('Linked images verified: ' + existing.length);
        for (const item of images.filter(item => item.action !== 'VERIFY_LINKED_BACKGROUND')) lines.push(item.action.replaceAll('_', ' ') + ': ' + item.path);
        for (const item of change.metadata_changes) lines.push(item.prop_id + ' · ' + item.field + ': ' + JSON.stringify(item.before) + ' → ' + JSON.stringify(item.after));
      }
      if (proposal.parent_publication_id) lines.push('Current published catalog: ' + proposal.parent_publication_id);
      if (!proposal.changes.length) lines.push('', proposal.parent_publication_id ? 'No changes since the current published catalog.' : 'Master matches the registered database baseline. Initial registration is ready.');
      details.textContent = lines.join('\n');
    } catch (error) { proposal = null; status.textContent = 'Catalog review blocked. See all problems below.'; details.textContent = error.message; details.hidden = false; disclosure.open = true; }
    finally { busy = false; controls(); }
  });
  publish.addEventListener('click', async () => {
    if (busy || !proposal || !proposal.can_publish || !approve.checked) return;
    busy = true; controls();
    try {
      const result = await api('catalog/publish', {review_id: proposal.review_id, confirm_publish: true});
      const source = result.source;
      const changed = proposal.changes.length;
      const disposable = Object.hasOwn(source, 'disposable_original_evidence_id');
      completeMessage.textContent = (disposable ? 'Disposable test catalog published. Production was not changed.' : 'Official catalog published. Programmers can now update their PCs.') +
        ' Reviewed previews changed: ' + changed + '. No database ingest was run.';
      receipt.textContent = ['Catalog: ' + source.evidence_id, 'Published by: ' + source.published_by,
        'Published at: ' + source.published_at, 'Master digest: ' + source.source_manifest_sha256,
        'Database baseline: Run ' + source.run_id].join('\n');
      status.textContent = 'Official catalog published.';
      details.hidden = true;
      complete.hidden = false;
      complete.scrollIntoView({block: 'center', behavior: 'smooth'});
      complete.focus({preventScroll: true});
    } catch (error) { status.textContent = error.message + ' Review again before retrying.'; }
    finally { proposal = null; approve.checked = false; busy = false; controls(); }
  });
  api('dashboard').then(data => { panel.hidden = !data.access?.can_publish_catalog; })
    .catch(() => { panel.hidden = true; });
  controls();
})();

