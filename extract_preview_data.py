import xml.etree.ElementTree as ET
import os
import sqlite3
import re

def initialize_database():
    # Connect to the database (do not delete the file)
    conn = sqlite3.connect("LOR.db")
    conn.execute("PRAGMA cache_size = -64000;")  # Increase cache size
    cursor = conn.cursor()

    # Drop existing tables and views
    cursor.execute("DROP VIEW IF EXISTS LORProps")
    cursor.execute("DROP VIEW IF EXISTS FullHierarchy")
    cursor.execute("DROP TABLE IF EXISTS dmxChannels")
    cursor.execute("DROP TABLE IF EXISTS subProps")
    cursor.execute("DROP TABLE IF EXISTS props")
    cursor.execute("DROP TABLE IF EXISTS previews")
    cursor.execute("DROP TABLE IF EXISTS displays")

    # Create tables for previews, props, subProps, dmxChannels, and displays
    cursor.execute("""
        CREATE TABLE previews (
            id TEXT PRIMARY KEY,
            StageID TEXT,
            PreviewType TEXT,
            Name TEXT,
            Revision TEXT,
            Brightness REAL,
            BackgroundFile TEXT
        )
    """)

    cursor.execute("""
        CREATE TABLE props (
            PropID TEXT PRIMARY KEY,
            Name TEXT,
            Comment TEXT,
            DeviceType TEXT,
            MaxChannels INTEGER,
            Tag TEXT,
            Lights INTEGER,
            Attributes TEXT,
            displayID TEXT,
            FOREIGN KEY (displayID) REFERENCES displays (displayID)
        )
    """)

    cursor.execute("""
        CREATE TABLE subProps (
            SubPropID TEXT PRIMARY KEY,
            Name TEXT,
            Comment TEXT,
            MasterPropID TEXT,
            Network TEXT,
            UID TEXT,
            StartChannel TEXT,
            EndChannel TEXT,
            Unknown TEXT,
            Color TEXT,
            Lights INTEGER,
            Attributes TEXT,
            FOREIGN KEY (MasterPropID) REFERENCES props (PropID)
        )
    """)

    cursor.execute("""
        CREATE TABLE dmxChannels (
            PropId TEXT,
            Network TEXT,
            Start_Unv INTEGER,
            Start_Channel INTEGER,
            End_Channel INTEGER,
            Unknown TEXT,
            Color TEXT,
            FOREIGN KEY (PropId) REFERENCES props (PropID)
        )
    """)

    cursor.execute("""
        CREATE TABLE displays (
            displayID TEXT PRIMARY KEY,
            Comment TEXT UNIQUE,
            Description TEXT,
            Location TEXT,
            Stage TEXT,
            InstallationDate TEXT,
            MaintenanceDate TEXT,
            Notes TEXT
        )
    """)

    # Create a view to join previews, displays, props, and subProps
    cursor.execute("""
        CREATE VIEW FullHierarchy AS
        SELECT 
            pr.id AS PreviewID,
            pr.Name AS PreviewName,
            pr.StageID,
            pr.PreviewType,
            pr.Revision,
            pr.Brightness,
            pr.BackgroundFile,
            d.displayID AS DisplayID,
            d.Comment AS DisplayComment,
            d.Description AS DisplayDescription,
            d.Location AS DisplayLocation,
            d.Stage AS DisplayStage,
            p.PropID,
            p.Name AS PropName,
            p.Comment AS PropComment,
            p.DeviceType,
            p.MaxChannels,
            p.Tag AS PropTag,
            p.Lights AS PropLights,
            sp.SubPropID,
            sp.Name AS SubPropName,
            sp.Comment AS SubPropComment,
            sp.Network AS SubPropNetwork,
            sp.UID AS SubPropUID,
            sp.StartChannel AS SubPropStartChannel,
            sp.EndChannel AS SubPropEndChannel,
            sp.Unknown AS SubPropUnknown,
            sp.Color AS SubPropColor,
            sp.Lights AS SubPropLights
        FROM previews pr
        LEFT JOIN displays d ON pr.id = d.displayID
        LEFT JOIN props p ON d.displayID = p.displayID
        LEFT JOIN subProps sp ON p.PropID = sp.MasterPropID;
    """)

    cursor.execute("""
        CREATE VIEW LORProps AS
        SELECT 
            pr.Name AS PreviewName,
            p.Name AS PropName,
            sp.Name AS SubPropName
        FROM previews pr
        JOIN props p ON pr.id = p.displayID
        LEFT JOIN subProps sp ON p.PropID = sp.MasterPropID;
    """)

    conn.commit()
    return conn

def populate_displays(conn):
    cursor = conn.cursor()

    # Populate displays table from unique Comments in props
    cursor.execute("""
        INSERT OR IGNORE INTO displays (displayID, Comment)
        SELECT DISTINCT PropID, Comment
        FROM props;
    """)
    conn.commit()

def link_props_to_displays(conn):
    cursor = conn.cursor()

    # Link props to displays based on the Comment field
    cursor.execute("""
        UPDATE props
        SET displayID = (
            SELECT displayID
            FROM displays
            WHERE displays.Comment = props.Comment
        )
        WHERE Comment IS NOT NULL;
    """)
    conn.commit()

def process_file(file_path, conn):
    # Parse the XML file
    tree = ET.parse(file_path)
    root = tree.getroot()

    # Extract structure for previews, props, subProps, and DMX channels
    previews = []
    props = []
    sub_props = []

    # Extract StageID and PreviewType from the file name
    stage_match = re.search(r"Stage (\d{2})", os.path.basename(file_path))
    stage_id = stage_match.group(1) if stage_match else None
    preview_type = os.path.basename(file_path).split()[0]

    for elem in root.iter():
        if elem.tag == "PreviewClass":
            previews.append({
                "id": elem.attrib.get('id'),
                "StageID": stage_id,
                "PreviewType": preview_type,
                "Name": elem.attrib.get('Name', None),
                "Revision": elem.attrib.get('Revision', None),
                "Brightness": float(elem.attrib.get('Brightness')) if elem.attrib.get('Brightness') else None,
                "BackgroundFile": elem.attrib.get('BackgroundFile', None)
            })

        if elem.tag == "PropClass":
            # Extract attributes
            attributes = elem.attrib
            
            base_prop_id = attributes.get('id')
            master_prop_id = attributes.get('MasterPropID', "")
            device_type = attributes.get('DeviceType', "")

            if device_type == "LOR" and master_prop_id:
                # Move to subProps table if MasterPropID is not empty
                sub_props.append({
                    "SubPropID": base_prop_id,  # Use PropID as SubPropID
                    "Name": attributes.get('Name'),
                    "Comment": attributes.get('Comment'),
                    "MasterPropID": master_prop_id,
                    "Network": attributes.get('Network'),
                    "UID": attributes.get('UID'),
                    "StartChannel": attributes.get('StartChannel'),
                    "EndChannel": attributes.get('EndChannel'),
                    "Unknown": attributes.get('Unknown'),
                    "Color": attributes.get('Color'),
                    "Lights": int(attributes.get('Parm2')) if attributes.get('Parm2') else None,
                    "Attributes": str(attributes)
                })
            else:
                # Keep in props table if MasterPropID is empty
                props.append({
                    "PropID": base_prop_id,
                    "Name": attributes.get('Name'),
                    "Comment": attributes.get('Comment'),
                    "DeviceType": device_type,
                    "MaxChannels": int(attributes.get('MaxChannels')) if attributes.get('MaxChannels') else None,
                    "Tag": attributes.get('Tag'),
                    "Lights": int(attributes.get('Parm2')) if attributes.get('Parm2') else None,
                    "Attributes": str(attributes)
                })

    # Insert data into the database
    cursor = conn.cursor()

    # Insert previews
    cursor.executemany(
        "INSERT OR IGNORE INTO previews (id, StageID, PreviewType, Name, Revision, Brightness, BackgroundFile) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [(preview['id'], preview['StageID'], preview['PreviewType'], preview['Name'], preview['Revision'], preview['Brightness'], preview['BackgroundFile']) for preview in previews]
    )

    # Insert props
    cursor.executemany(
        "INSERT OR IGNORE INTO props (PropID, Name, Comment, DeviceType, MaxChannels, Tag, Lights, Attributes) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [(prop['PropID'], prop['Name'], prop['Comment'], prop['DeviceType'], prop['MaxChannels'], prop['Tag'], prop['Lights'], prop['Attributes']) for prop in props]
    )

    # Insert sub-props
    cursor.executemany(
        "INSERT OR IGNORE INTO subProps (SubPropID, Name, Comment, MasterPropID, Network, UID, StartChannel, EndChannel, Unknown, Color, Lights, Attributes) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [(sub_prop['SubPropID'], sub_prop['Name'], sub_prop['Comment'], sub_prop['MasterPropID'], sub_prop['Network'], sub_prop['UID'], sub_prop['StartChannel'], sub_prop['EndChannel'], sub_prop['Unknown'], sub_prop['Color'], sub_prop['Lights'], sub_prop['Attributes']) for sub_prop in sub_props]
    )

    conn.commit()

def process_folder(folder_path):
    # Initialize the database
    conn = initialize_database()

    # Process all .lorprev files in the specified folder
    for file_name in os.listdir(folder_path):
        if file_name.lower().endswith(".lorprev"):
            file_path = os.path.join(folder_path, file_name)
            print(f"Processing file: {file_path}")
            process_file(file_path, conn)

    # Populate displays table
    populate_displays(conn)

    # Link props to displays
    link_props_to_displays(conn)

    conn.close()
    print(f"Processing complete. Data saved to {os.path.abspath('LOR.db')}")

if __name__ == "__main__":
    folder_path = input("Enter the folder path containing .lorprev files: ")
    process_folder(folder_path)
