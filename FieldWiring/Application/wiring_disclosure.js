(function () {
  "use strict";

  const groups = document.getElementById("controller-groups");
  if (!groups) return;

  function setExpanded(card, expanded) {
    card.classList.toggle("is-collapsed", !expanded);
    const head = card.querySelector(".controller-head");
    if (head) head.setAttribute("aria-expanded", String(expanded));
  }

  function toggle(card) {
    setExpanded(card, card.classList.contains("is-collapsed"));
  }

  function prepareCards() {
    const cards = [...groups.querySelectorAll(".controller-card")];
    cards.forEach((card, index) => {
      if (card.dataset.disclosureReady === "true") return;
      card.dataset.disclosureReady = "true";

      const head = card.querySelector(".controller-head");
      if (!head) return;

      head.setAttribute("role", "button");
      head.setAttribute("tabindex", "0");
      head.setAttribute("aria-expanded", "true");
      head.setAttribute("title", "Expand or collapse this wiring group");

      head.addEventListener("click", () => toggle(card));
      head.addEventListener("keydown", (event) => {
        if (event.key !== "Enter" && event.key !== " ") return;
        event.preventDefault();
        toggle(card);
      });

      // Keep the first wiring group visible on initial load. Additional groups
      // begin collapsed so large Stage/Scene packages do not turn into a wall
      // of controller tables before the technician chooses what they need.
      setExpanded(card, index === 0);
    });
  }

  const observer = new MutationObserver(prepareCards);
  observer.observe(groups, { childList: true });
  prepareCards();

  // Hard-copy output must always contain every controller relationship,
  // regardless of what the operator happened to collapse on screen.
  let printState = [];
  window.addEventListener("beforeprint", () => {
    printState = [...groups.querySelectorAll(".controller-card")].map((card) => ({
      card,
      collapsed: card.classList.contains("is-collapsed"),
    }));
    printState.forEach(({ card }) => setExpanded(card, true));
  });
  window.addEventListener("afterprint", () => {
    printState.forEach(({ card, collapsed }) => setExpanded(card, !collapsed));
    printState = [];
  });
})();
