/* Issue #184 browser-review refinement: separate T-Post storage context, definition, and physical counting. */
(() => {
  const state = {
    selectedCountId: null,
    addMode: false,
    managerSubmitPending: false,
    storageContextByContainer: new Map(),
    groupingList: false,
  };

  const el = (id) => document.getElementById(id);
  let listObserver = null;

  function appBasePath() {
    const marker = '/t-post-inventory';
    const index = window.location.pathname.indexOf(marker);
    return index >= 0 ? window.location.pathname.slice(0, index + 1) : '/';
  }

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
      const title = 'Manager only: edit the definition of this T-Post row. This does not change physical on-hand.';
      if (button.getAttribute('title') !== title) button.setAttribute('title', title);
    });
    document.querySelectorAll('.tpost-count').forEach((button) => {
      if (button.textContent !== 'Count physical stock') button.textContent = 'Count physical stock';
      const title = 'Select this T-Post row for physical counting or an inventory adjustment.';
      if (button.getAttribute('title') !== title) button.setAttribute('title', title);
    });
  }

  function applyCountHighlight() {
    document.querySelectorAll('#tpost-content-body tr.counting-source-row').forEach((row) => row.classList.remove('counting-source-row'));
    if (!state.selectedCountId) return;
    document.querySelector(`#tpost-content-body tr[data-content-id="${state.selectedCountId}"]`)?.classList.add('counting-source-row');
  }

  function makeContainerGroup(title, hint, buttons) {
    if (!buttons.length) return null;
    const group = document.createElement('section');
    group.className = 'tpost-container-group';
    const heading = document.createElement('div');
    heading.className = 'tpost-container-group-heading';
    heading.innerHTML = `<strong>${title}</strong><span>${hint}</span>`;
    group.appendChild(heading);
    buttons.forEach((button) => group.appendChild(button));
    return group;
  }

  function groupContainerList() {
    const target = el('tpost-list');
    if (!target || state.groupingList || !state.storageContextByContainer.size) return;
    const buttons = [...target.querySelectorAll('.kit-row[data-container-id]')];
    if (!buttons.length) return;

    state.groupingList = true;
    listObserver?.disconnect();
    try {
      const shared = [];
      const carried = [];
      buttons.forEach((button) => {
        const containerId = Number(button.dataset.containerId);
        const context = state.storageContextByContainer.get(containerId) || 'WITH_KIT_OR_DISPLAY';
        button.dataset.storageContext = context;
        const flags = button.querySelector('.kit-row-flags');
        if (flags && !flags.querySelector('.tpost-context-pill')) {
          const pill = document.createElement('span');
          pill.className = 'pill tpost-context-pill';
          pill.textContent = context === 'SHARED_STOCK' ? 'shared/bulk stock' : 'stored with Kit/Display';
          flags.prepend(pill);
        }
        (context === 'SHARED_STOCK' ? shared : carried).push(button);
      });

      target.replaceChildren();
      const sharedGroup = makeContainerGroup(
        'Shared / Bulk T-Post Stock',
        'General stock locations used as sources for multiple installations.',
        shared,
      );
      const carriedGroup = makeContainerGroup(
        'T-Posts Stored With Kits / Displays',
        'Posts intentionally kept in a Container that travels with specific work. These are physical storage facts, not task requirements.',
        carried,
      );
      if (sharedGroup) target.appendChild(sharedGroup);
      if (carriedGroup) target.appendChild(carriedGroup);
    } finally {
      state.groupingList = false;
      if (listObserver) listObserver.observe(target, { childList: true });
    }
  }

  async function loadStorageContexts() {
    try {
      const response = await fetch(`${appBasePath()}api/setup/t-post-inventory/containers`, {
        credentials: 'same-origin',
        headers: { Accept: 'application/json' },
      });
      if (!response.ok) return;
      const payload = await response.json();
      state.storageContextByContainer.clear();
      (payload.containers || []).forEach((row) => {
        state.storageContextByContainer.set(Number(row.container_id), row.storage_context || 'WITH_KIT_OR_DISPLAY');
      });
      groupContainerList();
    } catch (_error) {
      // The base application still renders the inventory list if classification cannot load.
    }
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
      banner.textContent = 'ADDING NEW T-POST ROW — define another physical T-Post variant in this Container. This does not record a physical count.';
    }
    if (el('tpost-editor-title')) el('tpost-editor-title').textContent = 'Manager — Add New T-Post Row';
    if (el('tpost-save')) el('tpost-save').textContent = 'Add T-Post Row';
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
    const variant = row?.querySelector('td strong')?.textContent?.trim() || 'selected T-Post row';
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
        window.requestAnimationFrame(groupContainerList);
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

    const list = el('tpost-list');
    if (list) {
      listObserver = new MutationObserver(() => groupContainerList());
      listObserver.observe(list, { childList: true });
    }

    const selected = el('tpost-inventory-selected');
    if (selected) {
      new MutationObserver(() => {
        if (!state.selectedCountId) return;
        setCountEnabled(true);
      }).observe(selected, { childList: true, subtree: true, characterData: true });
    }

    loadStorageContexts();
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
