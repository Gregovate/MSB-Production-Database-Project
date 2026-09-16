/* Issue #167/#191/#198 — route Kit Inventory and load durable Extra Material support. */
(() => {
  function inventoryUrl(containerId = null) {
    return containerId ? `kit-inventory/${Number(containerId)}` : 'kit-inventory/';
  }

  function openInventory(containerId = null) {
    window.location.assign(inventoryUrl(containerId));
  }

  function configureSetupEntryPoint() {
    const tab = document.querySelector('[data-view="extra-materials"]');
    if (tab) {
      tab.textContent = 'Kit Inventory';
      tab.title = 'Open durable Kit Box inventory';
    }

    /* The first #167 browser candidate embedded inventory inside the annual
       Setup tabs. Inventory is durable Container work, so remove that embedded
       workspace and use the standalone protected route instead. */
    document.getElementById('extra-materials-view')?.remove();
  }

  function makeInventoryLink(containerId, label = 'Inventory') {
    const link = document.createElement('a');
    link.className = 'small secondary setup-kit-inventory-link';
    link.href = inventoryUrl(containerId);
    link.textContent = label;
    link.title = `Open Kit Inventory for Container ${containerId}`;
    link.addEventListener('click', (event) => {
      /* Kit assignment rows are labels containing checkboxes. Prevent the link
         click from toggling the assignment while still navigating explicitly. */
      event.preventDefault();
      event.stopPropagation();
      openInventory(containerId);
    });
    return link;
  }

  function decorateAssignedKitChips() {
    document.querySelectorAll('.setup-kit-box-chip[data-container-id]').forEach((chip) => {
      if (chip.querySelector('.setup-kit-inventory-link')) return;
      const containerId = Number(chip.dataset.containerId || 0);
      if (!containerId) return;
      const removeButton = chip.querySelector('.setup-kit-box-chip-remove');
      const link = makeInventoryLink(containerId);
      if (removeButton) chip.insertBefore(link, removeButton);
      else chip.appendChild(link);
    });
  }

  function decorateKitDialogRows() {
    document.querySelectorAll('.setup-kit-box-row[data-container-id]').forEach((row) => {
      if (row.querySelector('.setup-kit-inventory-link')) return;
      const containerId = Number(row.dataset.containerId || 0);
      if (!containerId) return;
      const copy = row.querySelector('.setup-kit-box-copy') || row;
      copy.appendChild(makeInventoryLink(containerId, 'View Inventory'));
    });
  }

  function decorateKitAssignments() {
    decorateAssignedKitChips();
    decorateKitDialogRows();
  }

  function loadTaskExtraMaterialSourceUi() {
    if (document.querySelector('script[data-setup-task-extra-material-sources]')) return;
    const script = document.createElement('script');
    script.src = 'setup_task_extra_material_sources.js?v=2026-09-15.1';
    script.dataset.setupTaskExtraMaterialSources = '1';
    document.body.appendChild(script);
  }

  function loadTaskExtraMaterialUi() {
    const existing = document.querySelector('script[data-setup-task-extra-materials]');
    if (existing) {
      loadTaskExtraMaterialSourceUi();
      return;
    }
    const script = document.createElement('script');
    script.src = 'setup_task_extra_materials.js?v=2026-09-15.2';
    script.dataset.setupTaskExtraMaterials = '1';
    script.addEventListener('load', loadTaskExtraMaterialSourceUi, { once: true });
    document.body.appendChild(script);
  }

  function loadUomCatalogUi() {
    if (document.querySelector('script[data-setup-uom-catalog]')) return;
    const script = document.createElement('script');
    script.src = 'setup_uom_catalog.js?v=2026-09-15.1';
    script.dataset.setupUomCatalog = '1';
    document.body.appendChild(script);
  }

  /* Capture the old tab click before the generic Setup view-switch handler.
     This keeps a visible Setup entry point while making Kit Inventory a true
     route rather than another annual-session view. */
  document.addEventListener('click', (event) => {
    const tab = event.target.closest?.('[data-view="extra-materials"]');
    if (!tab) return;
    event.preventDefault();
    event.stopPropagation();
    event.stopImmediatePropagation();
    openInventory();
  }, true);

  function bind() {
    configureSetupEntryPoint();
    decorateKitAssignments();
    loadTaskExtraMaterialUi();
    loadUomCatalogUi();
    const observer = new MutationObserver(decorateKitAssignments);
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', bind);
  else bind();
})();
