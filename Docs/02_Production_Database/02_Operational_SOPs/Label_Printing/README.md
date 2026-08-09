# Label Printing Operational SOPs

Use this page to go directly to the label-printing task you are doing now.

## What Do You Need To Do?

| I want to... | Go to |
|---|---|
| Print display or container labels | [Print Display or Container Labels](Print_Display_or_Container_Labels.md) |
| Troubleshoot when labels do not print | [If Label Printing Does Not Start](If_Label_Printing_Does_Not_Start.md) |

## System Boundary

The Production Database is where operators request labels. The separate **MSB_LabelPrintService** performs the actual printing on the dedicated print server.

Normal operator flow:

**Directus -> select Display or Container records -> enable Print Label -> save -> LabelPrintService prints the labels**

The Production Database remains authoritative for the asset records and print request. Service operation and print-server troubleshooting belong to the LabelPrintService project.

## Related Operational Procedures

- [Containers](../Containers/README.md)
- [Displays](../Displays/README.md)
- [Production Database Operational SOPs](../README.md)

## Related Engineering

These links are for readers who want to understand how the labeling system works. They are not required for normal label-printing tasks.

- [Labeling and Scanning Engineering Handoff](../../01_System_Architecture/07_Labeling_and_Scanning/README.md)
- [LabelPrintService Operator Guide](https://github.com/Gregovate/MSB_LabelPrintService/blob/main/docs/Operator_Label_Printing.md)
