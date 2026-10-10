# #171 Network source reconciliation — October 9, 2026

| Document control | Value |
|---|---|
| Status | ENGINEERING CANDIDATE; operator review required |
| Owner | Site Infrastructure / GIS, with Network Infrastructure |
| Main baseline | `38f6f9427007470cbc02b3e2d23a97450d4414ba` |
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
GPX features sharing the same source cable-path evidence are alternatives and
highlight dashed; neither is silently chosen as the current surveyed route.
This is a read-only source consumption snapshot, not a second editable inventory.
Candyland reconstruction still requires geographic validation. A candidate there
does not establish that older route geometry describes the reconstructed cable.

Concrete discrepancies include TC-01 TO PN-01 with Waypoint_2 RA-08,
WV-00 to WV-03 Aux I with Waypoint_2 WV-04, and A5-02A to A5-02B AuxN with
Waypoint_1 A5-04. A5 formatting differences (A5-2A/A5-02A, A5-003/A5-03,
slash versus ampersand combined endpoints) also require explicit reconciliation.
No global spelling correction is made. The AUX-I record
`Cable_WV-00_WV-03_AuxI` cannot resolve the missing WV-00/WV-03 section because its
label/key indicate WV-03 while Waypoint_2 says WV-04. Greg must resolve that source
conflict. `Cable_WV-11_WV-13_Reg` also has a Reg label but Network = Aux I; its
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

Test network grouping and inspect conflicting/unmatched endpoint evidence in
PR #318's new exact candidate. Obtain the final corrected tester export before
claiming reconciliation against it; this turn supplied draw.io and SQL only.
PR #319 (`99a2534aa5bea51645de2de6d255b97d89981bb2`) owns existing CableIQ
validation and is not duplicated or replaced. Next integration must reconcile
source identities and design minimal extensions linked to existing Wiring and
reference tables under #171/#230, preserve append-only retests, and obtain normal
disposable/operator acceptance before Production. No database writer, editable
network records, test ingestion or complete topology is delivered by this slice.
