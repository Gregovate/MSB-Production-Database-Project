// Controller Inventory live-acceptance UX refinements — 2026-09-02.
(function () {
  'use strict';

  const HELP = {
    verification_state: 'Records how confidently this physical Controller has been verified. Use field verification when the actual hardware has been checked in person.',
    is_display_attached: 'Is this Controller physically mounted to, stored with, or normally moved with a Display? This is separate from Controller-to-Display assignments.',
    label_required: 'Marks that this permanent Controller asset should have a physical identity label. This does not itself request a print.',
    lor_uid_start: 'The first programmed LOR Unit ID, entered in hexadecimal. Example: 30. This is current programming, not permanent Controller identity.',
    lor_uid_count: 'How many sequential LOR Unit IDs this Controller currently uses. Enter an ordinary decimal count; model capacity rules still apply.',
    programmed_config_verification_state: 'Shows whether the recorded Network / UID / IP programming is unknown, recorded but not field-verified, or verified against the physical Controller.',
    programmed_config_source_note: 'Record where the programmed configuration came from or what was checked when it was verified.',
    firmware_verification_state: 'Shows whether the installed firmware is unknown, recorded but not field-verified, or verified on the physical Controller.',
    wiring_source_display: 'Use another Display only when this physical Display intentionally copies wiring defined by another Display. This does not change permanent Controller identity.',
  };

  function esc(value) {
    return String(value ?? '')
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;').replaceAll("'", '&#39;');
  }

  function makeHelp(helpText, labelText) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'field-help';
    button.textContent = '?';
    button.dataset.help = helpText;
    button.setAttribute('aria-label', `Help for ${labelText}`);
    button.addEventListener('click', event => {
      event.preventDefault();
      event.stopPropagation();
      const open = button.classList.toggle('help-open');
      for (const other of document.querySelectorAll('.field-help.help-open')) {
        if (other !== button) other.classList.remove('help-open');
      }
      if (open) button.focus({preventScroll:true});
    });
    return button;
  }

  function decorateField(form, name, labelText, helpText) {
    const control = form?.elements?.[name];
    if (!control) return;
    const label = control.closest('label');
    if (!label || label.dataset.helpDecorated === '1') return;

    const textNode = [...label.childNodes].find(node =>
      node.nodeType === Node.TEXT_NODE && String(node.textContent || '').trim()
    );
    if (textNode) textNode.textContent = '';

    const header = document.createElement('span');
    header.className = 'field-label-header';
    header.innerHTML = `<span>${esc(labelText)}</span>`;
    header.appendChild(makeHelp(helpText, labelText));
    label.insertBefore(header, label.firstChild);
    label.dataset.helpDecorated = '1';
  }

  function decorateInlineField(form, name, helpText, labelText) {
    const control = form?.elements?.[name];
    if (!control) return;
    const label = control.closest('label');
    if (!label || label.dataset.helpDecorated === '1') return;
    label.appendChild(document.createTextNode(' '));
    label.appendChild(makeHelp(helpText, labelText));
    label.dataset.helpDecorated = '1';
  }

  function decorateControllerForm(dialog) {
    if (!dialog || dialog.dataset.uxRefined === '1') return;
    const form = dialog.querySelector('#controller-maintenance-form');
    if (!form) return;

    decorateField(form, 'verification_state', 'Physical Verification', HELP.verification_state);
    decorateField(form, 'is_display_attached', 'Physically Attached to Display', HELP.is_display_attached);
    decorateInlineField(form, 'label_required', HELP.label_required, 'Label required');
    decorateField(form, 'lor_uid_start', 'First UID (hex)', HELP.lor_uid_start);
    decorateField(form, 'lor_uid_count', 'UID Count', HELP.lor_uid_count);
    decorateField(form, 'programmed_config_verification_state', 'Configuration Verification', HELP.programmed_config_verification_state);
    decorateField(form, 'programmed_config_source_note', 'Configuration Source / Verification Note', HELP.programmed_config_source_note);
    decorateField(form, 'firmware_verification_state', 'Firmware Verification', HELP.firmware_verification_state);
    dialog.dataset.uxRefined = '1';
  }

  function decorateWiringSource(root) {
    for (const strong of root.querySelectorAll?.('.wiring-source-picker .management-inline strong') || []) {
      if (strong.dataset.helpDecorated === '1') continue;
      if (!/LOR wiring source/i.test(strong.textContent || '')) continue;
      strong.appendChild(document.createTextNode(' '));
      strong.appendChild(makeHelp(HELP.wiring_source_display, 'Wiring Source Display'));
      strong.dataset.helpDecorated = '1';
    }
  }

  function removeDuplicateAddControllerButtons() {
    const buttons = [...document.querySelectorAll('#add-controller-button')];
    for (const duplicate of buttons.slice(1)) duplicate.remove();
  }

  function decoratePrintButton() {
    const button = document.getElementById('request-controller-label');
    if (button) button.classList.add('print-action-button');
  }

  function apply(root = document) {
    removeDuplicateAddControllerButtons();
    decoratePrintButton();

    if (root instanceof Element) {
      if (root.id === 'controller-edit-dialog') decorateControllerForm(root);
      root.querySelectorAll?.('#controller-edit-dialog').forEach(decorateControllerForm);
      decorateWiringSource(root);
    } else {
      document.querySelectorAll('#controller-edit-dialog').forEach(decorateControllerForm);
      decorateWiringSource(document);
    }
  }

  const observer = new MutationObserver(mutations => {
    removeDuplicateAddControllerButtons();
    decoratePrintButton();
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node instanceof Element) apply(node);
      }
    }
  });
  observer.observe(document.body, {childList:true, subtree:true});

  document.addEventListener('click', event => {
    if (event.target.closest?.('.field-help')) return;
    document.querySelectorAll('.field-help.help-open').forEach(button => button.classList.remove('help-open'));
  });

  apply();
})();
