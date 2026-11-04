# Updater 1.1.3 — per-account version checks and compact approval

Status: source candidate; Windows validation and immutable package/site publication pending. Do not point production downloads at this source until the package and release JSON exist and hashes are pinned.

## Operator changes

Every 1.1.3 launch includes installed version in a cache-versioned browser request. The signed-in browser fetches the current source and fresh downloads/updater-release.json metadata. No browser cookies or credentials are read by native PowerShell. Version evidence is checked before master preview or background image reads. Numeric version comparison, mandatory minimum version, current version, invalid metadata, unapproved installer origin and failed checks have separate decisions. Missing/invalid version evidence stops scanning and offers the approved download page rather than assuming the updater is current.

An update-required dialog shows installed/latest versions and an Install latest updater button. It opens the approved versioned installer ZIP; it does not execute downloads automatically. Setup verifies the installed runtime hash, metadata version and registered browser launch path, and explicitly confirms 1.1.3 installed and verified. Each Windows account needs a one-time install of 1.1.3; existing 1.0.9 binaries cannot gain a native check without that installation. The refreshed browser page warns about legacy launchers that do not report versions.

The release JSON must contain schema_version=1, latest_version, minimum_version, installer_url and installer_sha256. Installer URL is restricted to the exact MSB PC downloads path and versioned filename. Browser cache is bypassed for every release check. The browser receives new handoff.js?v=1.1.3 via the cache-versioned PC page. Catalog schema3 still supports minimum_updater_version=1.1.2 and future numeric minimums; its evidence identity is not changed by the transient updater_release transport field. The native updater never republishes that augmented document.

Approval starts compact: readiness/blockers, update counts and required acknowledgements. Show changes reveals affected previews; full details and revision alignment are opt-in. The catalog webpage similarly puts routine details inside a collapsed disclosure; blockers expand it. Routine verified image paths no longer fill each programmer summary. All source/identity/hash/backup guards and report artifacts remain.

## Focus exception

The startup Shown handler created a timer whose callback referenced a local $form variable after that handler returned. New-FocusReleaseTimer stores the owner on Timer.Tag and stops/releases focus through the event sender. The owner closes/disposes the timer via an explicitly captured closure. Review focus uses the same helper. No preview scheduling or parser timer is affected.

## Validation

Node browser-transport tests pass for fresh release evidence, legacy launches, older reported versions and release-fetch failure. JavaScript syntax checks pass. The unchanged catalog regression suite has 89 passing executions. Test-ProductionEngine.ps1 adds numeric version ordering, mandatory update, missing metadata and installer-origin rejection; it also pumps a disposable native timer after the helper scope returns and exercises compact review/Show changes through a disposable WinForms dialog without approving a preview write.

Windows-native results are not claimed until Greg runs the exact candidate and supplies PASS output. Full installed-package/browser acceptance remains after packaging/site promotion. No production restart, ingest, publication or PC installation is performed by this source change.

## Release order

1. Validate native candidate tests.
2. Build immutable 1.1.3 two-file installer with exact source commit and runtime hashes.
3. Build release JSON with the final ZIP checksum, latest/minimum versions 1.1.3.
4. Install and verify ZIP first, then release JSON, handoff.js, catalog.js, and cache-versioned PC/index pages. Use bounded backups and preserve independently changed files. Never expose a link before the package exists.
5. Install 1.1.3 once on each PC/Windows account used for LOR; confirm setup and runtime version. Check real browser version handoff and compact approval, then approved apply and repeat ADD 0 / REPLACE 0.

Source owner: PR300 / issue299. Current deployed runner policy remains V5 and runner V1.8.0; updater1.1.2 is the last published installer until release receipts establish otherwise.

## Windows validation checkpoint

Greg ran candidate b1edd42d1d384cf7a25fdca9ec69774250cae35c through SSH under Print Service. All comparison, preservation, background, version-gate and focus-timer checks passed. The last modal review test could not execute because that SSH session is not UserInteractive. This is recorded as a GUI acceptance gap, not a passing UI check. The harness now reports that step as SKIP under noninteractive Windows. Test-Updater113-UI.ps1 loads only the real review/timer/count functions and supplies synthetic in-memory rows on a local interactive desktop; it performs no network calls, real preview reads, installation or approved writes. Its result is still pending.
