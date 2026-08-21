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

  function channelRange(row) {
    if (row.start_channel === null || row.start_channel === undefined ||
        row.end_channel === null || row.end_channel === undefined) return "—";
    return `${row.start_channel}-${row.end_channel}`;
  }

  function renderE131Cards() {
    if (typeof packageData === "undefined" || !packageData?.controller_groups) return;

    const dataGroups = packageData.controller_groups.filter((group) => group.family === "E131");
    const cards = [...groupsRoot.querySelectorAll(".controller-card.e131-card")];

    cards.forEach((card, index) => {
      const group = dataGroups[index];
      if (!group) return;
      const wrap = card.querySelector(".hookup-table-wrap");
      if (!wrap) return;

      const rows = group.rows.map((row) => {
        const trigger = packageData.context.display_id &&
          Number(row.display_id) === Number(packageData.context.display_id);
        return `<tr class="${trigger ? "trigger-row" : ""}">
          <td class="output-cell">${esc(fmt(row.physical_output ?? "Review"))}</td>
          <td>${esc(row.channel_name || row.display_name || "—")}</td>
          <td>${esc(fmt(row.start_universe ?? row.controller))}</td>
          <td>${esc(fmt(row.pixel_count))}</td>
          <td>${esc(channelRange(row))}</td>
        </tr>`;
      }).join("");

      wrap.innerHTML = `<table class="hookup-table simple-family-table e131-table">
        <thead><tr>
          <th>Output / Port</th>
          <th>Channel / Display Section</th>
          <th>Universe</th>
          <th>Pixels</th>
          <th>Channel Range</th>
        </tr></thead>
        <tbody>${rows}</tbody>
      </table>`;
    });
  }

  const observer = new MutationObserver(renderE131Cards);
  observer.observe(groupsRoot, { childList: true });
  renderE131Cards();
})();
