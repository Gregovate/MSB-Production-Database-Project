/* Compact normal-flow resource picker with on-demand catalog maintenance. */
(() => {
  'use strict';

  function installCompactResourcePicker() {
    const manager = document.getElementById('setup-resource-manager');
    if (!manager || manager.dataset.compactResourcePickerInstalled === '1') return;

    const picker = manager.querySelector('.resource-existing-block');
    const catalogEditor = manager.querySelector('.resource-catalog-edit-block');
    const createBlock = manager.querySelector('.resource-create-block');
    if (!picker || !catalogEditor || !createBlock) return;

    manager.dataset.compactResourcePickerInstalled = '1';
    picker.classList.add('resource-picker-primary');
    catalogEditor.classList.add('resource-catalog-secondary');
    createBlock.classList.add('resource-catalog-secondary');
    catalogEditor.hidden = true;
    createBlock.hidden = true;

    const heading = picker.querySelector('.resource-manager-heading h4');
    if (heading) heading.textContent = 'Resource picker';
    const hint = picker.querySelector('.resource-manager-heading .hint');
    if (hint) {
      hint.textContent = 'Find an existing reusable resource, set this task\'s quantity/requirement, and add or update it.';
    }

    const actionRow = picker.querySelector('.action-row');
    if (actionRow && !document.getElementById('setup-resource-catalog-toggle')) {
      const toggle = document.createElement('button');
      toggle.id = 'setup-resource-catalog-toggle';
      toggle.type = 'button';
      toggle.className = 'secondary';
      toggle.textContent = 'Manage Resource Catalog';
      toggle.setAttribute('aria-expanded', 'false');
      actionRow.appendChild(toggle);

      const explanation = document.createElement('div');
      explanation.className = 'resource-manager-launch-hint muted';
      explanation.textContent = 'Resource not listed or named poorly? Open the catalog manager to rename, reactivate, or create it.';
      actionRow.insertAdjacentElement('afterend', explanation);

      const closeCatalog = () => {
        catalogEditor.hidden = true;
        createBlock.hidden = true;
        toggle.hidden = false;
        toggle.setAttribute('aria-expanded', 'false');
        manager.classList.remove('resource-catalog-open');
        toggle.focus();
      };

      toggle.addEventListener('click', async () => {
        catalogEditor.hidden = false;
        createBlock.hidden = false;
        toggle.hidden = true;
        toggle.setAttribute('aria-expanded', 'true');
        manager.classList.add('resource-catalog-open');

        const sort = document.getElementById('setup-resource-catalog-sort');
        if (sort && sort.value === 'ORDER') sort.value = 'NAME';
        if (typeof loadSetupResourceAdminCatalog === 'function') {
          await loadSetupResourceAdminCatalog();
        }
        if (typeof renderSetupResourceAdminCatalog === 'function') {
          renderSetupResourceAdminCatalog();
        }
        document.getElementById('setup-resource-catalog-search')?.focus();
      });

      const catalogActionRow = catalogEditor.querySelector('.action-row');
      if (catalogActionRow && !document.getElementById('setup-resource-catalog-close')) {
        const closeButton = document.createElement('button');
        closeButton.id = 'setup-resource-catalog-close';
        closeButton.type = 'button';
        closeButton.className = 'success resource-catalog-close';
        closeButton.textContent = 'Close Resource Catalog';
        closeButton.addEventListener('click', closeCatalog);
        catalogActionRow.appendChild(closeButton);
      }
    }

    const sort = document.getElementById('setup-resource-catalog-sort');
    if (sort && sort.value === 'ORDER') sort.value = 'NAME';

    const orderInput = document.getElementById('setup-resource-catalog-order');
    const orderLabel = orderInput?.closest('label');
    if (orderLabel && !orderLabel.classList.contains('resource-order-advanced')) {
      orderLabel.classList.add('resource-order-advanced');
      for (const node of orderLabel.childNodes) {
        if (node.nodeType === Node.TEXT_NODE && node.textContent.trim()) {
          node.textContent = 'Optional display order ';
          break;
        }
      }
      const note = document.createElement('span');
      note.className = 'resource-order-note muted';
      note.textContent = 'Usually leave 100; meaningful names drive the normal picker order.';
      orderLabel.appendChild(note);
    }
  }

  installCompactResourcePicker();

  const observer = new MutationObserver(() => installCompactResourcePicker());
  observer.observe(document.body, { childList: true, subtree: true });
})();
