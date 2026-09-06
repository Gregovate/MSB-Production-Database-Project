/* Manager-facing live Setup Procedure integration for the 2025 prototype. */

const instructionNotExpected = new Set([
  'OPS-FOOD',
  'OPS-RENTALS',
  'OPS-VOLTRAILER',
  'CMD-DELIVER'
]);

function ensureManagerProcedurePanel() {
  const section = document.getElementById('instruction-review-section');
  if (!section) return null;

  const heading = section.querySelector('.section-title h3');
  if (heading) heading.textContent = 'Setup Procedure';

  // The old three-folder governance cards were useful for engineering but are
  // too indirect for a Manager doing corrections. Keep the underlying folder
  // roles in the backend; present the action here.
  section.querySelector('.instruction-role-grid')?.setAttribute('hidden', '');
  section.querySelector('.publication-flow')?.setAttribute('hidden', '');
  section.querySelector('.instruction-boundary')?.setAttribute('hidden', '');

  section.querySelectorAll('.action-row button[disabled]').forEach((button) => {
    button.hidden = true;
  });

  let panel = document.getElementById('manager-procedure-panel');
  if (!panel) {
    panel = document.createElement('div');
    panel.id = 'manager-procedure-panel';
    panel.className = 'manager-procedure-panel';
    panel.innerHTML = `
      <div class="manager-procedure-card editable-procedure-card">
        <div class="eyebrow">Editable procedure</div>
        <div id="manager-editable-procedure" class="manager-procedure-content">
          <span class="muted">Checking for the editable Google Doc…</span>
        </div>
      </div>
      <div class="manager-procedure-card published-procedure-card">
        <div class="eyebrow">Published field PDF</div>
        <div id="manager-current-pdf" class="manager-procedure-content">
          <span class="muted">Checking for the current PDF…</span>
        </div>
      </div>
      <div id="manager-procedure-reminder" class="manager-procedure-reminder">
        If you edit the Google Doc, replace the published PDF before marking the instruction verified.
      </div>
      <div id="instruction-live-warnings" class="instruction-live-warnings"></div>
    `;

    const editGrid = section.querySelector('.instruction-edit-grid');
    if (editGrid) {
      editGrid.insertAdjacentElement('beforebegin', panel);
    } else {
      section.appendChild(panel);
    }
  }
  return panel;
}

function procedureActionLink(label, href, className = '') {
  if (!href) return '';
  return `<a class="procedure-action ${className}" href="${escapeHtml(href)}" target="_blank" rel="noopener">${escapeHtml(label)}</a>`;
}

function chooseEditableProcedureFiles(files) {
  const candidates = files || [];
  const sourceDocs = candidates.filter((file) => file.role === 'SOURCEDOC');
  if (sourceDocs.length) {
    return {
      files: sourceDocs,
      compatibilityFallback: false
    };
  }

  const archive = candidates.filter((file) => file.role === 'ARCHIVE');
  return {
    files: archive,
    compatibilityFallback: archive.length > 0
  };
}

function renderEditableProcedures(files) {
  const target = document.getElementById('manager-editable-procedure');
  if (!target) return;

  const selection = chooseEditableProcedureFiles(files);
  const selectedFiles = selection.files;

  if (!selectedFiles.length) {
    target.innerHTML = `
      <strong>No editable .gdoc source found for this Setup scope.</strong>
      <div class="procedure-help">Checked Procedures\\Setup\\SourceDocs first, then the existing Procedures\\Setup\\Archive legacy location.</div>
    `;
    return;
  }

  const compatibilityNotice = selection.compatibilityFallback
    ? `<div class="procedure-help"><strong>Legacy compatibility:</strong> no editable .gdoc was found in SourceDocs, so this existing Archive .gdoc is being used in place for the 2025 verification pass. The Setup system does not move it.</div>`
    : '';

  target.innerHTML = `${compatibilityNotice}${selectedFiles.map((file) => {
    const role = file.role === 'ARCHIVE'
      ? 'Legacy editable source in Archive'
      : 'Editable source in SourceDocs';
    const openAction = file.edit_url
      ? procedureActionLink('Open Editable Procedure', file.edit_url)
      : '<span class="procedure-action-disabled">Google Docs link could not be read from this .gdoc shortcut</span>';
    const exportAction = file.pdf_export_url
      ? procedureActionLink('Export Updated PDF', file.pdf_export_url, 'secondary')
      : '';

    return `
      <div class="procedure-source-item">
        <strong class="procedure-file-name">${escapeHtml(file.name || 'Unnamed .gdoc')}</strong>
        <div class="procedure-source-role">${escapeHtml(role)}</div>
        <div class="procedure-full-path">${escapeHtml(file.path || '')}</div>
        <div class="procedure-actions">${openAction}${exportAction}</div>
      </div>
    `;
  }).join('')}`;
}

function renderPublishedPdfs(files) {
  const target = document.getElementById('manager-current-pdf');
  if (!target) return;

  if (!files?.length) {
    target.innerHTML = `
      <strong>No published Setup PDF found.</strong>
      <div class="procedure-help">After correcting the editable procedure, publish the approved PDF directly in Procedures\\Setup.</div>
    `;
    return;
  }

  target.innerHTML = files.map((file) => `
    <div class="procedure-pdf-item">
      <strong class="procedure-file-name">${escapeHtml(file.name || 'Unnamed PDF')}</strong>
      <div class="procedure-full-path">${escapeHtml(file.path || '')}</div>
      <div class="procedure-actions">
        ${file.url ? procedureActionLink('Open Current PDF', file.url, 'secondary') : ''}
      </div>
    </div>
  `).join('');
}

function renderProcedureWarnings(warnings, resolutionMode) {
  const target = document.getElementById('instruction-live-warnings');
  if (!target) return;
  const visibleWarnings = (warnings || []).filter((warning) => {
    // The local fallback warning is useful engineering context but should not
    // dominate the Manager workflow. Show only a compact mode note for it.
    return !String(warning).includes('Local prototype exact-Stage-key');
  });
  const modeNote = resolutionMode === 'local-drive-prototype'
    ? '<div class="procedure-mode-note">Local prototype: resolved from the mounted Display Folders by exact Stage key.</div>'
    : '';
  target.innerHTML = `${modeNote}${visibleWarnings.map((warning) => `<div>${escapeHtml(warning)}</div>`).join('')}`;
}

async function loadLiveInstructionReview(task) {
  ensureManagerProcedurePanel();
  if (!task) return;

  const editableTarget = document.getElementById('manager-editable-procedure');
  const currentTarget = document.getElementById('manager-current-pdf');
  const warnings = document.getElementById('instruction-live-warnings');

  if (instructionNotExpected.has(task.id)) {
    if (editableTarget) {
      editableTarget.innerHTML = '<strong>No Setup Procedure expected for this support task.</strong>';
    }
    if (currentTarget) currentTarget.innerHTML = '<span class="muted">Not applicable.</span>';
    if (warnings) warnings.innerHTML = '';
    return;
  }

  if (editableTarget) editableTarget.innerHTML = '<span class="muted">Checking for the editable Google Doc…</span>';
  if (currentTarget) currentTarget.innerHTML = '<span class="muted">Checking for the published PDF…</span>';
  if (warnings) warnings.innerHTML = '';

  try {
    const response = await fetch(`/api/setup-instructions?stage_key=${encodeURIComponent(task.stageKey)}`, {
      headers: { Accept: 'application/json' }
    });
    if (!response.ok) {
      const errorPayload = await response.json().catch(() => ({}));
      throw new Error(errorPayload.error || `Setup Procedure API returned ${response.status}`);
    }

    const payload = await response.json();
    const data = payload.instructions || {};
    renderEditableProcedures(data.editable_sources || []);
    renderPublishedPdfs(data.current_documents || []);
    renderProcedureWarnings(data.warnings || [], data.resolution_mode);
  } catch (error) {
    if (editableTarget) {
      editableTarget.innerHTML = `
        <strong>Setup Procedure could not be resolved.</strong>
        <div class="procedure-help">${escapeHtml(error.message || error)}</div>
      `;
    }
    if (currentTarget) currentTarget.innerHTML = '<span class="muted">Not resolved.</span>';
    if (warnings) warnings.innerHTML = '';
  }
}

const baseSelectTaskForLiveInstructions = selectTask;
selectTask = function selectTaskWithLiveInstructions(taskId) {
  baseSelectTaskForLiveInstructions(taskId);
  loadLiveInstructionReview(taskById(taskId));
};

ensureManagerProcedurePanel();
if (selectedTaskId) loadLiveInstructionReview(taskById(selectedTaskId));
