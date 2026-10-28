# LOR2PC release check and repair design — #299

Status: proposed contract; not implemented or deployed. Updated 2026-10-28.

## Problem and ownership

Programmers have different locally installed runtime checkpoints. Showing the
app version/date identifies them but cannot establish whether they are supported.
#299 owns the LOR2PC release check, installer repair and distribution contract.
#81 remains solely the accepted preview/source publication authority.

## Required behavior

A protected, stable release document must identify the current supported PC
release, minimum supported release, release date, immutable installer URL,
installer SHA-256, source commit and schema version. Version comparison must use
numeric components, never lexical ordering. A pilot must not be advertised to
all programmers as an accepted production release.

The installed app checks the document using the existing authenticated browser
handoff, without copying browser credentials into the local process. The PC
receives bounded release metadata separately from accepted-preview evidence.
Never treat a preview reconciliation Run ID as an application release number.

Display Current, Update available, Update required, or Unable to verify release.
A required update blocks preview apply. An unverified release check also blocks
apply; audit/diagnostics remain available. Optional updates must not silently
rewrite an installation. There must be an explicit Install update action and a
simple first-install/repair entry on the protected LOR2DB PC page.

Download only an immutable allowlisted HTTPS installer, verify its digest before
execution, and require explicit installation. Preserve the working runtime and
shortcut until the new installation verifies. Failed download/hash/install must
leave the prior installation available. Do not install over a running updater
or change preview libraries as part of updating the application.

Publishing release metadata is a separate approved deployment step after native
Windows acceptance, not a side effect of building a ZIP. The release document,
installer and website must be published together from exact committed sources.
A hash retrieved from the same protected service is transport/publication
integrity evidence, not an independent code-signing trust anchor.

## Acceptance tests

- Equal, older, newer and unsupported installed versions; numeric 1.0.9/1.0.10.
- Missing, malformed, unauthorized, expired/unavailable and inconsistent release
  documents block apply without falling back to a guessed supported version.
- Optional vs mandatory updates; pilot is never silently promoted.
- Wrong host/path/hash/commit or interrupted download cannot execute setup.
- Install failure preserves prior runtime/shortcut and all preview bytes.
- Successful per-user repair updates desktop and protocol launchers consistently.
- Actual Windows desktop/browser launches show the new version/date.
- No accepted-source DB change or preview write during release check/install.

Current 1.0.8 implements visible version/date, durable review evidence and a
report-folder action only. It does not yet implement this release contract.
