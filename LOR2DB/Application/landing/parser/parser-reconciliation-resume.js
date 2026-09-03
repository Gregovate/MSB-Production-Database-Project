/* MSB parser reconciliation resume bridge - 2026-08-30 V0.6.2.2 */
(function () {
  "use strict";

  const app = document.querySelector("#app");
  const REVIEW_URL = /^preflight\/\?run=\d+$/;
  let requestInFlight = false;

  if (!app) return;

  async function loadWorkflow() {
    const response = await fetch("../preflight/api/dashboard", {
      credentials: "same-origin",
      headers: { "Content-Type": "application/json" }
    });
    const payload = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(payload.error || `Request failed (${response.status})`);
    }
    return payload.workflow;
  }

  function applyReviewAction(refreshButton, workflow) {
    const action = workflow?.action;
    const reviewUrl = String(action?.url || "");

    if (action?.kind !== "review" || !REVIEW_URL.test(reviewUrl)) {
      return false;
    }

    const link = document.createElement("a");
    link.id = "continue-reconciliation";
    link.className = "primary";
    link.href = `../${reviewUrl}`;
    link.textContent = action.label || "Continue reconciliation";
    refreshButton.replaceWith(link);

    const section = link.closest("section");
    if (section) {
      const heading = section.querySelector("h2");
      if (heading) heading.textContent = "Continue reconciliation";

      const pill = section.querySelector(".pill");
      if (pill) pill.textContent = "RECONCILIATION IN PROGRESS";

      const detail = section.querySelector(".card-title + p");
      if (detail) {
        detail.textContent = workflow?.message
          || "A reconciliation already exists for this snapshot. Continue that persisted run.";
      }
    }

    return true;
  }

  async function reconcileControl() {
    const refreshButton = document.querySelector("#refresh-reconciliation");
    if (!refreshButton || requestInFlight) return;

    requestInFlight = true;
    try {
      const workflow = await loadWorkflow();
      applyReviewAction(refreshButton, workflow);
    } catch (error) {
      // Leave the existing refresh control intact. The parser page remains
      // usable and a later render/refresh will retry this read-only lookup.
      console.error("Unable to load persisted reconciliation action", error);
    } finally {
      requestInFlight = false;
    }
  }

  const observer = new MutationObserver(() => {
    void reconcileControl();
  });

  observer.observe(app, { childList: true, subtree: true });
  void reconcileControl();
}());
