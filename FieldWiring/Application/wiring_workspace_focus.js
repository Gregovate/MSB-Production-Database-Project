(function () {
  "use strict";

  const imageSection = document.getElementById("image-section");
  const hookupPane = document.getElementById("hookup-pane");
  const imageToolbar = imageSection?.querySelector(".image-toolbar");
  const divider = document.getElementById("divider");

  if (!imageSection || !hookupPane || !imageToolbar || !divider) return;

  const controls = document.createElement("div");
  controls.className = "toolbar-group workspace-ratio-controls screen-only";

  const presets = [
    ["image", "More Image", "68%"],
    ["balanced", "Balanced", "50%"],
    ["hookup", "More Hookup", "30%"],
  ];

  const buttons = new Map();
  for (const [key, label] of presets) {
    const button = document.createElement("button");
    button.type = "button";
    button.textContent = label;
    button.dataset.workspacePreset = key;
    button.setAttribute("aria-pressed", "false");
    controls.appendChild(button);
    buttons.set(key, button);
  }

  imageToolbar.appendChild(controls);

  function setPressed(key) {
    for (const [name, button] of buttons) {
      button.setAttribute("aria-pressed", String(name === key));
    }
  }

  function applyPreset(key) {
    const preset = presets.find(([name]) => name === key);
    if (!preset) return;

    const basis = preset[2];
    if (typeof setImageVisible === "function") setImageVisible(true);

    // Keep the base renderer's remembered split in sync so Hide/Show Image
    // returns to the last selected preset instead of an unrelated default.
    if (typeof expandedImageBasis !== "undefined") expandedImageBasis = basis;
    imageSection.style.flexBasis = basis;
    setPressed(key);

    if (typeof applyImageScale === "function") setTimeout(applyImageScale, 0);
  }

  controls.addEventListener("click", (event) => {
    const button = event.target.closest("button[data-workspace-preset]");
    if (!button) return;
    applyPreset(button.dataset.workspacePreset);
  });

  // The existing divider remains the fine-grained control. Once the operator
  // starts dragging, clear the preset highlight and let wiring.js own the exact
  // pixel split. Its parent is now the bounded image/hookup work area.
  divider.addEventListener("pointerdown", () => {
    setPressed(null);
    imageSection.style.flex = "0 0 auto";
  });

  // Start with a true shared split on desktop/laptop. On mobile the controls are
  // hidden and the existing page-scroll behavior remains unchanged.
  if (window.matchMedia("(min-width: 801px)").matches) {
    applyPreset("balanced");
  }
})();
