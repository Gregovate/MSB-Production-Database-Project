# Naming Conventions Updated 25-08-26

# Naming Conventions

We maintain **two distinct naming conventions** that must be followed consistently:

1. **Channel Naming Conventions** (used in LOR sequencing)
2. **Prop/Display Naming Conventions** (used for physical panels, database, and labels)

---

## 1. Channel Naming Conventions

The sequencing program sorts channels alphabetically. Therefore, it is imperative that props have **channel naming conventions** so they stay grouped in a predictable order in the preview. This is especially important for props with motion, where the order of channels must match the intended motion.

**Format:**

```
LL UID-Channel Name
```

- **LL** → Character abbreviation of the display or stage  
- **UID** → Assigned to the controller used  
- **Channel** → The channel/port of the controller  
- **Name** → A brief description of the channel name  

**Example:**  

![Elf Patterns](Docs/images/ElfChoir.png)
```
EC01-ArmLeft
EC01-ArmRight
EC01-Head
```

⚠️ **Note:** If the UID or channel of a prop changes, the preview and all labeling must be updated. This has historically caused issues when UIDs were reassigned.

---

## 2. Prop/Display Naming Conventions

Every display we build, set up, maintain, and store must have a **unique identifier**. This identifier:

- Appears on the physical label attached to the display.  
- Is duplicated in the **Comment** field within the LOR sequencing software.  
- Ensures every channel associated with a display can be traced back to the correct physical panel.  

### 2.1 Displays and Device Types

A **Display** is the complete physical panel or structure (e.g., Conductor, Elf, Note, Arch, Star).  
Every display is assigned a **Device Type** in the Preview, which determines how it is handled in the database.

**Device Types:**

> **Terminology note:** In the LOR Sequencing UI this appears as **Undetermined**.  
> In our parser and the SQLite database we record this as **DeviceType="None"**.

- **LOR**  
  - Props with channel grids assigned to LOR controllers.  
  - Master = lowest StartChannel, other legs become generated sub-props.  

- **DMX**  
  - Props controlled by DMX universes.  
  - Master metadata goes into `props`, each universe leg goes into `dmxChannels`.  

- **None** *(shown as **Undetermined** in the LOR UI)*  
  - Physical-only props with no channels (e.g., FTString-01R, cutouts, scenery).  
  - Stored in `props` with DeviceType="None".  
  - `MaxChannels` can act as a multiplier (e.g., 16 strings).  
  - Excluded from wiring views but included in inventory/labels.  

---

### 2.2 Sub-Props

There are **two kinds of sub-props** we must distinguish:

#### Generated Sub-Props (Database / Parser)
- Created when a single physical display has multiple channels.  
- Generated automatically by the parser.  
- Always belong to one display and share its Display Name.  

**Example:** `ElfConductor` → ArmLeft, ArmRight, Head, Hat.  

#### Manual Sub-Props (Sequencing Software)
- Created inside the LOR sequencing software by selecting **"Uses same channel as"**.  
- Can span across multiple displays (aliases).  
- Do not create new physical channels; they reference existing ones.  

**Example:** A `HandWave` manual sub-prop may use the same channel as both `Elf-ArmLeft` and `Elf-ArmRight`.

---

### 2.3 Single-Channel Displays

Some displays are a single channel (one lighting element). Each must have a unique identifier.

**Examples:**  

- **Elves (32 total, 4 patterns):**  
  - Pattern 1: `Elf-P1-1` … `Elf-P1-8`  
  - Pattern 2: `Elf-P2-1` … `Elf-P2-8`  
  - Pattern 3: `Elf-P3-1` … `Elf-P3-8`  
  - Pattern 4: `Elf-P4-1` … `Elf-P4-8`  

- **Notes (8 total, 4 patterns):**  
  - `Note-A-1`, `Note-A-2`  
  - `Note-B-1`, `Note-B-2`  
  - `Note-C-1`, `Note-C-2`  
  - `Note-D-1`, `Note-D-2`  

### 2.3 Multi-Channel Displays

Some displays include multiple channels but remain a single physical panel. The display name is the same for every channel.

**Example:**  
- Display = `Conductor`  
- Sub-props = Arm Left, Arm Right, Head, Hat …  
- All channels use the name `Conductor`  

### 2.4 Naming Format

```
<DisplayName>-<Variation>-<Sequence>-<Color>
```

- **DisplayName** → CamelCase (no spaces). Examples: `Elf`, `Note`, `CandyCane`, `MiniTree`.  
- **Variations** → Optional. Defines differences between props:  
  - **Location:** `DS`, `PS`, `LH`, `RH`, `Front`, `Rear`, `A/B/C`  
  - **Pattern:** `P1`, `P2`, `A`, `B` …  
  - **Section:** `A`, `B`, `C` …  
- **Sequence*** → The instance number (for duplicates) of that variation.  
  - If fewer than 10 → single digit (`1, 2, 3, …`). Must guarantee there will NEVER be more than 9.  
  - If 10 or more → pad with leading zero (`01, 02, …, 10, 11, …`).  
  - ⚠️ *Do not use Sequence if Device Type is `None` (shown as **Undetermined** in the LOR UI). In that case, quantity is managed by **Max Circuits per Unit ID** instead.*  

- **Color** → Optional.  
  - Preferred: single-letter suffix appended to the sequence (`R`, `G`, `B`, `W`, `Y`).  
  - Alternate: full color names (e.g., `-Red`).

**Examples:**  
- Pattern-based: `Elf-P2-6`, `Note-B-1`  
- Color-based: `Star-Red-1`, `MiniTree-Green-4`  
- Location-based: `Arch-DS-1`, `Arch-PS-1`  
- Single-panel: `ElfConductor`  
- Stage/Section: `DF_A_DS-01R`  
- Handed props: `SledPoof-LH-04`  

### 2.5 Display Type = None

Some props do not have channels (DeviceType="None").

![FTString Example](Docs/images/DisplayTypeNone.png)

- **Purpose:** Exists in Preview for setup, labeling, and inventory; no channel mapping.  
- **Examples:** `FTString-01R`, static cutouts, scenery.  
- **Database Handling:**  
  - Still follow the naming convention.  
  - `MaxChannels` may act as a multiplier (e.g., 16 strings).  
  - Stored in `props` with metadata (Name, Comment, Lights).  

### 2.6 Inventory Data

Each display panel also has attributes stored in the Inventory Table (not the channel DB):

- Designer  
- Year Built  
- Number of Lights  
- Number of Amps  
- Other metadata  

### 2.7 Optional Identifiers

Prefixes like `EC` (Elf Choir) can indicate grouping/location, but are not required.

---

✅ By maintaining **both channel and display naming conventions**, we ensure consistency across:
- Physical assets (labels)  
- LOR software (comments)  
- Database (props, inventory, wiring)  
