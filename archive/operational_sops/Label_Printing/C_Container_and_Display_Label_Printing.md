# MSB Label Printing — Operator Guide

**Author:** Greg Liebig / Engineering Innovations, LLC  
**Date:** 2026-03-30
**System Version:** Label Service v3.x  

This guide explains how to print display and container labels
using the Directus interface.

---

## 🖥️ Accessing Label Printing

Use the Directus left navigation panel.

![Directus Menu](/Docs/images/directus_menu.jpg)

### Display Labels


Display → Print Display Labels


### Container Labels


Container → Print Container Labels


---

## 📋 Printing Multiple Labels at Once

### Step 1 — Find the Items

Use the search box at the top of the table.

![Search](/Docs/images/search_batch_edit.jpg)

Example:

- Type part of a container name
- Filter by location
- Narrow the list as needed

---

### Step 2 — Select Items

Use the checkbox column on the left side of the table.


![Container Selection](/Docs/images/container_selection.jpg)


Select all items you want to print.

---

### Step 3 — Open Batch Editor

Click the pencil icon in the upper-right corner.

![Search](/Docs/images/search_batch_edit_pencil.jpg)

This opens the batch editing panel.

---

### Step 4 — Enable Print Label

Toggle **Print Label → Enabled**


![Batch Edit Toggle](/Docs/images/container_print_toggle.jpg)


Then save the changes.

---

## 🖨️ What Happens Next

After saving:

1. Labels are queued automatically
2. The print service creates a batch
3. Labels print at the label printer
4. The Print Label flag resets automatically after completion

No further action is required.

## Label batch actor rule

The actor for a label print batch is the user who last updated the print-triggering record at the moment the batch row is created.

The batch row must store this actor directly so the print service and logs do not need to infer it later.

Recommended fields on the batch:
- requested_by
- requested_by_person_id
- requested_at

---

## ❗ If Printing Does Not Start

🚫 Do NOT repeatedly click print

If labels do not start printing:

1. Wait at least **10–15 seconds**
2. Verify the printer is powered on and has tape installed

If printing still does not start:

👉 [Label Print Service — Operator Guide](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Operator_Label_Printing.md)

This guide explains how to check and restart the print service on the dedicated print server.

---

🚨 Do NOT continue retrying print jobs without checking the service first

---

## ❗ If Tape Runs Out During Printing

Symptoms:

- Printer stops feeding tape
- Labels may be incomplete
- System may still mark batch complete

Action:

Note: This section is not tested as of 3/22/26-GAL

1. Load a new cartridge
2. Re-select labels that did not print
3. Enable **Print Label** again
4. Save to reprint

---

## 📦 Container Labels vs Display Labels

### Display Labels

- One label per display
- Typically printed in batches

### Container Labels

- Two labels printed per container
- Used for physical storage identification

---

## 📌 Best Practices

✔ Print labels in manageable batches  
✔ Verify output before removing items  
✔ Keep spare cartridges nearby  
✔ Do not power off printer during printing  

---

## 🆘 Support

Contact the MSB production database administrator
if printing repeatedly fails or produces incorrect labels.

---

## 🔄 Revision History

- 03/30/2026  
  - Documented post-print workflow behavior ("What Happens Next")  
  - Added label batch actor tracking rule (requested_by, requested_by_person_id, requested_at)

- 03/27/2026  
  - Initial operator guide for Label Service v3