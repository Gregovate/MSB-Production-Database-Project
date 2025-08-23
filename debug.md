# DEBUG Guide – MSB Production Database Project

---

## Previews Location (Team Standard)
**Last Updated:** 2025-08-23
### Quick PowerShell Example (Run from VS Code Terminal)
```powershell
# Run V6 parser with Previews folder
python parse_props_v6.py
# When prompted, enter:
G:\Shared drives\MSB Database\Database Previews

# Run V7 parser with Previews folder
python parse_props_v7.py
# When prompted, enter:
G:\Shared drives\MSB Database\Database Previews
```


All `.lorprev` preview files are stored in the **Google Workspace Shared Drive**:

```
G:\Shared drives\MSB Database\Database Previews
```

When running any parser (`parse_props_v5.py`, `parse_props_v6.py`, or `parse_props_v7.py`) and prompted for the folder path, always enter the above path.

> Do **not** copy these files into the repository. They remain on Google Drive and are ignored by GitHub.



**Last Updated:** 2025-08-23

This document provides debugging tips, queries, and sanity checks for the
**LOR Props Parsing → SQLite Wiring Views** pipeline.

---

## 0. Repository Usage & Running the Parsers

### Prerequisites
- **Python 3.9+** installed on your system.
- Install [VSCode](https://code.visualstudio.com/).
- Install the VSCode **Python extension**.
- Clone this repository locally.

### Running Scripts in VSCode
1. Open VSCode and load the repository folder (`File → Open Folder...`).
2. In the VSCode terminal (`Ctrl+`` or `View → Terminal`), create and activate a virtual environment (optional but recommended):
   ```bash
   python -m venv .venv
   # Windows
   .venv\Scripts\activate
   # macOS/Linux
   source .venv/bin/activate
   ```
3. Install dependencies (currently only `sqlite3` is required and comes with Python).
4. Run a parser script from the terminal:
   ```bash
   python parse_props_v7.py
   ```
5. When prompted, enter the path to the folder containing your `.lorprev` files.
6. The script will generate a database (e.g., `lor_output_v7.db`) in the `database/` folder defined in each script.

### Notes
- Use **V5.x** scripts for earliest schema tests.
- Use **V6** if you need integer keys (MS Access compatibility).
- Use **V7** for the cleanest, most current schema.

---

## 1. Check Schema Integrity
After running any parser (V5/V6/V7), confirm tables exist:

```sql
SELECT name FROM sqlite_master WHERE type='table';
```

Expected:
- `previews`
- `props`
- `subProps`
- `dmxChannels`
- (`duplicateProps` in V5.2+ / V7)

---

## 2. Basic Counts
Quick sanity check of record counts after processing `.lorprev` files:

```sql
SELECT COUNT(*) FROM previews;
SELECT COUNT(*) FROM props;
SELECT COUNT(*) FROM subProps;
SELECT COUNT(*) FROM dmxChannels;
```

---

## 3. Verify Wiring Data Exists
Test a known display (replace with real LOR Comment):

```sql
SELECT Name, LORComment, Network, UID, StartChannel, EndChannel
FROM props
WHERE LORComment = 'Fred Star -1-16';
```

---

## 4. Check SubProps Logic
See how props with multiple grids or shared channels were materialized:

```sql
SELECT * FROM subProps
WHERE LORComment = 'Fred Star -1-16'
ORDER BY StartChannel;
```

---

## 5. Wiring Map Views
If you created `v_wiring_map_v7` (or `v_wiring_map_v6`), test:

```sql
SELECT * FROM v_wiring_map_v7
WHERE display_key = 'Fred Star -1-16'
ORDER BY start_channel;
```

---

## 6. Conflict Detection
Detect overlapping wiring (same Network/Controller/Channel reused):

```sql
SELECT network, controller, start_channel,
       COUNT(*) AS hits,
       GROUP_CONCAT(display_key, ' | ') AS displays
FROM v_wiring_map_v7
GROUP BY network, controller, start_channel
HAVING COUNT(*) > 1;
```

---

## 7. Inventory Join
Check external inventory link (if `inventory_displays` exists):

```sql
SELECT wm.display_key, wm.network, wm.controller, wm.start_channel,
       i.inventory_id, i.location, i.status
FROM v_wiring_map_v7 wm
LEFT JOIN inventory_displays i
       ON i.display_name = wm.display_key
WHERE wm.display_key = 'Fred Star -1-16';
```

---

## 8. Debug Flags in Parsers
- All parsers (V5–V7) define `DEBUG = False`.
- Switch to `True` to get console messages:
  - `[DEBUG] Inserted Master Prop ...`
  - `[DEBUG] Inserted SubProp ...`
  - `[INFO] Logged duplicate PropID ...` (in V5.2+)

---

### Tips
- Start with props that have **unique `LORComment` + single grid**.
- Progress to **multi-grid** and **DMX** once the basics check out.
- Keep `inventory_displays.display_name` **identical** to `LORComment` for easy joins.

---

## 0. Repository & VS Code Quick Start
**Last Updated:** 2025-08-23

### Prereqs
- **Python 3.10–3.12** installed and on your PATH (`python --version` should work in a fresh terminal).
- **VS Code** with the **Python** extension.
- Optional: a SQLite browser (e.g., DB Browser for SQLite) for inspecting `.db` files.

### 0.1 Clone / Update Repository
```bash
# First time
git clone https://github.com/Gregovate/MSB-Production-Database-Project.git
cd MSB-Production-Database-Project

# Later, to update
git pull
```

### 0.2 Create & Activate a Virtual Environment (recommended)
```bash
# Windows (PowerShell)
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# macOS / Linux (bash/zsh)
python3 -m venv .venv
source .venv/bin/activate
```

> If `python` resolves to Python 2 on your system, use `python3` instead.

### 0.3 Install Dependencies
If a `requirements.txt` exists:
```bash
pip install -r requirements.txt
```
If not, the standard library is usually enough for the parsers (xml, sqlite3).

### 0.4 Open in VS Code
- `code .` (from the repo folder), or open via VS Code GUI.
- Select the **Python Interpreter**: press **Ctrl/Cmd+Shift+P** → *Python: Select Interpreter* → choose `.venv` if created.
- Open an **integrated terminal** in VS Code (Ctrl/Cmd+`).

### 0.5 Configure Output Paths (Important)
The parsers write to specific `DB_FILE` paths at the top of each script. Examples:
- V5: `lor_output_v5.db`
- V6: `G:\\Shared drives\\MSB Database\\database\\lor_output_v6.db`
- V7: (similar pattern)

> **Edit `DB_FILE`** to a valid path on your machine (e.g., `./database/lor_output_v6.db`). Create the folder if it doesn't exist.

### 0.6 Run the Parsers in VS Code Terminal
Each script prompts for a folder containing `.lorprev` files.

```bash
# Example: run V6
python parse_props_v6.py
# When prompted: enter an absolute or relative path to the folder with .lorprev files
# e.g., C:\Shows\Previews  or  ./sample_previews
```

Repeat with V5 or V7 as needed:
```bash
python parse_props_v5.py
python parse_props_v7.py
```

### 0.7 Verify Results
- The script prints debug info if `DEBUG = True` in the file header.
- Open the output `.db` in your SQLite browser or via CLI:
```bash
python - << 'PY'
import sqlite3
conn = sqlite3.connect('database/lor_output_v6.db')
for t in ['previews','props','subProps','dmxChannels']:
    c = conn.execute(f"SELECT COUNT(*) FROM {{t}}")
    print(t, c.fetchone()[0])
conn.close()
PY
```

### 0.8 Create Wiring Views
Paste the view definitions (see **Section 2** in this doc) into your SQLite client **after** running a parser. Then use the tester queries.

### 0.9 Typical Run Flow
1. Adjust `DB_FILE` in the parser you intend to run (V5/V6/V7).
2. Run the parser → enter the folder containing `.lorprev` files.
3. Open `.db` → create `v_wiring_map_v6` or `v_wiring_map_v7`.
4. Run the **sanity checks** below (counts, single-display lookup, etc.).
5. If linking inventory, create `v_wiring_with_inventory` and test joins.

### 0.10 Troubleshooting
- **`sqlite3.OperationalError: unable to open database file`** → The path in `DB_FILE` doesn’t exist.
- **No tables created** → The selected folder had no `.lorprev` files or XML couldn’t be parsed.
- **Missing Network/Controller/Channel** → For LOR, ensure `ChannelGrid` existed; for DMX, check `dmxChannels` rows for the prop.
- **Access compatibility** → Prefer V6/V7 (integer primary keys).

### 0.11 Platform Notes
- **Windows**: If multiple Python versions are installed, VS Code may show `Python 3.x (64-bit)` interpreters. Pick the one inside `.venv`.
- **macOS**: If your system Python shows 2.x, use `python3` in commands and VS Code settings.