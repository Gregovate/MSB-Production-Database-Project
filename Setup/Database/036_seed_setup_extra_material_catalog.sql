/* MSB Setup #167 — normalized Extra Material base catalog seed. REVIEW BEFORE PRODUCTION. */
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Migration 032 Extra Material catalog is required first';
    END IF;
END
$preflight$;

/* One row per normalized material family. Size/length/color are relationship
   attributes and are deliberately not seeded as separate catalog identities. */
INSERT INTO ref.setup_extra_material(
    display_order, material_name, lifecycle_class, default_uom, notes
)
VALUES
    (10, 'Anchor Nail', 'REUSABLE', 'EA', NULL),
    (20, 'Arch Bracket', 'REUSABLE', 'EA', NULL),
    (30, 'Arch Foot', 'REUSABLE', 'EA', 'Normalized from Arch Pipe Base and Arch Base Post / Foot.'),
    (40, 'Arch Foot Pad', 'REUSABLE', 'EA', NULL),
    (50, 'Ball Bungee', 'REUSABLE', 'EA', 'Bungee and Ball Bungee are the same normalized material. Physical size classes remain verification attributes.'),
    (60, 'Beam Clamp', 'REUSABLE', 'EA', NULL),
    (70, 'Bolts / Washers / Nuts', 'REUSABLE', 'SET', NULL),
    (80, 'Cardboard Separator', 'TEMP_REUSABLE', 'EA', NULL),
    (90, 'Chain', 'REUSABLE', 'EA', NULL),
    (100, 'Clamp', 'REUSABLE', 'EA', NULL),
    (110, 'Concrete Block', 'REUSABLE', 'EA', 'Normalized name; do not use Concrete Weight.'),
    (120, 'Cord Protector', 'TEMP_REUSABLE', 'EA', NULL),
    (130, 'Cribbing / Shim', 'REUSABLE', 'EA', 'Normalized functional family for cribbing, shims and leveling pieces of varying sizes.'),
    (140, 'D-Ring', 'REUSABLE', 'EA', 'Standard name; D-Link and D-Clip are legacy aliases. Size belongs on requirement/content rows.'),
    (150, 'Duct Tape', 'CONSUMABLE', 'ROLL', NULL),
    (160, 'Electrical Tape', 'CONSUMABLE', 'ROLL', NULL),
    (170, 'Extension Cord', 'REUSABLE', 'EA', 'Gauge and length belong on requirement/content rows; color is not cord identity.'),
    (180, 'Eye Bolt', 'REUSABLE', 'EA', 'Normalized name; do not use Eye Hook.'),
    (190, 'Fishing Line', 'REUSABLE', 'FT', NULL),
    (200, 'Foam Noodle', 'REUSABLE', 'EA', NULL),
    (210, 'Hay Bale', 'REUSABLE', 'EA', NULL),
    (220, 'Hose Clamp', 'REUSABLE', 'EA', NULL),
    (230, 'Marking Paint', 'CONSUMABLE', 'CAN', 'Color is operational and belongs on requirement/content rows: RED high voltage, BLUE network, WHITE display/datum layout.'),
    (240, 'Pipe Clamp', 'REUSABLE', 'EA', NULL),
    (250, 'Plywood', 'REUSABLE', 'SHEET', NULL),
    (260, 'Post Base', 'REUSABLE', 'EA', NULL),
    (270, 'Ratchet Strap', 'REUSABLE', 'EA', NULL),
    (280, 'Rubber / Floor Mat', 'TEMP_REUSABLE', 'EA', NULL),
    (290, 'Spare / Replacement Bulb', 'SPARE_REPLACEMENT', 'EA', NULL),
    (300, 'Standard Panel Spacer', 'REUSABLE', 'EA', 'Ordinary near-equal legacy spacer sizes are one standard class; exact physical size remains a verification attribute.'),
    (310, 'Steel Wool', 'CONSUMABLE', 'EA', NULL),
    (320, 'T-Post', 'REUSABLE', 'EA', 'T-Post, Y-Post and Fence Post are aliases. Requirement quantity/length is procedure-backed at task/installation scope, not 2 posts per Display.'),
    (330, 'Tripple Tap', 'REUSABLE', 'EA', 'Normalized MSB name for a 3-way electrical connector.'),
    (340, 'Turnbuckle', 'REUSABLE', 'EA', NULL),
    (350, 'Utility Flag', 'TEMP_REUSABLE', 'EA', NULL),
    (360, 'Velcro Cord Fastener', 'REUSABLE', 'EA', 'Used to secure cords, harnesses and network cables.'),
    (370, 'WD-40', 'CONSUMABLE', 'CAN', NULL),
    (380, 'Waterproof Coupler', 'REUSABLE', 'EA', 'For network connections only.'),
    (390, 'Wedge', 'REUSABLE', 'EA', NULL),
    (400, 'Wood Block', 'REUSABLE', 'EA', NULL),
    (410, 'Wood Block / Lumber', 'REUSABLE', 'EA', NULL),
    (420, 'Wood Blocking / Footpad', 'REUSABLE', 'EA', NULL),
    (430, 'Wooden Support Base', 'REUSABLE', 'EA', NULL)
ON CONFLICT (material_name) DO NOTHING;

COMMIT;

SELECT count(*) AS normalized_extra_material_catalog_rows
FROM ref.setup_extra_material
WHERE active_flag;
