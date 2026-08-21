(function () {
  "use strict";

  const groupsRoot = document.getElementById("controller-groups");
  if (!groupsRoot) return;

  function esc(value) {
    return String(value ?? "")
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#39;");
  }

  function fmt(value) {
    return value === null || value === undefined || value === "" ? "—" : String(value);
  }

  function fixtureRows(group) {
    const fixtures = new Map();
    for (const row of group.rows || []) {
      const key = row.dmx_fixture_key ||
        `review:${row.source_raw_prop_id || ""}:${row.channel_name || ""}:${row.start_channel || ""}`;
      if (!fixtures.has(key)) fixtures.set(key, row);
    }
    return [...fixtures.values()].sort((a, b) =>
      Number(a.dmx_fixture_start || 999999) - Number(b.dmx_fixture_start || 999999)
    );
  }

  function groupUniverse(group) {
    const values = [...new Set(
      (group.rows || [])
        .map((row) => row.start_universe ?? row.controller)
        .filter((value) => value !== null && value !== undefined && value !== "")
        .map(String)
    )];
    return values.length === 1 ? values[0] : values.join(", ");
  }

  function renderDumbRgbCards() {
    if (typeof packageData === "undefined" || !packageData?.controller_groups) return;

    const dataGroups = packageData.controller_groups.filter((group) => group.family === "DUMBRGB");
    const cards = [...groupsRoot.querySelectorAll(".controller-card.dumbrgb-card")];

    cards.forEach((card, index) => {
      const group = dataGroups[index];
      if (!group) return;
      const wrap = card.querySelector(".hookup-table-wrap");
      if (!wrap) return;

      const title = card.querySelector(".controller-title > strong");
      if (title) title.textContent = "DMX / DUMBRGB";

      const meta = card.querySelector(".controller-meta");
      if (meta) {
        meta.querySelector(".dmx-universe-meta")?.remove();
        const universe = groupUniverse(group);
        if (universe) {
          meta.insertAdjacentHTML(
            "afterbegin",
            `<span class="controller-meta-item dmx-universe-meta"><span class="controller-meta-label">Universe</span><span class="controller-meta-value">${esc(universe)}</span></span>`
          );
        }
      }

      const rows = fixtureRows(group).map((row) => {
        const trigger = packageData.context.display_id &&
          Number(row.display_id) === Number(packageData.context.display_id);
        const label = row.dmx_fixture_label || row.channel_name || row.display_name || "Review required";
        return `<tr class="${trigger ? "trigger-row" : ""}">
          <td>${esc(label)}</td>
          <td>${esc(fmt(row.start_universe ?? row.controller))}</td>
          <td class="output-cell">${esc(fmt(row.dmx_fixture_start))}</td>
          <td>${esc(fmt(row.dmx_rgb_channels))}</td>
        </tr>`;
      }).join("");

      wrap.innerHTML = `<table class="hookup-table simple-family-table dumbrgb-table">
        <thead><tr>
          <th>Fixture / Channel</th>
          <th>Universe</th>
          <th>DMX Start Address</th>
          <th>RGB Channels</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>`;
    });

    if (dataGroups.length) {
      const allDumbRgb = packageData.controller_groups.every((group) => group.family === "DUMBRGB");
      const fixtureCount = new Set(
        packageData.controller_groups
          .filter((group) => group.family === "DUMBRGB")
          .flatMap((group) => group.rows || [])
          .map((row) => row.dmx_fixture_key)
          .filter(Boolean)
      ).size;
      if (allDumbRgb) {
        document.getElementById("row-summary").textContent =
          `${fixtureCount} DMX fixture hookups · ${dataGroups.length} presentation ${dataGroups.length === 1 ? "group" : "groups"}`;
      }
    }
  }

  const observer = new MutationObserver(renderDumbRgbCards);
  observer.observe(groupsRoot, { childList: true });
  renderDumbRgbCards();
})();
