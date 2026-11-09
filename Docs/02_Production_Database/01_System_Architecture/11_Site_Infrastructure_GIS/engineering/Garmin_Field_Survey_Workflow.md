# Garmin GPSMAP 66sr — Field Survey and Device Track Management

| Control | Value |
| --- | --- |
| Owner | Site Infrastructure / GIS, #171 under #122 |
| Status | Operator requirements, October 14 2026; device-button acceptance pending |
| Scope | Garmin device as field collector; ExpertGPS as engineering editor |

## Purpose and authority

The Garmin already has a working park aerial. Its display coordinate-system selection need not be changed. Clean master GPX waypoint names are authoritative field identifiers and must not change to solve icon-display problems. Operator recognition of MSB waypoints through correct Garmin symbols is required; ExpertGPS Type, PC Map Marker, per-waypoint GPS Symbol, stock Garmin symbols and Garmin CustomSymbols artwork are distinct.

## One segment at a time

Stop automatic activity/track recording so the GPSMAP does not accumulate unwanted tracks. For an intentional cable survey, start recording deliberately at the segment, stop at its end and save the individual track. Document and field-verify the specific GPSMAP 66sr controls before calling the button sequence accepted.

Engineering track names use **HV waypoint1 to waypoint2** for 120V electrical routes or **NET waypoint1 to waypoint2** for network routes. Use exact existing waypoint names; unknown endpoint identities require review, not inference.

Garmin collects raw points. ExpertGPS is used to import those raw tracks, trim/split/simplify redundant recorded points, align surveyed geometry to the reference aerial and distinguish field observations from approved engineering corrections. The operator successfully tested copying the master to a working file, importing Garmin data, editing the track and transferring only the reviewed track to the intended master. The original master must not be replaced wholesale by a disposable working copy; #319 reviewed recurring intake remains separate.

## Remove old device tracks

The operator confirms that historical Garmin tracks have ALREADY been consumed and incorporated into the authoritative master GPX. They are redundant on the GPS and obstruct current engineering use. **No additional archival backup of these old Garmin tracks is required.** Remove the old saved tracks from the Garmin using its track-management controls and clear unwanted current recording as appropriate. Before deleting, distinguish historical tracks from any new, unfinished/untransferred survey and confirm the selected cleanup scope. Never delete the device aerial, waypoint collection, custom symbol files, master GPX, or independent reviewed database history. Verify the map and waypoint symbols remain after clearing tracks.

The October 13 ExpertGPS Send-to-GPS transfer was waypoint-only, not a historical track delivery. Continue selecting waypoints only when transferring field reference data to limit Garmin load time.

## Unresolved acceptance

- Garmin Auto Start OFF and manual Start/Stop/Save behavior observed on the actual device.
- Old saved tracks cleared with unrelated map, waypoints and symbols retained.
- Garmin waypoint-symbol fidelity reviewed separately using physical device and supplied CustomSymbols inventory.
- New individual GPX track imported into ExpertGPS, cleaned, named and reconciled through approved #319 controls.
