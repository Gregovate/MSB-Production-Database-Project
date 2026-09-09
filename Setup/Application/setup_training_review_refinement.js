/* Browser-review refinements from the 2026-09-08 Setup reconstruction preview. */

(() => {
  const captainTypeahead = {
    selectedPersonId: null
  };

  function relocateCatalogReturnControl() {
    const actions = document.getElementById('reusable-manager-actions');
    const wrap = document.getElementById('setup-return-library-wrap');
    if (!actions || !wrap) return;
    const deleteButton = document.getElementById('delete-reconstruction-task');
    if (wrap.parentElement !== actions) {
      actions.insertBefore(wrap, deleteButton || null);
    } else if (deleteButton && wrap.nextElementSibling !== deleteButton) {
      actions.insertBefore(wrap, deleteButton);
    }
  }

  function ensureCaptainTypeahead() {
    const search = document.getElementById('setup-captain-search');
    const select = document.getElementById('setup-captain-person');
    if (!search || !select || document.getElementById('setup-captain-typeahead-results')) return;

    const selectLabel = select.closest('label');
    if (selectLabel) selectLabel.hidden = true;
    select.removeAttribute('size');

    const searchLabel = search.closest('label');
    if (!searchLabel) return;

    const help = document.createElement('div');
    help.className = 'setup-captain-typeahead-help muted';
    help.textContent = 'Type at least 2 characters, then choose a matching person.';

    const results = document.createElement('div');
    results.id = 'setup-captain-typeahead-results';
    results.className = 'setup-captain-typeahead-results';
    results.hidden = true;

    const chosen = document.createElement('div');
    chosen.id = 'setup-captain-typeahead-chosen';
    chosen.className = 'setup-captain-typeahead-chosen muted';
    chosen.textContent = 'No person selected.';

    searchLabel.append(help, results, chosen);

    const renderMatches = () => {
      const query = String(search.value || '').trim();
      if (query.length < 2) {
        results.hidden = true;
        results.innerHTML = '';
        return;
      }

      const options = [...select.options].slice(0, 10);
      if (!options.length) {
        results.innerHTML = '<div class="setup-captain-no-match muted">No matching people.</div>';
        results.hidden = false;
        return;
      }

      results.innerHTML = options.map((option) => (
        `<button type="button" class="setup-captain-typeahead-match" data-person-id="${escapeHtml(option.value)}">${escapeHtml(option.textContent || '')}</button>`
      )).join('');
      results.hidden = false;
    };

    search.addEventListener('input', () => requestAnimationFrame(renderMatches));
    search.addEventListener('focus', () => requestAnimationFrame(renderMatches));

    results.addEventListener('click', (event) => {
      const match = event.target.closest('.setup-captain-typeahead-match');
      if (!match) return;
      const personId = String(match.dataset.personId || '');
      const option = [...select.options].find((item) => String(item.value) === personId);
      if (!option) return;
      select.value = personId;
      captainTypeahead.selectedPersonId = Number(personId);
      search.value = option.textContent || '';
      chosen.textContent = `Selected: ${option.textContent || `Person ${personId}`}`;
      results.hidden = true;
    });

    document.addEventListener('click', (event) => {
      if (!event.target.closest('.setup-captain-picker-grid')) results.hidden = true;
      if (event.target.closest('#setup-captain-clear')) {
        requestAnimationFrame(() => {
          captainTypeahead.selectedPersonId = null;
          search.value = '';
          chosen.textContent = 'No person selected.';
          results.hidden = true;
        });
      }
      if (event.target.closest('.setup-captain-edit')) {
        requestAnimationFrame(() => {
          const option = select.selectedOptions?.[0];
          if (!option) return;
          captainTypeahead.selectedPersonId = Number(option.value);
          search.value = option.textContent || '';
          chosen.textContent = `Selected: ${option.textContent || `Person ${option.value}`}`;
          results.hidden = true;
        });
      }
    });

    const captainList = document.getElementById('setup-captain-list');
    if (captainList) {
      new MutationObserver(() => {
        if (select.selectedIndex < 0) {
          captainTypeahead.selectedPersonId = null;
          search.value = '';
          chosen.textContent = 'No person selected.';
          results.hidden = true;
        }
      }).observe(captainList, { childList: true, subtree: true });
    }
  }

  function ensureMaterialDialog() {
    let dialog = document.getElementById('setup-material-details-dialog');
    if (dialog) return dialog;

    dialog = document.createElement('dialog');
    dialog.id = 'setup-material-details-dialog';
    dialog.className = 'setup-material-details-dialog';
    dialog.innerHTML = `
      <div class="setup-material-dialog-heading">
        <div>
          <div class="eyebrow">Material / Logistics Context</div>
          <h3 id="setup-material-dialog-title">Material Details</h3>
        </div>
        <button id="setup-material-dialog-close" type="button" class="secondary">Close</button>
      </div>
      <div id="setup-material-dialog-content" class="setup-material-dialog-content"></div>
    `;
    document.body.appendChild(dialog);
    dialog.querySelector('#setup-material-dialog-close')?.addEventListener('click', () => dialog.close());
    dialog.addEventListener('click', (event) => {
      if (event.target === dialog) dialog.close();
    });
    return dialog;
  }

  function compactMaterialDetails() {
    const body = document.getElementById('setup-material-context-body');
    if (!body || body.querySelector('.setup-material-compact')) return;

    const hasDetails = Boolean(
      body.querySelector('.setup-material-container, .setup-support-container-block')
    );
    if (!hasDetails) return;

    const dialog = ensureMaterialDialog();
    const content = dialog.querySelector('#setup-material-dialog-content');
    const title = dialog.querySelector('#setup-material-dialog-title');
    if (!content || !title) return;

    const detailHtml = body.innerHTML;
    const taskName = document.getElementById('detail-task-name')?.textContent?.trim() || 'Reusable Task';
    title.textContent = `${taskName} — Material Details`;
    content.innerHTML = detailHtml;

    body.innerHTML = `
      <div class="setup-material-compact">
        <button id="setup-material-details-open" type="button" class="secondary">View Material Details</button>
        <span class="muted">Open the Container / Display list and relationship reasons only when needed.</span>
      </div>
      <div class="setup-controller-context-note setup-controller-context-compact">
        <strong>Controllers:</strong> authoritative Controller context is not surfaced by this resolver yet.
      </div>
    `;
    body.querySelector('#setup-material-details-open')?.addEventListener('click', () => dialog.showModal());
  }

  function observeMaterialContext() {
    const body = document.getElementById('setup-material-context-body');
    if (!body || body.dataset.compactObserverInstalled === '1') return;
    body.dataset.compactObserverInstalled = '1';
    new MutationObserver(() => compactMaterialDetails()).observe(body, { childList: true });
    compactMaterialDetails();
  }

  function initializeRefinements() {
    relocateCatalogReturnControl();
    ensureCaptainTypeahead();
    observeMaterialContext();
  }

  initializeRefinements();

  new MutationObserver(() => initializeRefinements()).observe(
    document.getElementById('review-detail') || document.body,
    { childList: true, subtree: true }
  );

  document.addEventListener('click', () => requestAnimationFrame(initializeRefinements), true);
})();
