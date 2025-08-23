# SQLite Database Review Guide (DB Browser Only)

Some teammates may prefer to avoid the command line. These instructions use **DB Browser for SQLite**, a free graphical tool.

The database file is stored here:

```
G:\Shared drives\MSB Database\database\lor_output_v6.db
```

---

## 1. Install DB Browser for SQLite

1. Go to <https://sqlitebrowser.org/>
2. Download the Windows installer.
3. Run the installer and follow the prompts (accept defaults).

---

## 2. Open the Database

1. Launch **DB Browser for SQLite**.
2. Click **Open Database** from the main screen or the **File** menu.
3. Browse to:
   ```
   G:\Shared drives\MSB Database\database\lor_output_v6.db
   ```
4. Select it and click **Open**.

---

## 3. Explore the Wiring View

1. Once the database is open, click the **Browse Data** tab.
2. In the **Table/View** dropdown, select:
   ```
   vw_wiring
   ```
3. Scroll through the results to see the wiring view.

---

## 4. Export the Wiring Data (Optional)

1. In **DB Browser**, click the **File → Export → Table(s) as CSV file...**
2. Choose the `vw_wiring` view.
3. Save the file as `wiring_export.csv` to the desired location (e.g., Desktop or shared drive).

---

## ✅ At this point, you should be able to:

- Open `lor_output_v6.db` in DB Browser  
- Review the new `vw_wiring` view without using the command line  
- Export results to CSV if needed  
