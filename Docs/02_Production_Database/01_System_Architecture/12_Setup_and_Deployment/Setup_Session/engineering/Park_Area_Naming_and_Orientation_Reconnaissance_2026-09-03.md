# Park Area Naming and Orientation Reconnaissance — 2026-09-03

| Document control | Value |
|---|---|
| Status | CURRENT ENGINEERING RECONNAISSANCE — terminology/orientation problem documented; implementation not yet approved |
| System | Setup Session |
| Parent system | Setup and Deployment |
| GIS dependency | Site Infrastructure / GIS |
| Owner | MSB Technical Team |
| Related issue | [#122 — Engineer annual Setup Session planning, pick-list, movement, and park-location subsystem](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122) |

## Purpose

Preserve the operational finding that MSB Setup currently depends on several overlapping location vocabularies that are understood through tribal knowledge rather than controlled system guidance.

This is not only a usability concern. Current field knowledge is concentrated in one individual who can recite the crosswalk between MSB Stage names, newer Scene names, park rental-area numbers, landmarks, and real physical geography from memory. That creates an operational single point of failure.

The durable requirement is therefore:

> Another volunteer or city/park collaborator must be able to orient themselves and translate between the relevant location vocabularies without depending on one experienced person being present.

This document records the problem and field examples. It does **not** approve a new schema, rename existing identities, or decide that Stage, Scene, rental area, GPS point, or another geography becomes the single park-location authority.

## Why the current Stage GPS dataset is Stage-level

The current `2026_Stage_GPS.csv` intentionally uses **Stage/setup-area** reference points rather than Scene-level points.

That is useful because Stage names are the established broad operational language already used by the team, for example:

- Food Collection;
- Icicle Tunnel;
- Candyland;
- Festive Trees;
- Post Office;
- Sledders;
- Santa's Workshop;
- Church.

The Stage-level dataset helps answer the tribal-knowledge question:

> Where in the park is this named Setup area?

It does not need to answer every finer placement question inside the Stage.

## Scene-level location may become useful, but Scenes are new

Scenes are new this year and are already causing some confusion within the team.

Scene-level location guidance could become useful where:

- a Stage is physically large;
- several distinct Setup jobs happen inside one Stage;
- a particular Display group is easier to locate by Scene than by one broad Stage point;
- long or overlapping Stages need finer orientation.

However, Scene terminology must not become a prerequisite for basic park orientation.

If Scene-aware guidance is added later, the parent Stage should remain visible so the operator can understand both levels:

```text
Stage
    -> established broad Setup area
        -> optional Scene-level refinement
```

Do not replace Stage orientation with Scene terminology merely because Scene data now exists.

## Independent location vocabularies

Current reconnaissance identifies at least three distinct naming systems.

### 1. MSB Stage

The Production Database Stage identity is the established MSB operational grouping used for broad planning, procedures, display organization, and park orientation.

### 2. MSB Scene

Scene is a newer, finer-grained show/setup grouping inside the MSB production model.

Scenes may eventually improve precision, but they are not equivalent to park rental areas and should not be presented as a replacement for Stage identity.

### 3. City / park rental area

The park has its own numbered rental-area system.

Those numbers were created for park/rental administration, not MSB show topology. Their numbering does not align with MSB Stage numbers and one rental area may cover several MSB Stages.

Therefore:

> A city/park rental-area number is an external geographic/reference layer, not an MSB Stage key and not an MSB Scene key.

Do not infer relationships from matching or similar numbers.

## Two operational languages and a required translation layer

Field-process clarification established that MSB and the city effectively speak **different location languages**.

Inside the MSB organization, the normal vocabulary is the MSB production system:

```text
Stage
Scene
Display
Setup-area names
```

When communicating with city/park staff, the normal vocabulary is the park's rental-area system:

```text
Area 1
Area 3
Area 4
Area 5
Area 6
```

Neither vocabulary should replace the other. They serve different organizations and different operational purposes.

The current problem is that the translation between them is largely tribal knowledge held by one person. The long-term system therefore needs a **crosswalk/translation layer**, not a forced renaming or merger of the two systems.

Conceptually:

```text
MSB language
    Stage / Scene / Display context
        <-> explicit translation/crosswalk
            <-> city/park rental-area language
```

That translation may be one-to-many or many-to-one. For example, one city rental area can contain several distinct MSB Stages.

The same principle should apply to operator-facing guidance: when useful, the system should be able to show both vocabularies together without implying they are the same identity.

## Field-described rental-area examples

During 2026-09-03 reconnaissance, the current park rental-area relationship was described approximately as follows:

- **Park Rental Area 4** — Food Collection;
- **Area 4 bathroom** — corresponds operationally to MSB `06 - Post Office`;
- **Park Rental Area 3** — described during discussion as roughly associated with `07a` / the nearby Food Collection-related area; exact MSB identity still requires reconciliation before controlled mapping;
- **Park Rental Area 6** — covers MSB `11 - Sledders` and `12 - Stacies Island`;
- **Park Rental Area 5** — Church;
- **Park Rental Area 1** — spans Santa's Workshop, Candyland, Dancing Forest, and Command Center.

These are field-process observations, not approved database mappings.

## Why the rental-area numbering is dangerous in operator UI

The same small integers appear in multiple systems while meaning different things.

A volunteer hearing `Area 4` may mean a city rental area, while `Stage 04` is an MSB identity. Even when they overlap geographically, that coincidence must not become a general inference rule.

Likewise, one rental area can span several distinct MSB work areas. A future UI should therefore qualify terminology where ambiguity is possible, for example:

```text
MSB Stage 06 — Post Office
Park Rental Area 4 — bathroom area
```

Exact UI wording is not approved. The requirement is to avoid bare numbers or ambiguous `Area` labels that depend on tribal knowledge.

## Orientation requirement

A new or occasional volunteer should eventually be able to answer questions such as:

- Where is Icicle Tunnel?
- Where is Candyland?
- Where are Festive Trees?
- Where is Whoville?
- Where is the Church relative to the main park?
- Which side of the river should this delivery use?
- What broad MSB Stage am I in?
- If a Scene name is shown, what Stage is it part of?
- If someone refers to a park rental-area number, which MSB work areas does that approximately cover?
- If city staff says `Area 1`, which MSB Stages/setup areas are they talking about?
- If an MSB volunteer says `Candyland`, what city/park area should be used when communicating externally?

A particularly representative field instruction is:

> `Take this to Whoville.`

That instruction is meaningful inside MSB but not to a general public mapping/search service. `Whoville`, `Candyland`, `Icicle Tunnel`, and many other names are MSB-local operational place names. A volunteer cannot reasonably be expected to Google those names and discover the correct destination.

Therefore the system should eventually provide a discoverable answer to:

> `Show me where Whoville is.`

The exact implementation remains open. It may be a map, Stage reference point, landmark/access description, current-position view, or another task-focused aid. The requirement is that MSB-local place names become self-explaining inside the MSB system rather than depending on someone already knowing the park layout.

The system does not need to solve all of those with automatic GPS logic.

The durable requirement is to make this knowledge discoverable from controlled data/documentation rather than from one person's memory.

## Candidate future guidance — not decided

Possible aids include one or more of:

- Stage reference points from the current Stage GPS dataset;
- a simple park overview map labeled with MSB Stage names;
- optional Scene labels beneath their parent Stage;
- city/rental-area overlays as secondary context;
- landmark/access notes;
- current-device location;
- `Show me where this is` or `Show me where this goes` task-focused navigation;
- multiple anchors or richer geometry for long areas where later field use proves necessary.

None of these is approved by this document.

## Data-model constraints for later engineering

Any later park-location model should preserve these distinctions:

```text
MSB Stage identity
    != MSB Scene identity
    != city/park rental-area identity
    != raw GPS coordinate
```

Relationships between them may be useful, but they must be explicit relationships rather than number/name inference.

In particular:

- do not map rental-area numbers to Stage numbers by numeric similarity;
- do not assume one rental area contains exactly one Stage;
- do not assume one Stage fits inside exactly one rental area without field evidence;
- do not force Scene adoption into orientation workflows merely because Scene is available;
- preserve the parent Stage when Scene-level guidance is introduced;
- do not rely on one person's memory as the operational crosswalk;
- preserve both the internal MSB vocabulary and the external city/park vocabulary when building a future crosswalk.

## 2026 MVP significance

The Stage-level GPS dataset is enough to provide a useful first orientation layer without solving Scene-level GIS.

For the current two-week Setup Session window, the system can remain Stage-centric while preserving the fact that finer Scene-level orientation may become useful later.

The external rental-area system should be documented/recognizable where it helps communication with city or park staff, but it should not control MSB Setup planning.

## Scenarios any later design should handle

- a new volunteer receiving `Take this to Whoville` can discover where Whoville is from the MSB system without asking the one experienced person who knows the park layout;
- a new volunteer can locate Candyland from the MSB system without knowing the city rental-area numbering;
- a volunteer hearing `Area 1` can distinguish that park term from any MSB Stage number;
- Santa's Workshop, Candyland, Dancing Forest, and Command Center remain distinct MSB work areas even though Park Rental Area 1 spans them;
- Sledders and Stacies Island remain distinct MSB Stages even though Park Rental Area 6 covers both;
- a new Scene name can be shown together with its parent Stage so team members are not forced to infer the relationship;
- Church-side access remains understandable even when a map/rental-area reference is unfamiliar;
- city/park communication can use rental-area terminology while the MSB team continues using Stage/Scene terminology internally;
- operational orientation remains usable even when the one person who currently knows the complete crosswalk is unavailable.

## Related documents

- [Setup Session Engineering Reconnaissance — 2026-09-03](Setup_Session_Engineering_Reconnaissance_2026-09-03.md)
- [Park Placement Candidate Selection Reconnaissance — 2026-09-03](Park_Placement_Candidate_Selection_Reconnaissance_2026-09-03.md)
- [Stage GPS Reference Data Reconnaissance — 2026-09-03](../../../11_Site_Infrastructure_GIS/Stage_GPS_Reference_Data_Reconnaissance_2026-09-03.md)
- [Setup Session subsystem](../README.md)
- [#122 — Setup Session engineering issue](https://github.com/Gregovate/MSB-Production-Database-Project/issues/122)
