# Controller Browser Live Operator UX Acceptance — 2026-09-02

| Item | Value |
|---|---|
| Status | LIVE OPERATOR ACCEPTANCE — CORE DESIGN WORKING; MINOR UX / REPORTING FOLLOW-UP |
| Issue | #110 |
| Production browser | `https://my.sheboyganlights.org/fieldwiring/controllers` |
| Operator context | Administrator |
| Permanent identity | `ref.controller.controller_id` |

## Purpose

Record live operator acceptance findings from the production Controller Inventory browser after protected Controller maintenance became available.

This is not a replacement for the architecture contracts. It records what the actual production screens proved and the remaining small design corrections required before the Controller browser is considered polished and ready for ordinary field use.

## Live experience accepted

The current browser is close to the intended operational design.

Accepted behavior observed in production:

- authenticated identity is visible as `Greg Liebig · Administrator`;
- Controller browse/search remains readable and compact;
- Edit Controller opens a grouped operational form rather than exposing raw table rows;
- human-readable Controller model/status/location choices are used rather than raw foreign-key IDs;
- Controller serial number can be edited and saved successfully;
- Save Controller uses the established blue/PostgreSQL-oriented primary action styling;
- closing an edit form after changing data without saving warns that unsaved changes exist;
- Controller detail continues to expose current Display assignment and `Open Field Wiring` navigation;
- Print Label state remains separated from the normal Controller save operation.

The unsaved-change detection is specifically accepted as good operator protection and should be preserved.

## UI defect — duplicate Add Controller action

The production browse screen currently renders **two Add Controller buttons** side by side below the filter area.

This is a presentation bug. There must be only one Add Controller action for an authorized Manager/Administrator.

Do not hide the duplicate through authorization changes; fix the duplicate render/binding source.

## Display Attached — terminology clarification required

The edit screen currently contains a field labeled:

```text
Display Attached
```

This wording is ambiguous because Controller-to-Display logical assignments are already managed separately through `ref.controller_display`.

The useful physical meaning of this stored fact is:

```text
whether the physical Controller is mounted/attached to a Display and normally travels with that Display
```

It must **not** mean "does this Controller have a current Display assignment?" Assignment state is already governed by the Controller-to-Display relationship model.

Recommended operator wording:

```text
Physically Attached to Display
```

Recommended short help text:

```text
Is this controller physically mounted to or normally stored/moved with a Display? This is separate from Controller-to-Display assignments.
```

Final wording remains subject to operator acceptance, but the logical-assignment meaning is explicitly rejected.

## Field-level help popovers

The live form demonstrates that several fields require short in-context explanations. Add a small `?` help control beside non-obvious field labels rather than adding permanent paragraphs throughout the form.

Interaction requirements:

- hover/focus on desktop;
- click/tap on touch devices;
- keyboard accessible;
- one or two concise sentences;
- help text must explain operator meaning, not database implementation.

Initial fields that should receive contextual help include:

- Physically Attached to Display;
- Physical Verification;
- Programmed Config Verification State;
- Programmed Config Source Note;
- First UID / UID Count / calculated UID range;
- Wiring Source Display in assignment management;
- Label Required;
- Firmware Verification State.

Do not add `?` controls mechanically to every obvious field. Use them where they prevent a realistic operator misunderstanding.

## Print Label action styling

The Print Label button must be visually distinct from the blue **Save Controller** primary database-write action.

It should also not be confused with the blue `Open Field Wiring` navigation action.

Recommended direction:

- dedicated print/action treatment, preferably a non-blue accent plus printer icon/text;
- preserve clear `Print Label` wording;
- pending state must remain visibly different, e.g. `Print Requested`;
- do not rely on color alone for state/meaning.

Exact visual color is a UI implementation detail; the accepted rule is that Print Label is a distinct physical-output action and should not share the Save Controller primary-action treatment.

## Offline / printable field reports required

Controller Inventory needs printable physical reports for field/setup/maintenance work where Internet access may be unavailable or unreliable.

The reports are an operational companion to the live browser, not a replacement for PostgreSQL authority.

Minimum useful report set:

### Controller Firmware / Verification Worksheet

Printable/PDF output should support firmware upgrade and verification rounds. Useful columns/context include:

```text
Controller ID
Model
Stage / Display assignment context
Current recorded firmware
Firmware verification state
Current programmed Network / UID range or management IP
Physical location when known
Serial / hardware revision when useful
blank field for observed firmware / action
blank field for verification date / initials or person
notes
```

The report should be producible before field work and usable without network access.

### Stage / Display Controller List

Printable/PDF report grouped by Stage/Sub-stage or selected Display should provide the physical Controller IDs/models and assignment/programmed-address context needed for setup/troubleshooting.

### Verification / Exception Report

Printable list for controllers needing firmware verification, physical verification, unknown location, unknown serial/hardware facts, or other selected outstanding verification states.

Reports should be generated from current governed Controller Inventory data and clearly show the generation timestamp/current snapshot context so paper copies are not mistaken for permanent authority.

## Overall operator assessment

The current production design is accepted as a strong base. The remaining UX work is predominantly refinement rather than redesign:

```text
core browse                 working
protected identity          working
Edit Controller             working
save/audit path             working
unsaved-change protection   working
FieldWiring navigation      working
Add Controller              present; duplicate-button bug
Print Label                 database request works; physical print path separate
contextual field help       required
print action styling        needs distinction
offline printable reports   required
assignment management       continue acceptance separately
```

Preserve the current grouped form structure and the behavior that warns on unsaved changes. Do not replace the working browser design with a new editing paradigm merely to address these follow-up items.
