# #171 Network source reconciliation — October 9, 2026

| Document control | Value |
|---|---|
| Status | ENGINEERING CANDIDATE; operator review required |
| Owner | Site Infrastructure / GIS, with Network Infrastructure |
| Main baseline | `86a025a2528be9f7071355965f679320a1362181` |
| Implementation path | Existing PR #318, after `a523b5082dba54ec2fd14567aeb520a5a9813f88` |

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

## Candidate matching rule

Draw.io is operator-established network identity/topology authority; GPX carries
route geometry. GPX description text never assigns network membership.
Case-insensitive literal two-endpoint track names may match the unordered
Waypoint_1/Waypoint_2 pair. Apply only confirmed GG-10 → GG-11 and Aux I/Aux-I
aliases; retain original source strings. Other aliases need review. Cable label
versus structured endpoint disagreement blocks automatic matching.

This produces **11 endpoint-matched GPX routes and 67 unresolved routes**.
Matches are candidate correspondences requiring operator review, not confirmed
surveyed current routes. Candyland reconstruction is particularly unresolved;
older geometry must not be represented as verified reconstructed cable routing.
The cross-reference is a versioned read-only source consumption snapshot, not a
second editable inventory or permanent PostgreSQL business identity store.

Concrete discrepancies include TC-01 TO PN-01 with Waypoint_2 RA-08,
WV-00 to WV-03 Aux I with Waypoint_2 WV-04, and A5-02A to A5-02B AuxN with
Waypoint_1 A5-04. A5 formatting differences (A5-2A/A5-02A, A5-003/A5-03,
slash versus ampersand combined endpoints) also require explicit reconciliation.
No global spelling correction is made.

## Browser behavior

Search includes draw.io network groups plus original reference and asset results.
Selecting a network highlights every rendered segment of all endpoint-matched
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

Test network grouping and inspect conflicting/unmatched endpoint evidence in
PR #318's new exact candidate. Obtain the final corrected tester export before
claiming reconciliation against it; this turn supplied draw.io and SQL only.
PR #319 (`99a2534aa5bea51645de2de6d255b97d89981bb2`) owns existing CableIQ
validation and is not duplicated or replaced. Next integration must reconcile
source identities and design minimal extensions linked to existing Wiring and
reference tables under #171/#230, preserve append-only retests, and obtain normal
disposable/operator acceptance before Production. No database writer, editable
network records, test ingestion or complete topology is delivered by this slice.
