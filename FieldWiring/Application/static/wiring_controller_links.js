// FieldWiring permanent Controller Inventory cross-links.
// Presentation only: permanent identity comes from ref.controller relationships
// already attached by wiring_controller_inventory.py.
(function () {
  'use strict';

  const target = document.getElementById('controller-groups');
  if (!target) return;

  function controllersFor(group) {
    const found = new Map();
    const bases = new Set();
    for (const row of group.rows || []) {
      if (row.permanent_controller_basis) bases.add(row.permanent_controller_basis);
      for (const controller of row.permanent_controllers || []) {
        if (controller.controller_id === null || controller.controller_id === undefined) continue;
        found.set(Number(controller.controller_id), controller);
      }
    }
    return {
      controllers: [...found.values()].sort((a, b) => Number(a.controller_id) - Number(b.controller_id)),
      exact: found.size > 0 && bases.size === 1 && bases.has('PROGRAMMED_LOR_ADDRESS')
    };
  }

  function decorate() {
    if (typeof packageData === 'undefined' || !packageData) return;
    const groups = packageData.controller_groups || [];
    const cards = [...target.querySelectorAll('.controller-card')];
    if (!cards.length || cards.length !== groups.length) return;

    cards.forEach((card, index) => {
      if (card.querySelector('.permanent-controller-context')) return;
      const resolved = controllersFor(groups[index]);
      if (!resolved.controllers.length) return;

      const box = document.createElement('div');
      box.className = 'permanent-controller-context';

      const label = document.createElement('span');
      label.className = 'permanent-controller-label';
      label.textContent = resolved.exact
        ? (resolved.controllers.length === 1 ? 'Controller' : 'Controllers')
        : (resolved.controllers.length === 1 ? 'Assigned Controller' : 'Assigned Controllers');
      box.appendChild(label);

      const links = document.createElement('span');
      links.className = 'permanent-controller-links';
      resolved.controllers.forEach((controller, controllerIndex) => {
        if (controllerIndex) links.appendChild(document.createTextNode(' · '));
        const anchor = document.createElement('a');
        anchor.className = 'permanent-controller-link';
        anchor.href = `controllers?controller_id=${encodeURIComponent(controller.controller_id)}`;
        anchor.textContent = `CTRL ${controller.controller_id}${controller.model_code ? ` · ${controller.model_code}` : ''}`;
        anchor.title = resolved.exact
          ? 'Open this permanent physical Controller in Controller Inventory'
          : 'Open assigned permanent Controller; exact E1.31/DMX group partition is not claimed here';
        links.appendChild(anchor);
      });
      box.appendChild(links);

      if (!resolved.exact) {
        const note = document.createElement('span');
        note.className = 'permanent-controller-note';
        note.textContent = 'Display assignment';
        box.appendChild(note);
      }

      const head = card.querySelector('.controller-head');
      if (head) head.appendChild(box);
      else card.prepend(box);
    });
  }

  new MutationObserver(decorate).observe(target, {childList: true});
  decorate();
})();
