(function () {
  'use strict';

  const searchInput = document.getElementById('controller-search');
  const stageFilter = document.getElementById('stage-filter');
  const target = document.getElementById('search-context');

  if (!searchInput || !stageFilter || !target) return;

  function stageName(option) {
    const text = (option.textContent || '').trim();
    const parts = text.split(' · ');
    return parts.length > 1 ? parts.slice(1).join(' · ') : text;
  }

  function renderSearchContext() {
    const query = searchInput.value.trim().toLowerCase();

    // An explicit Stage/Sub-stage filter already confirms the active Stage.
    if (!query || stageFilter.value) {
      target.hidden = true;
      target.textContent = '';
      return;
    }

    const matches = [...stageFilter.options].filter(option => {
      if (!option.value) return false;
      return (option.textContent || '').toLowerCase().includes(query);
    });

    if (!matches.length) {
      target.hidden = true;
      target.textContent = '';
      return;
    }

    const names = matches.map(stageName);
    target.textContent = names.length === 1
      ? `Stage search match: ${names[0]}`
      : `Stage search matches: ${names.join(', ')}`;
    target.hidden = false;
  }

  searchInput.addEventListener('input', renderSearchContext);
  stageFilter.addEventListener('change', renderSearchContext);

  // controllers.js populates the Stage/Sub-stage choices after the first API load.
  new MutationObserver(renderSearchContext).observe(stageFilter, {childList: true});

  renderSearchContext();
})();
