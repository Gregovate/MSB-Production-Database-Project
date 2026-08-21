(function () {
  "use strict";

  const workspace = document.getElementById("workspace");
  const imageSection = document.getElementById("image-section");
  const hookupPane = document.getElementById("hookup-pane");
  const imageToolbar = imageSection?.querySelector(".image-toolbar .toolbar-group");
  const hookupHeading = hookupPane?.querySelector(".hookup-heading");
  const imageToggle = document.getElementById("image-toggle");

  if (!workspace || !imageSection || !hookupPane || !imageToolbar || !hookupHeading) return;

  const imageButton = document.createElement("button");
  imageButton.type = "button";
  imageButton.className = "workspace-focus-button";
  imageButton.textContent = "Expand Image";
  imageButton.title = "Give the image the working area";

  const hookupButton = document.createElement("button");
  hookupButton.type = "button";
  hookupButton.className = "workspace-focus-button screen-only";
  hookupButton.textContent = "Expand Hookup";
  hookupButton.title = "Give Field Hookup the working area";

  imageToolbar.appendChild(imageButton);
  hookupHeading.insertBefore(hookupButton, hookupHeading.querySelector(".legend"));

  function mode() {
    if (workspace.classList.contains("workspace-focus-image")) return "image";
    if (workspace.classList.contains("workspace-focus-hookup")) return "hookup";
    return "split";
  }

  function applyMode(next) {
    workspace.classList.toggle("workspace-focus-image", next === "image");
    workspace.classList.toggle("workspace-focus-hookup", next === "hookup");

    imageButton.textContent = next === "image" ? "Restore Split" : "Expand Image";
    hookupButton.textContent = next === "hookup" ? "Restore Split" : "Expand Hookup";

    imageButton.setAttribute("aria-pressed", String(next === "image"));
    hookupButton.setAttribute("aria-pressed", String(next === "hookup"));

    if (next === "image" && typeof setImageVisible === "function") {
      setImageVisible(true);
    }

    if (typeof applyImageScale === "function" && next !== "hookup") {
      setTimeout(applyImageScale, 0);
    }
  }

  imageButton.addEventListener("click", () => {
    applyMode(mode() === "image" ? "split" : "image");
  });

  hookupButton.addEventListener("click", () => {
    applyMode(mode() === "hookup" ? "split" : "hookup");
  });

  imageToggle?.addEventListener("click", () => {
    if (mode() === "image") applyMode("split");
  });

  // The base renderer recalculates image sizing on viewport changes. Reapply
  // focus state afterward so a resize never silently returns the workspace to
  // the split layout.
  window.addEventListener("resize", () => {
    const current = mode();
    if (current !== "split") setTimeout(() => applyMode(current), 0);
  });

  applyMode("split");
})();
