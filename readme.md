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

# MSB Production Database Project

This repository contains all scripts, configuration, and documentation for the **Making Spirits Bright Production Database**, used to manage LOR previews, stage wiring maps, prop inventory, and show integration.

---

## 📂 Repository Structure

| Folder | Description |
|--------|--------------|
| `Docs/` | Full documentation hub — operator guides, naming conventions, workflows, and field procedures |
| `Apps/` | Application builds and source (FormView, Parser, Merger, etc.) |
| `Docs/images/` | Screenshots and diagrams referenced in documentation |

---

## 🧭 Quick Start

**Primary workflow (v6):**
1. Run the **Preview Merger** (`preview_merger.py`)
2. Run the **Parser** (`parse_props_v6.py`)
3. Run the **Excel Export / DB Compare** step  
4. Open reports under  
   `G:\Shared drives\MSB Database\Spreadsheet`

---

## 📘 Full Documentation

➡️ See the complete documentation hub under  
[**Docs/README.md**](./Docs/README.md)

---

© Engineering Innovations, LLC — Greg Liebig  
Making Spirits Bright Production Team, Sheboygan WI
