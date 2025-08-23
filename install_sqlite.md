# SQLite Setup and Database Review Guide (Windows Only)

This guide will help you install SQLite on your Windows computer and open the **version 6 database** (`lor_output_v6.db`) located on the shared drive:

```
G:\Shared drives\MSB Database\database
```

---

## 1. Install SQLite on Windows

1. Go to the official SQLite download page: <https://www.sqlite.org/download.html>
2. Under **Precompiled Binaries for Windows**, download:
   - `sqlite-tools-win-x64-*.zip`
3. Extract the `.zip` file somewhere (e.g., `C:\sqlite`).
4. (Optional but recommended) Add that folder to your system **PATH** so you can run `sqlite3` from anywhere:
   - Press `Win + R`, type `sysdm.cpl`, and press Enter.
   - Go to **Advanced → Environment Variables**.
   - Under *System variables*, select **Path** → **Edit** → **New** → enter `C:\sqlite`.
   - Close and reopen Command Prompt.

---

## 2. Install a GUI (Optional but Recommended)

For a friendlier interface, install **DB Browser for SQLite**:

- Download: <https://sqlitebrowser.org/>
- Works on Windows.
- Lets you open databases, browse tables/views, and run SQL queries with a point-and-click interface.

---

## 3. Open the Database

### Command Line
1. Open Command Prompt or PowerShell.
2. Navigate to the shared drive:
   ```powershell
   cd "G:\Shared drives\MSB Database\database"
   ```
3. Open SQLite with the database:
   ```powershell
   sqlite3 lor_output_v6.db
   ```

### DB Browser (GUI)
1. Launch **DB Browser for SQLite**.
2. Click **Open Database**.
3. Browse to:
   ```
   G:\Shared drives\MSB Database\database\lor_output_v6.db
   ```
4. Select it and click **Open**.

---

## 4. Explore the Wiring View

### In SQLite CLI
Inside the SQLite shell, run:

```sql
.tables                -- show all tables and views
.schema vw_wiring      -- view the wiring view definition
.headers on
.mode column
SELECT * FROM vw_wiring LIMIT 20;
```

### In DB Browser
- Use the **Browse Data** tab to scroll through results.
- Use the **Execute SQL** tab to run the same commands above.

---

## 5. Export Data (Optional)

To save wiring data to a CSV file (CLI only):

```sql
.headers on
.mode csv
.output wiring_export.csv
SELECT * FROM vw_wiring;
.output stdout
```

This will create `wiring_export.csv` in the `G:\Shared drives\MSB Database\database` folder.

---

## 6. Exit SQLite

From the CLI shell, type:
```sql
.quit
```

---

✅ At this point, you should be able to:
- Open `lor_output_v6.db`
- Review the new `vw_wiring` view
- Export results if needed
