# Issue 299: routine background updates and legacy comparison recovery

## Root causes confirmed November 1, 2026

The current Master Musical export supplied in LOR-Review-20261101-035013.zip differs from the independently supplied original, after existing presentation exclusions, only in shape ScaleX/ScaleY for TR-MegaTreeRGBBall and TR-MegaTreeRGBTree. These are drawing dimensions, not physical string/channel configuration. V4 excludes only these two additional shape attributes. Other unknown settings, shape structure, prop identity, Comment, wiring, Scene membership and derived Stage ID remain protected.

Stage 07 and Stage 24 production diagnostics show no V3 baseline anchors. Their legacy records retain a full V1 XML contract hash. V4 attempts reconstruction using documented original Scene BackgroundFile links from the production error reports, supporting single/doubled LOR backslashes. A recovered original is accepted ONLY if its complete V1 contract hash matches the immutable registered value. Matching a filename, size, current projection or changed current source is never sufficient. A simultaneous protected-field edit fails this proof.

Successful reconstruction creates an append-only V4 anchor bound to original raw SHA256 and preview UUID. The original legacy contract tree and proof kind are retained. Existing baseline, publications and pointers are never rewritten. Future background exports compare against this anchor, so they do not require another migration. Static V4 anchors for Master Musical, Winter Wonderland and Tunnel are regenerated only from the independently supplied original exports already used in V3.

## Operator behavior

No image edits, moves, restores or deletion. No parser or ingest. No automatic publication. Programmer updater stays 1.1.2. Existing image byte/path checks remain in force; the earlier proposed warning-only policy was not implemented and is unnecessary after Greg corrected the links.

First-time image evidence for unchanged previews is grouped into one registration count, without listing every image as a preview content change. Missing baseline evidence is labelled separately from a protected comparison mismatch.

The bounded Windows deployment runs Preflight-Catalog-Presentation-Policy.py against the real immutable baseline and current exports BEFORE stopping the runner. It reads only; it does not create anchors or call review/publish. All preview identities and contracts must be proven. Failed proof leaves runtime untouched. The subsequent actual catalog review performs the same verified recovery and double source capture, then persists review evidence. Publication is a separate Greg approval.

## Validation

87 unittest executions passed, including exact-original hash recovery, rejection of concurrent prop UUID/Comment/channel/Scene changes, actual Master Musical scale-only comparison, and all prior background/stale-evidence checks. Counts include inherited regression executions, not 87 unique test methods. Native updater code has not changed since Greg's successful 1.1.2 Windows validation.

## Rollout

Run deployment/Update-Catalog-Presentation-Policy.ps1 from the exact candidate commit, using -CandidateCommit for the pinned source. It accepts installed catalog SHA256 f8298dc201c29c1912172e460969283313a3f80014b0c5d3d80815c92496110e and installs e2c6a5d27451ead0431d33e0ce5a474aa02d9ca12ba2cbb94fc1922d337dac00 only after proof. Task, pairing and credentials are preserved; prior module is backed up and restored on deployment failure.

Deploy the companion catalog.js via the bounded static-only release script. Refresh LOR2DB and review; no new preview export is needed merely to install this policy. Do not claim production proof or catalog publication until their operator receipts are supplied.
