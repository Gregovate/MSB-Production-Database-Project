/* Setup #198 browser-acceptance refinements for Extra Material source allocation. */
(() => {
  'use strict';

  let sourceBaseline = null;
  let sourceContainerTouched = false;
  let requirementObserver = null;

  const el = (id) => document.getElementById(id);

  function claimEditorVisibility() {
    ['task-extra-material-form', 'task-extra-material-source-form'].forEach((id) => {
      const form = el(id);
      if (!form) return;

      /* applyAccess() unhides every .manager-only element. These two forms are
         workflow editors, not always-visible Manager panels, so their own UI
         controls must own visibility after access has been established. */
      form.classList.remove('manager-only');
      if (!form.dataset.workflowVisibilityClaimed) {
        form.dataset.workflowVisibilityClaimed = '1';
        form.hidden = true;
      }
    });
  }

  function decorateSourceOpeners() {
    document.querySelectorAll('.task-extra-material-source-add').forEach((button) => {
      button.textContent = 'Add Source…';
      button.title = 'Open the source editor';
    });
  }

  function sourceSnapshot() {
    return {
      container: String(el('task-extra-material-source-container')?.value || ''),
      quantity: String(el('task-extra-material-source-qty')?.value || '').trim(),
      verification: String(el('task-extra-material-source-verification')?.value || ''),
      notes: String(el('task-extra-material-source-notes')?.value || '').trim(),
    };
  }

  function sameSnapshot(left, right) {
    if (!left || !right) return false;
    return left.container === right.container
      && left.quantity === right.quantity
      && left.verification === right.verification
      && left.notes === right.notes;
  }

  function updateSourceSaveState() {
    const form = el('task-extra-material-source-form');
    const button = el('task-extra-material-source-save');
    if (!form || !button) return;

    button.textContent = 'Save Source';
    if (form.hidden || !sourceBaseline) {
      button.disabled = true;
      return;
    }

    const current = sourceSnapshot();
    const changed = !sameSnapshot(current, sourceBaseline);
    const hasContainer = Boolean(current.container);
    const newSourceNeedsExplicitContainerChoice = !sourceBaseline.container && !sourceContainerTouched;
    const verifiedNeedsQuantity = current.verification === 'VERIFIED' && !current.quantity;

    button.disabled = !changed
      || !hasContainer
      || newSourceNeedsExplicitContainerChoice
      || verifiedNeedsQuantity;
  }

  function beginSourceTracking() {
    claimEditorVisibility();
    const form = el('task-extra-material-source-form');
    if (!form || form.hidden) return;

    sourceBaseline = sourceSnapshot();
    sourceContainerTouched = false;
    updateSourceSaveState();
  }

  function clearSourceTracking() {
    sourceBaseline = null;
    sourceContainerTouched = false;
    const button = el('task-extra-material-source-save');
    if (button) {
      button.textContent = 'Save Source';
      button.disabled = true;
    }
  }

  function refreshWholeSelectedTask() {
    const taskId = Number(appState?.selectedTaskId || 0);
    if (!taskId || typeof selectTask !== 'function') return;
    selectTask(taskId);
  }

  function watchRequirementSave() {
    const body = el('task-extra-material-body');
    if (!body) return;

    requirementObserver?.disconnect();
    let completed = false;
    requirementObserver = new MutationObserver(() => {
      if (completed) return;
      completed = true;
      requirementObserver?.disconnect();
      requirementObserver = null;

      /* The requirement editor refreshes its own table after a successful save.
         Re-select the current task once so the independent source-allocation
         module reloads the same fresh requirement quantity and recomputes its
         allocation audit (for example 66 of 66 after correcting Northern Lights). */
      window.setTimeout(refreshWholeSelectedTask, 0);
    });
    requirementObserver.observe(body, { childList: true, subtree: true, characterData: true });

    window.setTimeout(() => {
      if (!completed) {
        requirementObserver?.disconnect();
        requirementObserver = null;
      }
    }, 10000);
  }

  function bind() {
    claimEditorVisibility();
    decorateSourceOpeners();

    document.addEventListener('click', (event) => {
      const sourceOpener = event.target.closest?.('.task-extra-material-source-add, .task-extra-material-source-edit');
      if (sourceOpener) {
        window.setTimeout(beginSourceTracking, 0);
        return;
      }

      if (event.target.closest?.('#task-extra-material-source-clear')) {
        window.setTimeout(clearSourceTracking, 0);
      }
    }, true);

    document.addEventListener('change', (event) => {
      const form = el('task-extra-material-source-form');
      if (!form || !form.contains(event.target)) return;
      if (event.target?.id === 'task-extra-material-source-container') sourceContainerTouched = true;
      window.setTimeout(updateSourceSaveState, 0);
    });

    document.addEventListener('input', (event) => {
      const form = el('task-extra-material-source-form');
      if (!form || !form.contains(event.target)) return;
      if (event.target?.id === 'task-extra-material-source-search') return;
      updateSourceSaveState();
    });

    document.addEventListener('submit', (event) => {
      if (event.target?.id === 'task-extra-material-form') watchRequirementSave();
    }, true);

    const observer = new MutationObserver(() => {
      claimEditorVisibility();
      decorateSourceOpeners();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
