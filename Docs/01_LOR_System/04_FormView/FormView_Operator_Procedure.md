# FormView Operator Procedure

| Document control | Value |
|---|---|
| Status | ACTIVE — current V6 production procedure |
| System | FormView |
| Intended user | Wiring/setup technician, programmer, or lead |
| Current application version | 0.3.1 |

## Purpose

Use FormView to view the current Light-O-Rama wiring information for a Stage/Preview, see the related wiring drawings, and export temporary field instructions.

The normal field-wiring workflow is designed to answer:

> Which Display plugs into which controller/channel, on which network, and where is that connection shown on the wiring drawing?

## Important Current Limitation

FormView is currently a **Windows desktop application**.

For normal production use it requires access to the MSB shared `G:` drive because the production SQLite database and Stage wiring images are stored there.

If the `G:` drive is not available, FormView cannot operate normally with current production data.

## Before You Start

Confirm:

1. You are using a Windows computer configured for MSB shared-drive access.
2. Google Drive / the MSB shared drive is available as `G:`.
3. You are connected well enough for the shared-drive files to be available.
4. You know which physical Stage and which Preview type you are wiring.

A complete workstation provisioning/install procedure is maintained separately from this day-to-day operator procedure. Production users should not build FormView from source.

## Start FormView

1. Open `FormViewApp.bat`.
2. Wait for FormView to start.
3. Confirm the database path shown at the top of the Wiring View.

The production launcher checks for:

- the mapped `G:` drive;
- the production database; and
- the canonical FormView executable.

It copies the **application executable** to a local per-user cache and runs that cached executable.

It does **not** currently copy the production SQLite database locally.

## Confirm the Database

For production use, FormView should normally use:

```text
G:\Shared drives\MSB Database\database\lor_output_v6.db
```

The current database path is displayed beside **DB:**.

### Choose DB...

The **Choose DB...** button allows another SQLite database to be selected.

This exists so other parser/database models can be tested without changing FormView first.

Do not use an experimental database for production field wiring unless it has been specifically approved.

### V7 warning

FormView has not yet been operationally validated with the V7 scene-aware SQLite database.

Use the proven V6 production database for current field work until V7 compatibility has been tested and accepted.

## Select the Correct Stage / Preview

Use the **Stage / Preview** picker.

This selection controls both:

- which wiring rows are shown; and
- which wiring-background images are associated with the Stage/Preview.

### Two Stage/Preview contexts matter

Technicians must understand the difference between:

- **Show Background Stage**; and
- **RGB Plus Prop Stage / Musical Stage**.

They are not interchangeable.

If you expect a Display to be at a Stage but cannot find it in the wiring list, first check whether you selected the wrong Stage/Preview type.

This is a common source of confusion in the field.

## Review the Wiring Image

If a wiring diagram has been created for the selected Preview, FormView displays it above the channel table.

The visual drawing shows the physical location of the LOR **Channel Names**. Those names correspond to the Channel Name entries in the table below.

Use the drawing and the table together.

### Image path

The **Image:** field shows the actual wiring-image path being displayed.

### Multiple image pages

Large or dense Stages may have more than one wiring image.

When additional images exist, the Page control becomes useful:

```text
<<   Page X/Y   >>
```

Use the previous/next buttons to move through detail drawings or separate Stage sections.

### Show image

**Show image** is normally enabled.

Uncheck it when using a small tablet or screen and you need more room for the wiring table.

The wiring rows remain available even when the image is hidden.

### Scale

Use the **Scale** slider to make the image smaller or larger.

This is useful for dense Displays with many channels where the labels are difficult to read at the default size.

## Open the Wiring Folder

Use **Open Folder** when you need direct access to the published wiring images for the selected Preview.

FormView opens the folder containing the currently displayed image.

This is useful for reviewing the original drawing or related published images.

Do not move, rename, or add unrelated files to the active wiring-image folder during field use.

## Set the Wiring Filters

The Wiring View has three important checkboxes.

## Field wiring mode

**Normal field setting: CHECKED.**

Leave **Field wiring mode (one lead per display/circuit)** checked when plugging Displays into controllers during setup.

This mode removes much of the internal/shared wiring detail and shows the practical Display-to-circuit connections needed in the field.

A single controller channel may still legitimately show more than one Display when multiple Displays physically share that circuit.

### When would you uncheck it?

Turn Field Wiring mode off only when you specifically need the detailed underlying wiring relationships, such as:

- internal Display wiring;
- controller/panel construction;
- troubleshooting a shared circuit; or
- engineering review.

The full view can become busy quickly because it shows Prop/SubProp and other relationships that are not separate field plugs.

## Displays only

**Displays only** limits the list to master Display/Prop rows.

This can help when a Stage has many controllers and many associated records and you want to quickly see which controllers are associated with which Displays.

This is an optional narrowing tool, not the normal substitute for Field Wiring mode.

## Hide SPAREs

**Normal field setting: CHECKED.**

Hide SPAREs removes unused spare controller/sequencer channels from the list.

Spare plugs are intentionally unused.

> **Do not plug anything into a channel identified as SPARE.**

Uncheck Hide SPAREs only when you intentionally need to review the complete controller/channel inventory.

## Read the Channel Grid

The table is normally sorted by **Controller**, then **Channel**.

The important columns are:

### Controller

The controller UID / Unit Identifier.

Use this to identify the correct physical controller.

### StartChannel

The channel / plug number on that controller.

This is the physical output connection used for the Display/circuit.

### Channel_Name

The LOR Channel Name used in the sequencer.

The wiring drawing uses these channel names to show where the connection belongs physically.

### Display_Name

The physical Display name.

This is important because one controller may operate more than one Display.

### Network

The LOR network the controller must use.

This is an important configuration cross-check.

### Source

Engineering metadata that identifies the underlying relationship, such as a Prop or SubProp.

Normally not important to a technician performing basic field wiring.

### ConnectionType

Engineering metadata used to classify the wiring relationship.

Normally not needed for basic field wiring.

### DeviceType

Device metadata from LOR.

Useful for engineering/troubleshooting, but normally secondary to Controller, Channel, Display, and Network during setup.

### LORTag

Sequencing/programming metadata.

Normally not required for field wiring. It can be useful as a double-check during troubleshooting or programming review.

## Sort the Table

Click a column heading to sort by that column.

Common useful sorts are:

- **Controller** — controller UID first, then channel;
- **StartChannel** — channel number first; and
- **Display_Name** — useful when locating all rows for a particular Display.

For normal setup work, the default Controller → Channel ordering is usually the most useful because it follows the physical controller plugs.

## Refresh

Use **Refresh** if:

- you changed filters;
- the database was updated while FormView was open; or
- you want to reload the current Stage/Preview rows.

If the underlying parser/database was rebuilt, generating a new field document is safer than relying on an old export.

## Export CSV

Use **Export CSV...** when you want the currently displayed Stage/Preview wiring rows in spreadsheet-compatible form.

The CSV reflects the current selection and filters.

For example:

- Field Wiring ON produces the reduced field view;
- Field Wiring OFF produces the more detailed wiring relationships;
- Hide SPAREs changes whether spare rows are included.

CSV is useful for engineering review, analysis, sorting, and troubleshooting.

It is not the normal printed field-wiring instruction.

## Export Printable HTML

Use **Export Printable...** when you need a hard copy or portable wiring document for immediate field work.

The HTML includes:

- the selected Stage/Preview;
- the generation date/time;
- the wiring-image path;
- the current wiring image;
- additional Stage wiring images when available;
- the wiring table;
- the row count; and
- the database path used to generate it.

The printed wiring table is intentionally simplified compared with the full on-screen table.

## Printed Wiring Documents Are Disposable

This rule is important.

FormView printable wiring documents are **convenience copies for immediate setup work**. They are not permanent records.

The HTML displays a warning similar to:

```text
Printed: YYYY-MM-DD HH:MM:SS — Use immediately. Discard if not printed "today".
```

The footer also warns that paper copies expire when a new database build or Preview merge occurs.

### Rules

- Do not laminate a FormView wiring printout.
- Do not save an old printout as the permanent wiring plan.
- Do not reuse last year's or an earlier setup's copy without regenerating it.
- Print a current copy when it is needed.
- Use it during setup.
- Throw it away when the Stage/Display setup is complete.

This prevents Light-O-Rama changes from being defeated by stale field paperwork.

The current LOR data and a freshly generated FormView document are the working source for field wiring.

## If a Display Is Missing

Check these items in order:

1. Confirm the correct physical Stage.
2. Confirm whether you need **Show Background Stage** or **RGB Plus Prop/Musical Stage**.
3. Confirm **Displays only** is not hiding a relationship you need to inspect.
4. If investigating internal/shared wiring, temporarily turn **Field wiring mode** off.
5. Confirm **Hide SPAREs** is not relevant to what you are checking.
6. Press **Refresh**.
7. Confirm the correct database is selected.

If the Display is still missing, stop and treat it as a data/Preview issue rather than guessing a controller connection.

## If the Wiring Image Is Missing

1. Confirm the correct Stage / Preview is selected.
2. Check the Image path shown by FormView.
3. Confirm the `G:` drive is available.
4. Use Open Folder if the path resolves but the expected drawing is not displayed.
5. Confirm the Preview Authoring wiring-background procedure has been followed.

Do not create a new ad-hoc field drawing in the published folder just to make FormView display something. Correct the upstream Preview/wiring-documentation problem.

## Stage View

The **Stage View** tab provides a read-only listing grouped by:

```text
Stage
  -> Preview
      -> Display
```

It also identifies Displays with no wiring.

Stage View can export a printable Stage display listing.

Use it when you need a broader inventory/reference view of what belongs to the Stage rather than individual controller plug instructions.

## Programming View

The **Programming View** tab uses the same Stage / Preview selection concept and lists Props and Groups with their Tags.

This view is primarily useful for programming/reference work rather than field wiring.

It can export CSV or printable HTML.

## Current Production Defaults

For normal field setup, the expected starting state is:

```text
Database:       current approved lor_output_v6.db
Stage/Preview:  correct physical Stage and Preview type
Field wiring:   ON
Displays only:  optional / normally OFF
Hide SPAREs:    ON
Show image:     ON when screen space permits
Sort:           Controller -> Channel
```

## Do Not Guess

If FormView, the selected Preview, the image, and the physical Stage do not agree, stop and verify the upstream information.

Do not choose a controller/channel based on an old printout, memory, or a similar Stage.

The purpose of FormView is to keep field wiring aligned with the current approved LOR data.

## Related Documents

- [FormView Engineering Architecture](FormView_Engineering_Architecture.md)
- [FormView subsystem portal](README.md)
- [Create Wiring Backgrounds for Stage Previews](../01_Preview_Authoring/D_Create_Wiring_Backgrounds..md)
- [FormView application/build README](../../../LOR/FormView/README.md)
