/* Optional live Procedure-review integration for the Setup prototype. */

const instructionNotExpected = new Set([
  'OPS-FOOD',
  'OPS-RENTALS',
  'OPS-VOLTRAILER',
  'CMD-DELIVER'
]);

function ensureInstructionFileContainers() {
  const section = document.getElementById('instruction-review-section');
  if (!section) return;
  const roles = section.querySelectorAll('.instruction-role');
  if (roles.length < 3) return;

  if (!document.getElementById('instruction-current-files')) {
    const current = document.createElement('div');
    current.id = 'instruction-current-files';
    current.className = 'instruction-file-list';
    roles[0].appendChild(current);
  }
  if (!document.getElementById('instruction-source-files')) {
    const source = document.createElement('div');
    source.id = 'instruction-source-files';
    source.className = 'instruction-file-list';
    roles[1].appendChild(source);
  }
  if (!document.getElementById('instruction-archive-files')) {
    const archive = document.createElement('div');
    archive.id = 'instruction-archive-files';
    archive.className = 'instruction-file-list';
    roles[2].appendChild(archive);
  }
  if (!document.getElementById('instruction-live-warnings')) {
    const warnings = document.createElement('div');
    warnings.id = 'instruction-live-warnings';
    warnings.className = 'instruction-live-warnings';
    section.querySelector('.publication-flow')?.insertAdjacentElement('afterend', warnings);
  }
}

function renderNamedFiles(targetId, files, { current = false } = {}) {
  const target = document.getElementById(targetId);
  if (!target) return;
  if (!files?.length) {
    target.innerHTML = '<span class="muted">None found.</span>';
    return;
  }

  target.innerHTML = files.map((file) => {
    const name = escapeHtml(file.name || 'Unnamed file');
    if (current && file.url) {
      return `<a class="instruction-file-link" href="${escapeHtml(file.url)}" target="_blank" rel="noopener">${name}</a>`;
    }
    const ext = file.extension ? ` <span class="muted">${escapeHtml(file.extension)}</span>` : '';
    return `<div class="instruction-file-name">${name}${ext}</div>`;
  }).join('');
}

async function loadLiveInstructionReview(task) {
  ensureInstructionFileContainers();
  if (!task) return;

  const currentState = document.getElementById('instruction-current-state');
  const currentFiles = document.getElementById('instruction-current-files');
  const sourceFiles = document.getElementById('instruction-source-files');
  const archiveFiles = document.getElementById('instruction-archive-files');
  const warnings = document.getElementById('instruction-live-warnings');

  if (instructionNotExpected.has(task.id)) {
    if (currentState) currentState.textContent = 'No field Setup instruction is expected for this support task unless a Manager deliberately links one later.';
    if (currentFiles) currentFiles.innerHTML = '';
    if (sourceFiles) sourceFiles.innerHTML = '';
    if (archiveFiles) archiveFiles.innerHTML = '';
    if (warnings) warnings.innerHTML = '';
    return;
  }

  if (currentState) currentState.textContent = 'Checking the current Procedure resolver…';
  if (currentFiles) currentFiles.innerHTML = '';
  if (sourceFiles) sourceFiles.innerHTML = '';
  if (archiveFiles) archiveFiles.innerHTML = '';
  if (warnings) warnings.innerHTML = '';

  try {
    const response = await fetch(`/api/setup-instructions?stage_key=${encodeURIComponent(task.stageKey)}`, {
      headers: { Accept: 'application/json' }
    });
    if (!response.ok) {
      const errorPayload = await response.json().catch(() => ({}));
      throw new Error(errorPayload.error || `Instruction API returned ${response.status}`);
    }

    const payload = await response.json();
    const data = payload.instructions || {};
    if (currentState) {
      currentState.textContent = `Resolved Stage/Sub-stage ${task.stageKey}; Procedure status: ${data.status || 'unknown'}.`;
    }
    renderNamedFiles('instruction-current-files', data.current_documents || [], { current: true });
    renderNamedFiles('instruction-source-files', data.source_docs || []);
    renderNamedFiles('instruction-archive-files', data.archive || []);

    if (warnings && data.warnings?.length) {
      warnings.innerHTML = data.warnings.map((warning) => `<div>${escapeHtml(warning)}</div>`).join('');
    }
  } catch (error) {
    if (currentState) {
      currentState.textContent = 'Live instruction files are not connected in this run. The task/procedure review fields below still work locally.';
    }
    if (currentFiles) currentFiles.innerHTML = '<span class="muted">Run the Flask prototype backend with DB + Display Folders configuration to show current PDFs.</span>';
    if (sourceFiles) sourceFiles.innerHTML = '<span class="muted">Not connected.</span>';
    if (archiveFiles) archiveFiles.innerHTML = '<span class="muted">Not connected.</span>';
    if (warnings) warnings.innerHTML = `<div>${escapeHtml(error.message || error)}</div>`;
  }
}

const baseSelectTaskForLiveInstructions = selectTask;
selectTask = function selectTaskWithLiveInstructions(taskId) {
  baseSelectTaskForLiveInstructions(taskId);
  loadLiveInstructionReview(taskById(taskId));
};

ensureInstructionFileContainers();
if (selectedTaskId) loadLiveInstructionReview(taskById(selectedTaskId));
