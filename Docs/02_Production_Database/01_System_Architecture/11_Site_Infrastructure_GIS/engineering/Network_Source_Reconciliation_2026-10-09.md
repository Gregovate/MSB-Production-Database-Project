# #171 Network source reconciliation — October 9, 2026

| Document control | Value |
|---|---|
| Status | ENGINEERING CANDIDATE; operator review required |
| Owner | Site Infrastructure / GIS, with Network Infrastructure |
| Main baseline | `38f6f9427007470cbc02b3e2d23a97450d4414ba` |
| Implementation path | Existing PR #318, after `a523b5082dba54ec2fd14567aeb520a5a9813f88` |

## October 10 finding: raw LinkIQ source and consolidation authority

Greg confirmed on 2026-10-10 that the tester cable names identify individual
cables, endpoint to endpoint, including network/spare designation. Draw.io is
hand-entered from these records and should agree; discrepancies must be reported
to Greg with exact object ID, entered values, tester values and proposed correction.
Do not silently rewrite the drawing. The eventual consolidated source of truth is
the PostgreSQL database, with source provenance and reviewed reconciliation.

The supplied `26-10-09-Park-Data.flw` is directly readable SQLite, opened read-only.
Size: 174,149,636 bytes. SHA256:
`75a6b4673c9acf3aa7698fef0617df219a2742aeaebf022daebb7b8a8277b5ef`.
The file reports TesterType=LinkIQ (the conversation previously called it CableIQ).
Tables: Records, RecordData, Admin and 606A. Records contains 470 test rows,
447 distinct literal CableId values, 466 Deleted=NO and four Deleted=YES.
These are record/name counts, not a verified count of physical cables.

Readable fields include CableId, CableIdLong, LengthF, LengthM, TimeSpan,
TestStatus, Deleted, Hash, UUID and TesterType. ResultBrief and RecordData.BinRec
hold binary data; detailed binary results and numeric test-status meanings have
NOT been decoded. Timestamp semantics/timezone still require verification.
A tester timestamp must not automatically become an installation date.
CSV export is unnecessary to access the verified scalar fields. Preserve raw
names and raw values; do not use the zero-padded CableIdLong sorting form as a
human cable name.

Verified source examples (literal CableId and LengthF):

| Tester cable name | Feet |
|---|---:|
| WV 00 to WV 03 AUX-I | 110 |
| WV 04 TO WV-00 | 266 |
| WV-11 TO WV-13 REG | 91 |
| WV-11 TO WV-13 AUX-I | 87 |

The first record supports correcting draw.io object
`Cable_WV-00_WV-03_AuxI` Waypoint_2 from WV-04 to WV-03; report it for Greg's
source correction. The second is a separate tester record and has no explicit
network suffix: do not invent one. The last two prove separately named REG and
AUX-I cables between the same endpoints; shared endpoints are not duplicates.
The draw.io `Cable_WV-11_WV-13_Reg` label/Network conflict still needs
object-to-cable reconciliation before its intended identity is chosen.

Potential stray record: `1000 ft test cat-6 on roll`, 995 feet. Flag it for
operator disposition rather than dropping it. Preserve deleted source records
and repeated test records as evidence; do not automatically import them as active
cables or collapse retests. Identical names alone are not a durable unique key.

Required reconciliation sequence:

1. Reconcile endpoint waypoint identities across tester names, draw.io and GPX,
   retaining original spellings and explicit confirmed aliases. Report missing,
   ambiguous and conflicting identities in either direction.
2. Establish individual cable identity from tester evidence, including endpoints,
   network/spare designation and separate parallel cables. Attach multiple tests
   as history to a reconciled cable; preserve source-file hash and source-row keys.
3. Report draw.io discrepancies with exact source object IDs and both sets of
   values so Greg can correct human entry errors.
4. Link cables to their GPX installation traces and preserve recorded installation
   dates and original geometry/provenance. Greg considers bad traces unlikely;
   inspect naming/matching errors first, without assuming all geometry is perfect.
5. Compare route length in feet with tester-measured cable length to help assess
   waypoint/track alignment. Slack, vertical runs and service loops can differ
   from mapped length; length alone cannot determine a route. Store reviewed
   corrections separately from original recordings and retain EPSG:8158 authority.
6. Consolidate reviewed waypoint/cable/route identities and append-only test
   history in the existing database/Wiring integration, reusing existing IDs.
   The map and schematic should consume reconciled information rather than
   independently assigning network identity.

V0.3.54 is still the earlier draw.io-derived implementation. Its network
assignments are provisional and its automatic dashed "alternative routes"
classification is not supported merely by shared cable-path evidence. Separate
cables may share endpoints/routes. This documentation supersedes that assumption;
the application correction and full three-source reconciliation remain pending.
No raw tester binary has been committed, no source drawing/GPX edited, and no
database import, schema change or Production mutation occurred for this finding.

## Actual source inventory

`Park Network Schematic 2026(8).drawio` SHA256
`e59d67383e735b4bbd77b59f6ec1f6a73dedd1b983d6594a379159d18ace953c`
has 375 object-wrapped edges: 372 structured records with Cable_ID,
Waypoint_1, Waypoint_2 and Network, plus three legacy records. Another 70
bare mxCell edges require review. The earlier object-only extractor omits those
70 edges. Source object IDs and raw attributes are retained in the candidate
cross-reference, including duplicate-looking records; they are not collapsed
into asserted physical cable identities.

The supplied October 9 02:00 compressed SQL has SHA256
`cc2df6a9e1e13045ad05b4b5e75b0341b2a61475b8f4b441833e54c13a243525`.
Read as text without restoration/execution: 155 CREATE TABLE definitions,
PostGIS in public, no dedicated physical cable/network/waypoint mapping/test
history tables. ref.container_endpoint is movement terminology. Reuse existing
controller_id, stage_id, display_id and Wiring consumption paths. lor_network
and management_ip describe controller configuration; they cannot substitute for
physical cable identity. Schema integration/writer/editor remain unimplemented.

## Historical V0.3.54 candidate matching rule — correction pending

V0.3.54 used draw.io as network identity/topology input; this is superseded by
the tester-first authority above. GPX carries route geometry. GPX description text never assigns network membership.
The first V0.3.53 candidate matched only literal two-endpoint track names (11
routes, 67 unresolved). Greg's 23:05 screenshots exposed incomplete AUX-I/INET
highlighting and confusing raw-track versus network search results. That browser
review requires changes; it is not operator acceptance.

V0.3.54 screens existing route geometry against named GPX waypoint positions.
Waypoint names match source endpoint codes directly; literal panel forms such as
PANEL 09 / PANEL-09 and PANEL RA-00 / RA-00 are retained in `waypoint_lookup`.
Confirmed GG-10 → GG-11 and Aux I/Aux-I aliases remain. Original names/attributes
are preserved. Ambiguous duplicate waypoint identities are excluded.

A route segment requires named source endpoints within a 30-ft **screening**
radius and exactly one monotonic draw.io cable-node path for the same network.
Every path node must be within that radius of the original line. All segments of
a multi-segment GPX feature must support the same network before the full feature
can be highlighted. Missing links, conflicting source attributes and multiple
possible node paths remain unresolved. Network identity comes only from draw.io.

Screening uses a local WGS84 distance approximation at park latitude; it does not
transform/persist replacement coordinates. The 30-ft bound is only a candidate
search radius (CC-00 is about 23 ft from the old GPX endpoint). It is not survey
accuracy or a locate/clearance threshold. Existing EPSG:8158 authority and original
browser geometry remain unchanged. These source correspondences require operator
review and must not become accepted current physical topology automatically.

The new source snapshot contains **43 candidate GPX routes, 35 unresolved routes**;
AUX-I has **13 candidate routes and two conflicting cable records**; INET has
**19 candidate routes and 15 records without supported full-route correspondence**.
V0.3.54 highlights GPX features sharing the same source cable-path evidence dashed
as alternatives. That classification is premature and must be corrected; sharing
evidence does not prove that the traces are alternatives.
This is a read-only source consumption snapshot, not a second editable inventory.
Candyland reconstruction still requires geographic validation. A candidate there
does not establish that older route geometry describes the reconstructed cable.

Concrete discrepancies include TC-01 TO PN-01 with Waypoint_2 RA-08,
WV-00 to WV-03 Aux I with Waypoint_2 WV-04, and A5-02A to A5-02B AuxN with
Waypoint_1 A5-04. A5 formatting differences (A5-2A/A5-02A, A5-003/A5-03,
slash versus ampersand combined endpoints) also require explicit reconciliation.
No global spelling correction is made. The AUX-I record
`Cable_WV-00_WV-03_AuxI` cannot resolve the missing WV-00/WV-03 section because its
label/key indicate WV-03 while Waypoint_2 says WV-04. The October 10 tester evidence above identifies the endpoint correction to
report to Greg. `Cable_WV-11_WV-13_Reg` also has a Reg label but Network = Aux I; its
network assignment is held unresolved instead of being counted as a second
confirmed Aux-I cable. Other nonconfirmed Aux spellings are not globally merged.

## Browser behavior

An exact network-name/confirmed-alias query returns the logical network group
only. Thus Aux-I and Aux I each yield one AUX-I result; INET does not also return
Flammables Cabinets. Broader route queries still show **GPX route (source name)**
results. Selecting a raw route or asset clears stale network evidence. Refresh
clears that selection. Network selection opens its evidence without an arbitrary
first-route popup.
Selecting a network highlights every rendered segment of all supported candidate
GPX features, fits their combined bounds, and reveals source cable evidence.
The details list includes unmapped and conflicting records and per-cable Show
cable route buttons. Networks with zero mapped routes remain searchable and
show an explicit unavailable geographic state. Source load failure preserves
ordinary map search. Switching selection or refreshing restores original styles.
No lines bridge missing routes. Common network labels do not assert continuous
physical connectivity. Feet and Speed remain source fields; Speed is not claimed
as throughput, negotiated speed, or a new independently inspected test result.

## Operator-confirmed broader integration facts

Waypoints support multiple infrastructure functions: Outlet Combo includes power
and network; Out Power/LP Power are power-only; some waypoints are network-only.
Lookup should reach shared Wiring/reference records, power circuits, meter and
breaker details, switches/PoE and preserved test history with Show on map.
MSB owns FC-00, ST-00, WW-00, A5-00, CL-00, RA-00, GG-00 and PANEL 42-00;
all remaining park panels are city-owned. MSB pays its eight panels' monthly bills;
city billing was not specified. PANEL 42-00 is GPX w106, type Panel, source comment
“MSB / 2019 New”. Ownership, billing, meter and breaker identity stay separate.
GPX cameras are incomplete; preserve existing entries and defer camera management.

## Resume point

Use the directly readable October 9 LinkIQ file to reconcile waypoint and cable
identities, produce the actionable draw.io discrepancy list, and then correct
PR #318's map matching/classification. The tester source is now available; full
reconciliation and raw-binary decoding have not yet been implemented.
PR #319 (`99a2534aa5bea51645de2de6d255b97d89981bb2`) owns existing CableIQ
validation and is not duplicated or replaced. Next integration must reconcile
source identities and design minimal extensions linked to existing Wiring and
reference tables under #171/#230, preserve append-only retests, and obtain normal
disposable/operator acceptance before Production. No database writer, editable
network records, test ingestion or complete topology is delivered by this slice.
