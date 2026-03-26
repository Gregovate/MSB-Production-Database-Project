# Inventory Tracking Modes
<!-- File: docs/02_Production_Database/Inventory_Tracking_Modes_Notes.md -->
<!-- Purpose: discussion note for Kanban stock items vs asset-tracked items -->

## Status
Discussion only. No code. No schema changes yet.

## Confirmed Direction

Inventory should support at least two different tracking modes:

1. Kanban / stock-tracked items
2. Asset-tracked items

These should share a common inventory foundation, but they should not be forced into the same operational model.

---

## 1. Kanban / Stock-Tracked Items

Examples:
- lights
- zip ties
- wire
- cable
- connectors
- consumables

These items are best managed as stock, not as individual assets.

What matters:
- item definition
- quantity on hand
- reorder point
- target stock level
- preferred vendor
- unit of measure
- replenishment planning

This is a stock-control problem.

Core question:
**Do we have enough on hand, and when do we need more?**

---

## 2. Asset-Tracked Items

Examples:
- controllers
- tools
- cameras
- network switches
- tablets
- printers
- test equipment

These items need unique identity because they can be:
- assigned
- moved
- repaired
- retired
- placed on shelf
- returned to service

This is an asset lifecycle problem.

Core question:
**Which exact unit is this, where is it, and what is it assigned to?**

---

## Recommended Shared Backbone

### Shared inventory item master
One common catalog for all inventoryable item types.

Each item type should include a tracking mode such as:
- `KANBAN_STOCK`
- `ASSET_TRACKED`

This allows one inventory system without forcing one identical behavior for all items.

---

## Recommended Operational Split

### For Kanban / stock items
Use stock-oriented tracking:
- quantity on hand
- reorder point
- target quantity
- storage location as needed
- purchase/vendor information as needed

### For asset-tracked items
Use one row per owned unit:
- asset identity
- item type
- status
- location
- assignment state
- purchase information
- retirement/service notes

---

## Controller Position in This Design

Controllers are asset-tracked items.

They should use:
- shared inventory item master
- shared asset tracking layer

and then extend into controller-specific operational tables for:
- UID/network assignment
- stage assignment
- channel definitions
- channel usage
- spare channels

Controllers remain a specialized asset class.

---

## Current Conclusion

Best current direction:

- one shared inventory architecture
- explicit tracking mode on item types
- Kanban/stock subsystem for consumables and supplies
- asset subsystem for individually tracked equipment
- specialized controller subsystem layered on top of asset tracking