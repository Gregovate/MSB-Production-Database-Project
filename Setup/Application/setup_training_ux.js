/* Setup training/live-use UX corrections discovered during 2025 reconstruction. */

(() => {
  const returnState = {
    fromLibrary: false,
    taskId: null,
    scrollY: 0
  };

  function navigationHost() {
    return document.querySelector('#review-detail .detail-heading');
  }

  function ensureLibraryReturnControl() {
    const host = navigationHost();
    if (!host || document.getElementById('setup-return-library-wrap')) return;

    const wrap = document.createElement('div');
    wrap.id = 'setup-return-library-wrap';
    wrap.className = 'setup-return-library-wrap';
    wrap.hidden = true;
    wrap.innerHTML = `
      <button id="setup-return-library" type="button" class="secondary">← Back to Reusable Task Catalog</button>
      <span class="muted">Return to the same reusable task and Catalog position.</span>
    `;
    host.insertAdjacentElement('beforebegin', wrap);

    document.getElementById('setup-return-library').addEventListener('click', () => {
      const taskId = returnState.taskId;
      if (typeof renderLibrary === 'function') renderLibrary();
      showView('library');

      requestAnimationFrame(() => {
        const row = taskId == null
          ? null
          : document.querySelector(`#library-view [data-task-id="${taskId}"]`);
        if (row) {
          row.scrollIntoView({ block: 'center', behavior: 'auto' });
          row.classList.add('setup-return-highlight');
          window.setTimeout(() => row.classList.remove('setup-return-highlight'), 1600);
        } else {
          window.scrollTo({ top: returnState.scrollY, behavior: 'auto' });
        }
      });

      returnState.fromLibrary = false;
      updateLibraryReturnControl();
    });
  }

  function updateLibraryReturnControl() {
    ensureLibraryReturnControl();
    const wrap = document.getElementById('setup-return-library-wrap');
    if (wrap) wrap.hidden = !returnState.fromLibrary;
  }

  function rememberLibraryOrigin(taskId) {
    returnState.fromLibrary = true;
    returnState.taskId = Number(taskId);
    returnState.scrollY = window.scrollY;
  }

  function clearLibraryOrigin() {
    returnState.fromLibrary = false;
    returnState.taskId = null;
    updateLibraryReturnControl();
  }

  /*
   * Capture Catalog Open before the existing bubble handler switches views.
   * This preserves the user's Catalog context without changing the existing
   * task-selection or save behavior.
   */
  document.addEventListener('click', (event) => {
    const catalogOpen = event.target.closest('#library-view .open-task');
    if (catalogOpen) {
      rememberLibraryOrigin(catalogOpen.dataset.taskId);
      requestAnimationFrame(updateLibraryReturnControl);
      return;
    }

    if (event.target.closest('#review-list .task-row')) {
      clearLibraryOrigin();
      return;
    }

    const tab = event.target.closest('.tabs .tab');
    if (tab && tab.dataset.view !== 'library') {
      clearLibraryOrigin();
    }
  }, true);

  /* Keep the return control visible across saves/reloads of the open task. */
  if (typeof selectTask === 'function') {
    const priorSelectTask = selectTask;
    selectTask = function selectTaskWithCatalogReturn(taskId) {
      const result = priorSelectTask(taskId);
      requestAnimationFrame(updateLibraryReturnControl);
      return result;
    };
  }

  ensureLibraryReturnControl();
})();
