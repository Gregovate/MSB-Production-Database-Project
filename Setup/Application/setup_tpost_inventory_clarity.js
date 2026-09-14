/* Issue #184 browser-review refinement: separate stock definition from physical counting. */
(() => {
  const state = {
    selectedCountId: null,
    addMode: false,
    managerSubmitPending: false,
  };

  const el = (id) => document.getElementById(id);

  function configPanel() { return el('tpost-manager-editor'); }
  function countFields() { return el('tpost-count-fields'); }

  function setConfigOpen(open) {
    configPanel()?.classList.toggle('collapsed', !open);
  }

  function setCountEnabled(enabled) {
    const fields = countFields();
    if (fields) fields.disabled = !enabled;
    const instruction = el('tpost-count-instruction');
    if (instruction && !enabled && instruction.textContent !== 'No stock row selected. Click “Count physical stock” on one row above.') {
      instruction.textContent = 'No stock row selected. Click “Count physical stock” on one row above.';
    }
  }

  function labelRowActions() {
    document.querySelectorAll('.tpost-edit').forEach((button) => {
      if (button.textContent !== 'Edit stock definition') button.textContent = 'Edit stock definition';
      const title = 'Manager only: edit the definition of this shared-stock variant. This does not change physical on-hand.';
      if (button.getAttribute('title') !== title) button.setAttribute('title', title);
    });
    document.querySelectorAll('.tpost-count').forEach((button) => {
      if (button.textContent !== 'Count physical stock') button.textContent = 'Count physical stock';
      const title = 'Select this stock variant for physical counting or an inventory adjustment.';
      if (button.getAttribute('title') !== title) button.setAttribute('title', title);
    });
  }

  function applyCountHighlight() {
    document.querySelectorAll('#tpost-content-body tr.counting-source-row').forEach((row) => row.classList.remove('counting-source-row'));
    if (!state.selectedCountId) return;
    document.querySelector(`#tpost-content-body tr[data-content-id="${state.selectedCountId}"]`)?.classList.add('counting-source-row');
  }

  function openAddVariant() {
    state.addMode = true;
    el('tpost-clear')?.click();
    setConfigOpen(true);
    const panel = configPanel();
    panel?.classList.remove('editing');
    const banner = el('tpost-editor-status');
    if (banner) {
      banner.hidden = false;
      banner.textContent = 'ADDING NEW STOCK VARIANT — define a new shared T-Post stock row. This does not record a physical count.';
    }
    if (el('tpost-editor-title')) el('tpost-editor-title').textContent = 'Manager — Add New Shared-Stock Variant';
    if (el('tpost-save')) el('tpost-save').textContent = 'Add Stock Variant';
    if (el('tpost-clear')) el('tpost-clear').textContent = 'Cancel';
    window.requestAnimationFrame(() => {
      panel?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      window.setTimeout(() => el('tpost-length')?.focus({ preventScroll: true }), 180);
    });
  }

  function closeConfig() {
    state.addMode = false;
    setConfigOpen(false);
  }

  function selectCountRow(button) {
    state.selectedCountId = Number(button.dataset.contentId || 0) || null;
    setCountEnabled(Boolean(state.selectedCountId));
    applyCountHighlight();
    const row = button.closest('tr');
    const variant = row?.querySelector('td strong')?.textContent?.trim() || 'selected stock row';
    const instruction = el('tpost-count-instruction');
    if (instruction) instruction.textContent = `Counting physical stock for: ${variant}. The event below changes only this on-hand balance.`;
  }

  function clearCountSelection() {
    state.selectedCountId = null;
    setCountEnabled(false);
    applyCountHighlight();
  }

  function bind() {
    setConfigOpen(false);
    setCountEnabled(false);
    labelRowActions();

    el('tpost-add-variant')?.addEventListener('click', openAddVariant);

    document.addEventListener('click', (event) => {
      const edit = event.target.closest('.tpost-edit');
      if (edit) {
        state.addMode = false;
        window.requestAnimationFrame(() => setConfigOpen(true));
        return;
      }

      const count = event.target.closest('.tpost-count');
      if (count) {
        selectCountRow(count);
        return;
      }

      if (event.target.closest('#tpost-clear')) {
        window.requestAnimationFrame(closeConfig);
        return;
      }

      if (event.target.closest('#tpost-list .kit-row')) {
        clearCountSelection();
        closeConfig();
      }
    });

    el('tpost-form')?.addEventListener('submit', () => {
      state.managerSubmitPending = true;
    });

    const body = el('tpost-content-body');
    if (body) {
      new MutationObserver(() => {
        labelRowActions();
        applyCountHighlight();
        if (state.managerSubmitPending) {
          state.managerSubmitPending = false;
          closeConfig();
        }
      }).observe(body, { childList: true });
      // Deliberately do not observe descendants here. labelRowActions() changes
      // descendant button text, and subtree observation would self-trigger forever.
    }

    const selected = el('tpost-inventory-selected');
    if (selected) {
      new MutationObserver(() => {
        if (!state.selectedCountId) return;
        setCountEnabled(true);
      }).observe(selected, { childList: true, subtree: true, characterData: true });
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
