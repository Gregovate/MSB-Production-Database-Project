/* Interpret the existing append-only activity ledger; no independent state store. */
"use strict";
globalThis.MSBBreakerState = Object.freeze({
  latest(events, breakerId) {
    const corrected = new Set(events.map(e => e.corrects_event_id).filter(x => x != null).map(String));
    return events.filter(e => !corrected.has(String(e.event_id)) &&
      String(e.definition_snapshot?.site_power_breaker_id) === String(breakerId) &&
      ["REPORTED", "FIELD_VERIFIED", "COMPLETED", "UTILITY_CONFIRMED"].includes(e.event_kind))
      .sort((a,b) => Date.parse(b.observed_at)-Date.parse(a.observed_at) || Number(b.event_id)-Number(a.event_id))[0] || null;
  },
  classify(breaker, event, year, phase) {
    const known = x => ["ON", "OFF"].includes(x);
    const show=breaker.show_desired_state, restoration=breaker.restoration_desired_state;
    if (!known(show) || !known(restoration)) return "configuration";
    if (show === restoration) return "unchanged";
    const required=phase === "RESTORATION" ? restoration : show;
    return event?.condition === required && Number(event.season_year) === Number(year) &&
      event.definition_snapshot?.phase === phase ? "completed" : "open";
  },
});
