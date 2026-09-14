(() => {
  'use strict';

  function focusSection(sectionId, focusId) {
    const section = document.getElementById(sectionId);
    if (!section || section.hidden) return;
    window.requestAnimationFrame(() => {
      section.scrollIntoView({ behavior: 'smooth', block: 'start' });
      const target = document.getElementById(focusId);
      window.setTimeout(() => target?.focus({ preventScroll: true }), 180);
    });
  }

  document.addEventListener('click', (event) => {
    const edit = event.target.closest('.expected-edit');
    if (edit) {
      focusSection('expected-editor', 'expected-qty');
      return;
    }

    const inventory = event.target.closest('.inventory-select');
    if (inventory) {
      focusSection('inventory-editor', 'inventory-delta');
    }
  });
})();
