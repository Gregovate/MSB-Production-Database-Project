/* Compact Setup task-detail presentation for Issue #153.
 *
 * Presentation only: no API, authorization, or save behavior lives here.
 * The editor is organized into two independent vertical rails so the shorter
 * side can keep using available space instead of inheriting the other side's
 * row height.
 */

(() => {
  'use strict';

  function ensureEditorRail(split, className) {
    let rail = split?.querySelector(`:scope > .${className}`);
    if (rail || !split) return rail;
    rail = document.createElement('div');
    rail.className = className;
    split.appendChild(rail);
    return rail;
  }

  function compactMaterialWording(material) {
    if (!material) return;
    material.classList.add('setup-material-context-compact-section');

    const heading = material.querySelector(':scope > h3');
    if (heading) heading.textContent = '4. Material / Logistics';

    const purpose = material.querySelector(':scope > .task-section-purpose');
    if (purpose) {
      purpose.textContent = 'Current Displays and Containers resolved automatically from this task\'s Stage or Scene.';
    }

    const detailHint = material.querySelector('.setup-material-compact .muted');
    if (detailHint) detailHint.textContent = 'Full Display / Container list and inclusion reasons.';

    const controller = material.querySelector('.setup-controller-context-compact');
    if (controller) {
      controller.innerHTML = '<strong>Controllers:</strong> not included in this resolver yet.';
    }
  }

  function applyCompactTaskDetailLayout() {
    const detail = document.getElementById('review-detail');
    const split = detail?.querySelector('.split-section');
    const reusable = document.getElementById('reusable-fieldset');
    const annual = document.getElementById('annual-fieldset');
    const captain = document.getElementById('setup-captain-section');
    const material = document.getElementById('setup-material-context-section');

    if (!split) return;
    split.classList.add('setup-task-editor-grid');

    const leftRail = ensureEditorRail(split, 'setup-task-editor-left');
    const rightRail = ensureEditorRail(split, 'setup-task-editor-right');

    if (reusable && leftRail && reusable.parentElement !== leftRail) leftRail.appendChild(reusable);
    if (annual && rightRail && annual.parentElement !== rightRail) rightRail.appendChild(annual);

    if (captain && rightRail) {
      captain.classList.add('setup-captain-rail');
      if (captain.parentElement !== rightRail) rightRail.appendChild(captain);
    }

    if (material && leftRail) {
      compactMaterialWording(material);
      if (material.parentElement !== leftRail) leftRail.appendChild(material);
    }
  }

  applyCompactTaskDetailLayout();

  const host = document.getElementById('review-detail') || document.body;
  new MutationObserver(() => requestAnimationFrame(applyCompactTaskDetailLayout)).observe(
    host,
    { childList: true, subtree: true }
  );

  document.addEventListener(
    'click',
    () => requestAnimationFrame(applyCompactTaskDetailLayout),
    true
  );
})();
