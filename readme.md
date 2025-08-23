# MSB Production Database
The logic outlined in this project is for processing the LOR v6.3.10 Pro preview file and provides a comprehensive approach to organizing props, subprops, and displays required to manage a large light show utilizing the Light O Rama sequencing software. 

# Objective
Outline actions needed to process *.lorprev files in a specified folder to extract xml keys found for PreviewClass and PropClass. Parse and data and format prop file to provide the structure necessary to create a one to one link to the between the props table and external displays table. This will be accomplished by utilizing the comment field to assign the display name. We will create separate tables using the keys found in previewsClass and propClass records. All requisite data is in the preview file. 

# Goal
Create props table that contains one record per display. Use the subprops and dmx channel tables to store the information needed to setup the displays. This is needed to manage the physical displays we design, build, inventory, and set up the light show. 
---

## Developer Quick Links

- [DEBUG Guide](./debug.md) — step-by-step instructions for running the parsers in VS Code,
  required Python setup, **previews folder location**, and troubleshooting tips.

### Previews Location (Team Standard)
All exported `.lorprev` preview files are stored in the shared Google Drive:


# Background Information:
The propClass is designed to sequence a light show but is not friendly to manage the inventory and documentation to set it up. The propClass is very consistent and provides all the information needed by utilizing the comment field to set the key for displays. There could be one prop per display. There could be props with SubProps in a display. there can be shared props on one display. there could be shared props that are on different displays. There can be multiple props on one display, there can be  prop file. since one display can contain multiple props

# Definitions:
  - Preview: A collection of props in a designated stage. This can be a collection of props sequenced to music or a background animation.
  - LOR: Abbreviation for Light O Rama
  - Stage: An area set to a theme containing displays that are either background animations or displays sequenced to music.
  - Prop: Light O Rama defines a prop as any device that responds to a command sent from the sequencer. This is a very confusing term since most people think a prop is a single physical object.
  - SubProp: A prop that responds to the same commands as a prop. This must be explicitly assigned in the preview.
  - Display: A display as a single physical object that we design, build, setup, and inventory. A display can be a single prop or can be a combination of props and/or SubProp.
  - UID: The hexadecimal number assigned to a controller
  - id: is the  UUID or "Universally Unique Identifier" assigned to the id of a prop, preview, or subprop by the LOR Software at the time of creation. This number will not change unless the prop is deleted or is imported into a preview where that UUID is shared with a duplicated prop. All duplicated props must be placed into the same preview and re-exported to ensure 


## Features

- Light O Rama (LOR) v6.3.10 Pro integration for large light show management
- Dynamic updates and customization using exported *.lorprev files 
- Reads the prop data and links to a table containing Display information using a sqlite database
- The datafiles are untouched as not to affect the sequencing software.


---

### **Processing Logic Summary**
- [Procesing Rules](ProcessingRules.md)

### **Additional Notes**
- **Fancy Queries or Joins**:
  - When reassembling data for setup, consider using server-side logic (e.g., SQL JOINs or stored procedures) to simplify retrieval based on the linked tables (`props`, `subprops`, `dmxchannels`, etc.).

- **Terminology Updates**:
  - `propbuildInfo` → `Display` table: Links `DisplayName` to `LORComment`.
  - `Fixtures` → `subprops` table.

Let me know if you'd like me to refine the explanation further or help troubleshoot the script!

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/username/repo-name.git
   ```

2. Navigate to the project directory:
   ```bash
   cd repo-name
   ```

3. Install dependencies:
   - Python is required on required on the machine you are running this script.
   - SQLite browser required to open the database created.
   
## Usage

  1. Create a folder to store the exported previews you want to include for processing. If you want to include all previews, just use the ImportExport folder under your Light O Rama installation.

  2. Using the Light O Rama Sequencing Software, Navigate to the Preview Panel and Right Click in the preview or previews you want to include in the database and save them to the folder of your choice.

  3. Open a Terminal Window and run the parse_props_vx.py script. When prompted, enter the path to the folder containing the preview(s) you want to process.

  4. The location for the database is currently hard coded at the top of the script. This can be changed to put the database in the location of your choosing.


## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-name`).
3. Commit your changes (`git commit -m 'Add some feature'`).
4. Push to the branch (`git push origin feature-name`).
5. Open a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.

## Acknowledgments

- [Resource 1](https://example.com)
- [Resource 2](https://example.com)
- [Resource 3](https://example.com)
