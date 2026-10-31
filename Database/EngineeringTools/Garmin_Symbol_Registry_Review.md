# Garmin Type-to-symbol registry — #171

`garmin_symbol_registry.json` is a **review candidate** based on the October 14 authoritative 236-waypoint inventory and the operator's accepted name examples. It is not a complete Garmin release or approval to overwrite the master GPX or device icons.

Every record explicitly couples one ExpertGPS Type, one approved local PNG derivative from Plain, and one named Garmin BMP stem used for outgoing GPX `<sym>`.

- `Panel` → `panel.png` → `PANEL.bmp` / `PANEL`: already demonstrated physically on GPSMAP 66sr.
- `OUT-Combo` → `outlet-combo.png` → `Outlet_Combo.bmp` / `Outlet_Combo`: matches known working custom image associations.
- `Stage` → `stage.png` → `Stage.bmp` / `Stage`: **must use approved arch**, not old Garmin star.
- `LP-Combo`, `LP-Power`, `LP-Network`: independently mapped as discussed; `LP-Power` deliberately uses artwork filename `lp-outlet.png`, not a nonexistent `lp-power.png`.

The six Types account for **145 waypoints** in the October 14 snapshot (17+84+33+6+4+1). The candidate GPX remaps are 9+84+33+6+4+1 = **137** (LP-Combo has an existing `Outlet_Combo` mismatch, all six map to `LP_Combo`). Exact count must be re-evaluated at release time; the source may change.

All other Types remain **unmapped**, retaining original `sym` in a preview. In particular, `Outlet Power` historically mixes five GPS symbols; no blanket Type remap or inference is approved. No direct Garmin volume writes, source master mutations, or web-server changes.

Approval gate: inspect the source artwork rendered as 24-bit BMP, verify the exact approved Type mapping and any per-waypoint exceptions, then produce a reviewed waypoint-only device export and controlled BMP installation with backups, hash readback, and rollback.
