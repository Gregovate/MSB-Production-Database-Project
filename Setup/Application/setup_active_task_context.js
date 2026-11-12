/* Persistent active Setup task identity for Issue #169.
 *
 * Presentation only: mirror the existing selected task heading into the
 * already-sticky global Setup header. No API, save, navigation, or dirty-edit
 * behavior lives here.
 */

(() => {
  'use strict';

  function ensureContext() {
    let context = document.getElementById('setup-active-task-context');
    if (context) return context;

    const brandCopy = document.querySelector('.site-header .brand-copy');
    if (!brandCopy) return null;

    context = document.createElement('div');
    context.id = 'setup-active-task-context';
    context.className = 'active-task-context';
    context.hidden = true;
    context.setAttribute('aria-live', 'polite');
    context.innerHTML = '<span class="active-task-context-label">Active task</span><span class="active-task-context-identity"></span>';
    brandCopy.appendChild(context);
    return context;
  }

  function syncContext() {
    const context = ensureContext();
    if (!context) return;

    const reviewView = document.getElementById('review-view');
    const reviewDetail = document.getElementById('review-detail');
    const stage = document.getElementById('detail-stage')?.textContent?.trim() || '';
    const taskName = document.getElementById('detail-task-name')?.textContent?.trim() || '';
    const visible = Boolean(
      reviewView?.classList.contains('active-view') &&
      reviewDetail &&
      !reviewDetail.hidden &&
      taskName
    );

    context.hidden = !visible;
    const identity = context.querySelector('.active-task-context-identity');
    if (identity) identity.textContent = visible ? `${stage}${stage ? ' · ' : ''}${taskName}` : '';
  }

  const watchText = (node) => {
    if (!node) return;
    new MutationObserver(() => syncContext()).observe(node, {
      childList: true,
      characterData: true,
      subtree: true
    });
  };

  watchText(document.getElementById('detail-stage'));
  watchText(document.getElementById('detail-task-name'));

  const reviewDetail = document.getElementById('review-detail');
  if (reviewDetail) {
    new MutationObserver(() => syncContext()).observe(reviewDetail, {
      attributes: true,
      attributeFilter: ['hidden']
    });
  }

  const reviewView = document.getElementById('review-view');
  if (reviewView) {
    new MutationObserver(() => syncContext()).observe(reviewView, {
      attributes: true,
      attributeFilter: ['class']
    });
  }

  document.addEventListener('click', () => requestAnimationFrame(syncContext), true);
  syncContext();
})();
