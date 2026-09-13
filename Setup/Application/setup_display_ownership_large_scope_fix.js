/* Source-only large-scope usability correction for Setup Display Ownership. */

(() => {
  const DIALOG_ID = 'setup-display-ownership-dialog';
  const PATCH_MARK = 'largeScopeFixInstalled';

  function dialogNode() {
    return document.getElementById(DIALOG_ID);
  }

  function resetNativeDragState() {
    document.dispatchEvent(new Event('dragend', { bubbles: true }));
  }

  function resetDialogState(dialog) {
    if (!dialog) return;
    resetNativeDragState();
    const content = dialog.querySelector('#setup-display-ownership-content');
    if (content) content.scrollTop = 0;

    const taskId = Number(appState?.selectedTaskId || 0);
    if (taskId && typeof selectTask === 'function') {
      requestAnimationFrame(() => selectTask(taskId));
    }
  }

  function taskOptions(dialog) {
    return [...dialog.querySelectorAll('.setup-display-owner-column[data-target-task-id]')]
      .map((column) => {
        const taskId = Number(column.dataset.targetTaskId || 0);
        const label = column.querySelector('.setup-display-owner-column-heading strong')?.textContent?.trim()
          || `Task ${taskId}`;
        return { taskId, label };
      })
      .filter((item) => item.taskId > 0);
  }

  function selectedDisplayIds(dialog) {
    return [...dialog.querySelectorAll('.setup-display-owner-card.selected[data-display-id]')]
      .map((card) => Number(card.dataset.displayId || 0))
      .filter((displayId) => displayId > 0);
  }

  function updateMoveButton(dialog) {
    const select = dialog.querySelector('#setup-display-ownership-move-target');
    const button = dialog.querySelector('#setup-display-ownership-move-selected');
    if (!select || !button) return;
    button.disabled = !selectedDisplayIds(dialog).length || !Number(select.value || 0);
  }

  function dispatchExistingDrop(dialog) {
    const select = dialog.querySelector('#setup-display-ownership-move-target');
    const targetTaskId = Number(select?.value || 0);
    const displayIds = selectedDisplayIds(dialog);
    if (!targetTaskId || !displayIds.length) return;

    const target = dialog.querySelector(`.setup-display-owner-column[data-target-task-id="${targetTaskId}"]`);
    if (!target) return;

    const transfer = new DataTransfer();
    transfer.effectAllowed = 'move';
    transfer.setData('text/plain', displayIds.join(','));
    target.dispatchEvent(new DragEvent('drop', {
      bubbles: true,
      cancelable: true,
      dataTransfer: transfer,
    }));
  }

  function installMoveControl(dialog) {
    const toolbar = dialog.querySelector('.setup-display-ownership-toolbar');
    if (!toolbar || toolbar.querySelector('#setup-display-ownership-move-target')) return;

    const options = taskOptions(dialog);
    if (!options.length || !appState?.access?.can_manage_setup) return;

    const label = document.createElement('label');
    label.className = 'setup-display-ownership-move-control';
    label.textContent = 'Move selected to ';

    const select = document.createElement('select');
    select.id = 'setup-display-ownership-move-target';
    select.setAttribute('aria-label', 'Move selected Displays to reusable task');
    select.innerHTML = '<option value="">Choose task…</option>' + options.map((item) => (
      `<option value="${item.taskId}">${escapeHtml(item.label)}</option>`
    )).join('');
    label.appendChild(select);

    const button = document.createElement('button');
    button.id = 'setup-display-ownership-move-selected';
    button.type = 'button';
    button.className = 'secondary';
    button.textContent = 'Move selected';
    button.disabled = true;

    select.addEventListener('change', () => updateMoveButton(dialog));
    button.addEventListener('click', () => dispatchExistingDrop(dialog));

    toolbar.appendChild(label);
    toolbar.appendChild(button);
    updateMoveButton(dialog);
  }

  function installAutoScroll(dialog) {
    if (dialog.dataset.largeScopeAutoScroll === '1') return;
    dialog.dataset.largeScopeAutoScroll = '1';

    dialog.addEventListener('dragover', (event) => {
      if (!dialog.querySelector('.setup-display-owner-card.dragging')) return;
      const content = dialog.querySelector('#setup-display-ownership-content');
      if (!content) return;

      const rect = content.getBoundingClientRect();
      const edge = Math.min(110, Math.max(70, rect.height * 0.14));
      const step = 34;
      if (event.clientY <= rect.top + edge) {
        content.scrollTop = Math.max(0, content.scrollTop - step);
      } else if (event.clientY >= rect.bottom - edge) {
        content.scrollTop += step;
      }
    }, true);
  }

  function enhanceDialog(dialog) {
    if (!dialog) return;

    const eyebrow = dialog.querySelector('.setup-display-ownership-heading .eyebrow');
    if (eyebrow) eyebrow.textContent = 'Display material assignment';

    installMoveControl(dialog);
    installAutoScroll(dialog);
    updateMoveButton(dialog);

    if (dialog.dataset[PATCH_MARK] === '1') return;
    dialog.dataset[PATCH_MARK] = '1';

    dialog.addEventListener('click', () => {
      requestAnimationFrame(() => updateMoveButton(dialog));
    });

    dialog.addEventListener('close', () => resetDialogState(dialog));
    dialog.addEventListener('cancel', () => resetNativeDragState(), true);

    const content = dialog.querySelector('#setup-display-ownership-content');
    if (content) {
      new MutationObserver(() => {
        const current = dialogNode();
        if (!current) return;
        const heading = current.querySelector('.setup-display-ownership-heading .eyebrow');
        if (heading) heading.textContent = 'Display material assignment';
        installMoveControl(current);
        updateMoveButton(current);
      }).observe(content, { childList: true, subtree: true });
    }
  }

  document.addEventListener('click', (event) => {
    if (event.target.closest('#setup-display-ownership-open')) {
      requestAnimationFrame(() => {
        const dialog = dialogNode();
        enhanceDialog(dialog);
        const content = dialog?.querySelector('#setup-display-ownership-content');
        if (content) content.scrollTop = 0;
      });
    }
  }, true);

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && dialogNode()?.open) resetNativeDragState();
  }, true);

  window.addEventListener('load', () => enhanceDialog(dialogNode()));
})();
