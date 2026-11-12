# MSB Label Printing System — Operational SOP

**Project:** MSB Production Database
**System:** QR Label Printing (Displays & Containers)
**Applies To:** Shop Operators, Managers, IT Support
**Author:** Greg Liebig / Engineering Innovations, LLC
**Effective Date:** 2026-03-20
**Version:** 1.0

---

## 1. PURPOSE

This procedure defines the **standard method for requesting, batching, printing, and tracking QR code labels** for MSB assets.

The system ensures:

* No duplicate or lost labels
* Safe operation during printer errors (paper out, jams, offline)
* Full audit history of who printed what and when
* Ability to reprint any label on demand
* Compatibility with Displays, Containers, and future Controllers
* Operator-controlled workflow (no automatic decisions)

---

## 2. SYSTEM OVERVIEW

Label printing uses a **snapshot batch model**.

Operators select records to print → Service captures snapshot → Service prints → History recorded → Flags cleared for printed records only.

New selections made during printing are NOT affected.

### 2.1 Asset Types Supported

* Displays (1 label per asset)
* Containers (2 labels per asset)
* Controllers (future)

### 2.2 Key Database Fields

Each asset table contains:

| Field                | Purpose                         |
| -------------------- | ------------------------------- |
| `print_label`        | Operator request flag           |
| Label history tables | Permanent audit                 |
| Batch tables         | Temporary snapshot for printing |

---

## 3. OPERATOR PROCEDURE — REQUESTING LABELS

### 3.1 Selecting Labels to Print

1. Open Directus.

2. Navigate to the asset collection:

   * **Displays**
   * **Containers**
   * (Controllers when implemented)

3. Locate the records needing labels.

4. Set:

```
print_label = TRUE
```

Use individual edit or group edit.

---

### 3.2 Important Rules

* You may request labels regardless of status.
* Previously printed assets may be reprinted.
* The `label_required` field is informational only.
* Do NOT clear flags manually after printing.

---

## 4. PRINT SERVICE OPERATION (AUTOMATED)

The Label Print Service runs on the office workstation.

### 4.1 Polling Behavior

Service periodically checks for:

```
print_label = TRUE
```

When found:

1. Creates a new batch
2. Snapshots selected records
3. Generates CSV files
4. Sends job to printer
5. Waits for completion
6. Writes history
7. Clears flags ONLY for printed records

---

## 5. BATCH SNAPSHOT MODEL

### 5.1 Why Snapshot Is Required

Prevents data corruption when:

* Operators continue selecting labels
* Printer runs out of media
* Jobs are interrupted
* Multiple batches occur simultaneously

### 5.2 Batch Lifecycle

| Status    | Meaning                                   |
| --------- | ----------------------------------------- |
| PENDING   | Snapshot created, not yet printed         |
| PRINTING  | Job sent to printer                       |
| COMPLETED | Successfully printed                      |
| FAILED    | Error occurred (manual recovery required) |

---

## 6. PRINTER FAILURE HANDLING

### 6.1 Out-of-Media / Jam / Offline

If printing stops:

* Batch remains PENDING or PRINTING
* Flags remain TRUE
* No history written
* Job may be safely retried

Do NOT manually clear flags.

---

### 6.2 Recovery Procedure

1. Fix printer issue
2. Resume print job (if supported)
3. If job was cancelled:

   * IT may restart service
   * Or manually re-run batch

---

## 7. LABEL QUANTITY RULES

| Asset Type  | Labels Produced |
| ----------- | --------------- |
| Displays    | 1 per asset     |
| Containers  | 2 per asset     |
| Controllers | TBD             |

Quantity is enforced by the print service, not by operators.

---

## 8. LABEL TYPES

### 8.1 Display Labels

* QR code links to display scan page
* One or two lines of text
* Format determined automatically

### 8.2 Container Labels

Two templates exist:

| Container Type | Orientation |
| -------------- | ----------- |
| Type = 1       | Vertical    |
| Other Types    | Horizontal  |

Operators do NOT select orientation manually.

---

## 9. PRINT HISTORY

Every successful label print creates a permanent record containing:

* Asset ID
* Timestamp
* Operator/service identity
* Label data used
* Method (Batch Service or Manual)

History cannot be deleted by operators.

---

## 10. VERIFYING LABEL STATUS

Operators may view:

* Last printed date/time
* Who printed it
* Reprint history

No external tracking is required.

---

## 11. REPRINTING LABELS

To reprint any label:

1. Locate asset in Directus
2. Set `print_label = TRUE`
3. Wait for next batch cycle

Previous prints remain in history.

---

## 12. DO NOT DO THE FOLLOWING

❌ Do not manually delete history records
❌ Do not modify batch tables
❌ Do not clear flags during active printing
❌ Do not power off printer mid-job unless necessary

---

## 13. SPECIAL NOTES FOR MASS RELABELING

When large numbers of assets require labels:

* Use group edit to set flags
* Allow service to batch automatically
* Large jobs may produce many labels without ordering
* Sorting improvements may be implemented later

---

## 14. CONTROLLER LABELS (FUTURE)

Controllers will follow the same architecture:

* Separate asset table
* Same flag
* Same batching system
* Same history tracking

---

## 15. SUPPORT CONTACT

For system issues:

**Engineering Innovations, LLC**
Greg Liebig

Do not attempt database changes without authorization.

---

## 16. CHANGE HISTORY

| Date       | Version | Description                 |
| ---------- | ------- | --------------------------- |
| 2026-03-20 | 1.0     | Initial operational release |

---

**END OF SOP**
