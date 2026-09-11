/* Compact Setup task-detail presentation for Issue #153.
 *
 * Presentation only: no API, authorization, or save behavior lives here.
 * The Captain editor is relocated into the unused right rail beneath Annual
 * Review so the reusable editor no longer determines the height of the whole
 * two-column block.
 */

(() => {
  'use strict';

  function applyCompactTaskDetailLayout() {
    const detail = document.getElementById('review-detail');
    const split = detail?.querySelector('.split-section');
    const annual = document.getElementById('annual-fieldset');
    const captain = document.getElementById('setup-captain-section');
    const material = document.getElementById('setup-material-context-section');

    if (split) split.classList.add('setup-task-editor-grid');
    if (material) material.classList.add('setup-material-context-compact-section');

    if (split && annual && captain) {
      captain.classList.add('setup-captain-rail');
      if (captain.parentElement !== split || captain.previousElementSibling !== annual) {
        annual.insertAdjacentElement('afterend', captain);
      }
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
