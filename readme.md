# Project Title

A brief description of what this project does and who it's for.

## Features

- Light O Rama (LOR) integration for large light show management
- Dynamic updates and customization
The logic you've outlined for processing the LOR preview files provides a comprehensive approach to organizing props, subprops, and displays. Below is a breakdown and clarification of your current processing logic, as well as the outstanding issue with #2:

---

### **Processing Logic Summary**

1. **SubProps Definition**:
   - Process props with:
     - Same `LORComment`
     - `devicetype == LOR`
     - Single channel grid group
     - `masterpropID` exists
   - Action:
     - These props are subprops and should be placed in the `subprops` table, linked to the `masterID` prop.

2. **Grouped Props with Repeating `LORComment`** (**Current Issue**):
   - Process props with:
     - Repeating `LORComment`
     - `devicetype == LOR`
     - Single channel grid
     - No `masterpropID`
   - Action:
     - Group props by `LORComment`.
     - Create a derived master prop using the lowest channel number in the group.
     - Place the master prop in the `props` table.
     - Move remaining props in the group to the `subprops` table, linking them to the master prop.

3. **Multi-Channel Props**:
   - Process props with:
     - Single `LORComment`
     - `devicetype == LOR`
     - More than one channel grid
     - No `masterpropID`
   - Action:
     - Lowest channel becomes the master prop (remains in the `props` table).
     - Assign display names to remaining props for display purposes.
     - Handle complex display types (e.g., Light Curtain motion tags).

4. **DMX Props with Multi-Channel Groups**:
   - Process props with:
     - Same `LORComment`
     - `devicetype == DMX`
     - Multiple channel groups
     - No `masterpropID`
   - Action:
     - Lowest channel number prop is placed in the `props` table.
     - Create a link using the `propID` and move remaining data to the `dmxchannels` table.

5. **Non-LOR Controlled Props**:
   - Process props with:
     - `devicetype == none`
   - Action:
     - Store directly in the `props` table.

---

### **Current Issue with #2**
- **Problem**: For props with repeating `LORComment` and no `masterpropID`, only one display ends up in the `props` table, and the rest are not correctly moved to the `subprops` table.
- **Examples**:
  - Singing Trees: 8 displays (4 version 1, 4 version 2). Each group of face props with the same `LORComment` needs to be grouped as one display.
  - Who Panel: Multiple props on the same panel comprise one display, but each plug must be accounted for setup.

---

### **Recommendations**
1. **Ensure Correct Grouping and Relocation**:
   - Use a query or data processing step to:
     - Identify groups by `LORComment`.
     - Determine the lowest channel as the master prop.
     - Explicitly move remaining props in the group to the `subprops` table, ensuring links are created.

2. **Data Validation**:
   - Validate after processing:
     - All props with the same `LORComment` are either part of the master prop or in the `subprops` table.
     - No duplicate entries or missed groupings.

3. **Testing with Edge Cases**:
   - Use provided examples like the Singing Trees and Who Panel to validate that the logic is working as expected.
   - Extend tests to handle scenarios like mismatched displays in previews (e.g., Church RGB preview).

---

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
   ```bash
   npm install
   # or
   pip install -r requirements.txt
   ```

## Usage

Explain how to use the project with code examples:

```bash
# Run the project
npm start
# or
python main.py
```

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
