# MSB Production Database

The logic outlined in this project is for processing the LOR v6.3.10 Pro preview file and provides a comprehensive approach to organizing props, subprops, and displays required to manage a large light show utilizing the Light O Rama sequencing software.

## Background Information

The propClass is designed to sequence a light show but is not friendly to manage the inventory and documentation to set it up. The propClass is very consistent and provides all the information needed by utilizing the comment field to set the key for displays. There could be one prop per display. There could be props with SubProps in a display. there can be shared props on one display. there could be shared props that are on different displays. There can be multiple props on one display, there can be  prop file. since one display can contain multiple props

## Objective

Outline actions needed to process *.lorprev files in a specified folder to extract xml keys found for PreviewClass and PropClass. Parse and data and format prop file to provide the structure necessary to create a one to one link to the between the props table and external displays table. This will be accomplished by utilizing the comment field to assign the display name. We will create separate tables using the keys found in previewsClass and propClass records. All requisite data is in the preview file.

## Goal

Create props table that contains one record per display. Use the subprops and dmx channel tables to store the information needed to setup the displays. This is needed to manage the physical displays we design, build, inventory, and set up the light show.

## Features

- Light O Rama (LOR) v6.3.10 Pro integration for large light show management
- Dynamic updates and customization using exported *.lorprev files
- Reads the prop data and links to a table containing Display information using a sqlite database
- The datafiles are untouched as not to affect the sequencing software.

## Definitions

- **Preview**: A collection of props in a designated stage. This can be a collection of props sequenced to music or a background animation.
- **LOR**: Abbreviation for Light O Rama
- **Stage**: An area set to a theme containing displays that are either background animations or displays sequenced to music (e.g., Elf Choir, Candyland).
- **Prop**: Light O Rama defines a prop as any device that responds to a command sent from the sequencer. This is a very confusing term since most people think a prop is a single physical object.
- **SubProp**: A prop that responds to the same commands as a prop. This must be explicitly assigned in the preview.
- **Channel Name** → `Name` in LOR XML. The label used by the sequencer. Never modified by the parser.
- **Display Name** → `LORComment` in LOR XML. Our inventory/display label. Used for grouping,
- **Display**: A display as a single physical object that we design, build, setup, and inventory. A display can be a single prop or can be a combination of props and/or SubProp.
- **UID**: The hexadecimal number assigned to a controller
- **id**: is the  UUID or "Universally Unique Identifier" assigned to the id of a prop, preview, or subprop by the LOR Software at the time of creation. This number will not change unless the prop is deleted or is imported into a preview where that UUID is shared with a duplicated prop. All duplicated props must be placed into the same preview and re-exported to ensure

## Preview Types (what we build and why)

### 1) Previews for Props *(panel authoring; source of truth)*

Where we design an individual panel/component and set correct **Channel Name** (`Name`) and **Display Name** (`Comment`).  
We then **Export as Props** from here.

**Authoring path**

~~~
G:\Shared drives\MSB Database\UserPreviewStaging\<username>\PreviewsForProps\
~~~

---

### 2) Master Previews *(sequencing targets)*

Where we **import props** and do the actual sequencing.

- **RGB Plus Prop Stage `xx`** — primary sequencing canvas per stage  
- **Show Background Stage `yy`** — background/static elements per stage  
- **Show Animation `zz`** — shared/global animation elements

> When we import exported props into these masters, the **RawPropID** is preserved, but the original **PreviewID** is not. That’s OK—our checks use **RawPropID**.

---

### 3) Staged Previews *(for the database build)*

The curated set of previews the parser consumes to build the database (v6).  
These copies are produced by the **preview_merger** (do **not** copy into this folder by hand).

**Staging path**

~~~
G:\Shared drives\MSB Database\Database Previews\
~~~

**Typical contents**

~~~
G:\Shared drives\MSB Database\
  Database\
    lor_output_v6.db
    master_musical_preview_keys.csv        (optional: last-year snapshot for drift checks)
  Database Previews\                        <-- Staged previews used to build the DB
    RGB Plus Prop Stage 01 ....lorprev
    Show Background Stage 07 ....lorprev
    Show Animation 03 ....lorprev
  UserPreviewStaging\
    <username>\
      PreviewsForProps\                     <-- Panel authoring previews (export to props)
        1st Panel Animation - <Panel>.lorprev
        1st Panel Animation - <Another>.lorprev
~~~

## Authoring → Build Master → Validate & Stage → Parse (the workflow)

> **Rule of thumb**
>
> - All editing/exports happen in your **UserPreviewStaging** area.  
> - The **preview_merger** is the only tool that copies validated previews into **Database Previews** (staging).  
> - The **parser** reads **only** from **Database Previews**.

### 1) Author the panel preview (*Previews for Props*)

- Work in:`G:\Shared drives\MSB Database\UserPreviewStaging\<username>\PreviewsForProps\`
- Set **Channel Name** = LOR **`Name`** (sequencer label)  
- Set **Display Name** = LOR **`Comment`** (inventory/display label)  
- Save your `.lorprev`.  
- **Export the panel preview as a prop** (LOR “Export as Props”).

### 2) Create/Edit a Master Preview for sequencing

- Choose one of the three masters and **import the prop** you just exported:
  - **RGB Plus Prop Stage `xx`** — primary sequencing canvas  
  - **Show Background Stage `yy`** — background/static elements  
  - **Show Animation `zz`** — shared/global animation elements
- Continue editing until the master preview looks correct in LOR.
- Keep these master `.lorprev` files under your `UserPreviewStaging\<username>` area (**do not** place them in the staging folder manually).

### 3) Validate with the preview_merger (*produces the staged copies*)

- Run the merger against your `UserPreviewStaging\<username>` previews (both **panel authoring previews** and the **master previews** you edited).
- The merger fixes/flags issues (blank comments, duplicates, formatting) and **writes validated copies** into:  
  `G:\Shared drives\MSB Database\Database Previews\` ← *staging for the parser*  
- You **never** copy files into **Database Previews** by hand.

### 4) Parse staged previews to build/update the DB

- From VS Code, run `parse_props_v6.py` (see **[DEBUG Guide](./debug.md)**).  
- Output: `lor_output_v6.db` (SQLite), with views:
  - `preview_wiring_map_v6`
  - `preview_wiring_sorted_v6` *(used by `formview.py`)*

### (Optional) Breaking-change / drift check

- Keep `master_musical_preview_keys.csv` (last year’s snapshot) with:  
  **RawPropID, ChannelName, DisplayName, ChannelGrid_SHA256**
- Compare snapshot vs current DB by **RawPropID** to flag:  
  **Missing_Now / ChannelName_Changed / DisplayName_Changed / Grid change**.

## Developer Quick Links

- [DEBUG Guide](./debug.md) — step-by-step instructions for running the parsers in VS Code,
  required Python setup, **previews folder location**, and troubleshooting tips.

## Documentation References

## Docs (start here)

- [Operator Quickstart](docs/quickstart_operator.md)
- [Preview Merger — Reference](docs/preview_merger_reference.md)
- [Reporting & History](docs/reporting_history.md)
- Archived docs live in [/archive/docs](archive/docs/)
- 📝 [CHANGELOG](CHANGELOG.md) — curated list of processing and schema changes by date.
- 📘 [Naming Conventions](naming_conventions.md)  
  Explains both **Channel Naming Conventions** (LOR sequencing) and **Prop/Display Naming Conventions** (labels, inventory, database).
- 🗄️ [Database Cheat Sheet](database_cheatsheet.md)  
  Quick SQL reference for querying `lor_output_v6.db`, including how to list controllers, find DeviceType=None props, and detect spare channels.

### **Processing Logic Summary**

- [Procesing Rules](ProcessingRules.md)

### **Additional Notes**

- **Fancy Queries or Joins**:
  - When reassembling data for setup, consider using server-side logic (e.g., SQL JOINs or stored procedures) to simplify retrieval based on the linked tables (`props`, `subprops`, `dmxchannels`, etc.).

- **Terminology Updates**:
  - `propbuildInfo` → `Display` table: Links `DisplayName` to `LORComment`.
  - `Fixtures` → `subprops` table.

Let me know if you'd like me to refine the explanation further or help troubleshoot the script!

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/username/repo-name.git
   ```

2. Navigate to the project directory:

   ```bash
   cd repo-name
   ```

3. Install dependencies:
   - Python is required on required on the machine you are running this script.
   - SQLite browser required to open the database created.

## Usage

  1. Create a folder to store the exported previews you want to include for processing. If you want to include all previews, just use the ImportExport folder under your Light O Rama installation.

  2. Using the Light O Rama Sequencing Software, Navigate to the Preview Panel and Right Click in the preview or previews you want to include in the database and save them to the folder of your choice.

  3. Open a Terminal Window and run the parse_props_vx.py script. When prompted, enter the path to the folder containing the preview(s) you want to process.

  4. The location for the database is currently hard coded at the top of the script. This can be changed to put the database in the location of your choosing.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-name`).
3. Commit your changes (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature-name`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgments
