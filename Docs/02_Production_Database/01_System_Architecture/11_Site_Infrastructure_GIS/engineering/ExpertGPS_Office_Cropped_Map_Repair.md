# ExpertGPS Office cropped-map calibration correction — #171

Status: source-only candidate; NOT operator-accepted or Production released.
Owner: Site Infrastructure / GIS; controlled by GIS_Symbol_Management.md.
Date: 2026-10-13. Under #122, existing draft PR #378.

## Approved repair boundary

YOGA-GREG is the accepted source for the cropped raster's GPX-facing map georeference. MSB-OFFICE-PC has three registrations; ONLY `2019 Ortho Cropped for GPS Export` is the correction target. The operator previously miscalibrated this exact-raster registration intentionally as a test. Preserve that baseline as recoverable evidence, then correct it at the operator's request.

The other two registered maps MUST NOT change:
- `EvergreenParkCropped`: working Office aerial; source of a separate laptop/Show transfer.
- `2019OrthoEvergreenParktoWorkshop`: separate unaccepted georeference.

Do not edit GPX, raster TIFF, worldfile, Garmin, FLW, PostGIS or Type/GPS Symbol mappings as a side effect.

## Evidence and exact correction

The uploaded YOGA-GREG JSON proposal and all three October 13 Office map capture JSONs prove identical TIFF SHA-256 for the cropped map: `cff28c2ac5bf04c780238171d68295a105b67e1f61ffdb6881916d3510d85174`. Dimensions: 18281 by 9492. Pixel coordinates and Worldfile X/Y points match between Office and laptop.

Office before: Projection Mercator, datum North American 1983 (United States), no Projection\\EPSG. Point01 latitude 1.69910207, longitude 1.87947681. Point02 latitude 1.67765309, longitude 1.92052983.

Expected afterward: National Grid Transverse Mercator, EPSG 103458, same datum. Point01 latitude 43.78198693, longitude -87.74984560. Point02 latitude 43.77550693, longitude -87.73252256. No pixel, worldfile, raster path, dimensions, metadata, or other registration changes.

An existing portable OziExplorer .map file is additional geographic evidence but its WGS84 Latitude/Longitude declaration is not equivalent to the laptop's native EPSG setting. Do not blindly import it as a replacement for native ExpertGPS settings.

## Safety and acceptance

A real Office `reg export HKCU\\Software\\TopoGrafix` backup succeeded and was supplied by the operator. It is located at `%USERPROFILE%\\Documents\\MSB-GIS-171-Backup\\TopoGrafix-Before-Map-Repair.reg`. This is an emergency backup, not a release installer.

Draft `gis_workstation_map_repair.py` performs:
1. Verify current Windows-user Office host and exact identity/hash/baseline, and the other map snapshots.
2. Require ExpertGPS closed; plan preview is read-only.
3. After two explicit GUI confirmations, save a separate exclusively created private native snapshot.
4. Set only the target map Projection, EPSG and the four latitude/longitude strings under the selected HKCU map key.
5. Reread all three map fingerprints and exact seven target values.
6. On failure, restore original values and verify all map fingerprints. Stop and do not reopen ExpertGPS if rollback verification fails.

No automatic deployment, silent rewrite, or full registry import is authorized. **All disposable tests and the actual Office GUI preview must pass before live repair.** After successful readback, operator reopens ExpertGPS for independent map/waypoint alignment acceptance. Only then may the repair be considered field accepted. Record exact SHA and evidence on #171.

## Current checkpoint

Implementation source and guard tests are committed to draft PR #378. CI/Windows field acceptance remains pending; no Office registry correction has yet been performed through this candidate.
