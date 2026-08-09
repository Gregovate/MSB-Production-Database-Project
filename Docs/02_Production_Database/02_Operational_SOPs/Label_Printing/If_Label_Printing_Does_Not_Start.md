# If Label Printing Does Not Start

[← Previous: Print Display or Container Labels](Print_Display_or_Container_Labels.md) | [↑ Label Printing Home](README.md)

| Document Control | Value |
|---|---|
| Document Type | Operational SOP |
| System | Production Database — Label Printing |
| Task | Respond when requested labels do not print |
| Audience | Volunteers / Managers |
| Status | CURRENT |
| Owner | Production Database Manager |
| Last Reviewed | 2026-08-09 |
| Keywords | labels, printer, troubleshooting, LabelPrintService |

## Purpose

Use this procedure when you requested labels from the Production Database but printing does not start.

## Procedure

1. Do **not** repeatedly enable Print Label or keep resubmitting the same records.
2. Wait at least 10–15 seconds for the print request to process.
3. Verify that the label printer is powered on.
4. Verify that label tape is installed.
5. If printing still does not start, use the LabelPrintService operator procedure for the dedicated print server:

[Label Print Service — Operator Guide](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Operator_Label_Printing.md)

## If Tape Runs Out

Do not assume the entire batch failed or immediately resubmit every label.

The previous combined SOP contained a reprint sequence for this condition, but it was explicitly marked as **not tested**. Until that behavior is verified, check which labels actually printed and use the LabelPrintService operator guidance or ask the Production Database administrator before reprinting.

## Expected Result

A printing failure is investigated without creating unnecessary duplicate print requests or duplicate labels.

## Related Documents

- [Print Display or Container Labels](Print_Display_or_Container_Labels.md)
- [Label Printing Home](README.md)

---

[← Previous: Print Display or Container Labels](Print_Display_or_Container_Labels.md) | [↑ Label Printing Home](README.md)
