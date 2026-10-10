# Setup Park Map entry — #122 / #171

Base main: `123f24e0a91707984e8325af29d13d287102b3b6`.

Greg confirmed the shared map works from Field Wiring and the temporary direct entry, but Setup lacked a discoverable button. Add **Park Map** to the permanent Setup header for all Setup readers. Open `locate/` in a separate tab with `noopener` to preserve unfinished Setup work and use the established Setup default layers.

Presentation/navigation correction only: existing map, API, permissions and database behavior are unchanged. Retain V0.3.62-field-networks and Updated 2026-10-10; refresh the changed JavaScript cache pin. No migration, maintenance entry, database dump, or shared Field Wiring promotion belongs to this correction.

Validation: JavaScript syntax check, 33 focused checks, and full Setup/Application regression (751 passed). Exact application candidate: `c1db3e767f56b0346e76b05fd615d6e21e8ccf57`. Production button acceptance remains pending until installed and checked by Greg.

Deploy using the existing Setup source-only runbook and installer, bounded to this exact candidate with live Setup/shared source `6192a1fdf5acb234fd83731b6a8eb73072b7a35d`. Migration 070 already committed successfully; never replay it for this correction.
