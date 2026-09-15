/* MSB Setup #167 — finalize assigned Kit inventory coverage after operator assignment review.
   REVIEW BEFORE PRODUCTION.

   Boundary:
   - current task -> Kit assignments are now the reconciliation anchor;
   - current ref.display.container_id remains authoritative physical Display contents;
   - procedure/current-container evidence adds expected Extra Materials only where supported;
   - assigned Kits with no recovered Extra Material evidence get a durable review marker,
     never invented contents;
   - shared spacer stock remains shared stock, while a Kit may also have its own
     explicitly evidenced spacer contents;
   - no physical inventory events and no 2026 Setup Session are created here.
*/
BEGIN;

DO $preflight$
BEGIN
    IF to_regclass('ref.setup_container_extra_material') IS NULL
       OR to_regclass('ref.setup_container_extra_material_review') IS NULL
       OR to_regclass('ref.setup_task_container_support') IS NULL
       OR to_regclass('ref.setup_extra_material') IS NULL THEN
        RAISE EXCEPTION 'Durable #184 Extra Material / Kit assignment foundation is required first';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        JOIN ops.setup_extra_material_inventory_event e
          ON e.setup_container_extra_material_id=cem.setup_container_extra_material_id
        WHERE cem.container_id=63
          AND cem.active_flag
          AND m.material_name='Standard Panel Spacer'
          AND cem.notes LIKE 'Procedure-derived Kit preload v6.%03-Welcome Area-WA%'
    ) THEN
        RAISE EXCEPTION 'Cannot move stale Welcome Area spacer evidence off Container 63 after physical inventory history exists';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Extension Cord' AND active_flag)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Standard Panel Spacer' AND active_flag)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Wood Block' AND active_flag)
       OR NOT EXISTS (SELECT 1 FROM ref.setup_extra_material WHERE material_name='Wood Blocking / Footpad' AND active_flag) THEN
        RAISE EXCEPTION 'Required normalized Extra Material families are missing';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM ref.container c
        WHERE c.container_id=60
          AND c.container_type_id=2
          AND lower(coalesce(c.description,'')) LIKE '%spacer%'
    ) THEN
        RAISE EXCEPTION 'Current Container 60 no longer identifies Elf Choir spacer contents; reconcile before #167 preload';
    END IF;
END
$preflight$;

/* Current Container 63 is Fred Stars. The legacy Welcome Area spacer reference was
   historical Container-number evidence and must not survive as current Fred Stars
   Kit inventory. Shared standard spacer stock is represented below instead. */
UPDATE ref.setup_container_extra_material cem
SET active_flag=false,
    notes=concat_ws(' ', cem.notes,
        '[#167 assignment correction] Current Container 63 is Fred Stars; Welcome Area standard-spacer evidence belongs to shared spacer stock, not this Kit.')
FROM ref.setup_extra_material m
WHERE cem.setup_extra_material_id=m.setup_extra_material_id
  AND cem.container_id=63
  AND cem.active_flag
  AND m.material_name='Standard Panel Spacer'
  AND cem.notes LIKE 'Procedure-derived Kit preload v6.%03-Welcome Area-WA%';

/* Current Production Container identity itself proves that these assigned Festive
   Tree Containers are cord sets. Exact cord count/specification remains unverified. */
WITH seed(container_id, size_text, evidence_note) AS (
    VALUES
        (74, 'Festive Tree east-side cord set',
         'Current Production Container 74 description: Festive Tree Eastside Cords (PS); assigned to Individual Tree Wrap Tasks.'),
        (75, 'Festive Tree west-side cord set',
         'Current Production Container 75 description: Festive Tree Westside Cords (DS); assigned to Individual Tree Wrap Tasks.')
), mat AS (
    SELECT setup_extra_material_id, default_uom
    FROM ref.setup_extra_material
    WHERE material_name='Extension Cord' AND active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, verification_state, notes, active_flag
)
SELECT
    s.container_id, m.setup_extra_material_id, NULL, m.default_uom,
    s.size_text, 'UNVERIFIED',
    '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY] ' || s.evidence_note ||
    ' Exact count/gauge/length remains to verify physically.',
    true
FROM seed s CROSS JOIN mat m
WHERE EXISTS (
    SELECT 1 FROM ref.container c
    WHERE c.container_id=s.container_id AND c.container_type_id=2
)
AND NOT EXISTS (
    SELECT 1 FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=s.container_id
      AND cem.setup_extra_material_id=m.setup_extra_material_id
      AND cem.quantity_uom=m.default_uom
      AND coalesce(lower(btrim(cem.size_text)), '')=lower(btrim(s.size_text))
      AND cem.length_value IS NULL AND cem.length_unit IS NULL
      AND cem.color IS NULL AND cem.active_flag
);

/* Traditional Christmas Kit 105 has explicit current-procedure non-LOR contents
   that were previously retained only as remainder text. */
WITH seed(material_name, expected_quantity, quantity_uom, size_text, evidence_note) AS (
    VALUES
        ('Extension Cord'::text, NULL::numeric, 'EA'::text, 'Traditional Christmas labeled/mixed cord set'::text,
         '23-Traditional Christmas-TC Rev 20260813 explicitly lists multiple labeled and unlabeled power cords in Container C105.'::text),
        ('Wood Block'::text, 3::numeric, 'EA'::text, '4x4'::text,
         '23-Traditional Christmas-TC Rev 20260813: Traditional Kit C105 includes 3 x 4x4 blocking.'::text),
        ('Wood Blocking / Footpad'::text, 2::numeric, 'EA'::text, '2x6'::text,
         '23-Traditional Christmas-TC Rev 20260813: Traditional Kit C105 includes 2 x 2x6 blocking.'::text)
), resolved AS (
    SELECT s.*, m.setup_extra_material_id
    FROM seed s
    JOIN ref.setup_extra_material m ON m.material_name=s.material_name AND m.active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, verification_state, notes, active_flag
)
SELECT
    105, r.setup_extra_material_id, r.expected_quantity, r.quantity_uom,
    r.size_text, 'UNVERIFIED',
    '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY] ' || r.evidence_note,
    true
FROM resolved r
WHERE EXISTS (SELECT 1 FROM ref.container WHERE container_id=105)
AND NOT EXISTS (
    SELECT 1 FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=105
      AND cem.setup_extra_material_id=r.setup_extra_material_id
      AND cem.quantity_uom=r.quantity_uom
      AND coalesce(lower(btrim(cem.size_text)), '')=coalesce(lower(btrim(r.size_text)), '')
      AND cem.length_value IS NULL AND cem.length_unit IS NULL
      AND cem.color IS NULL AND cem.active_flag
);

/* Current Production Container 60 is explicitly named "Elf Choir Kit includes
   spacers". That is current physical identity evidence that this Kit contains the
   normalized Standard Panel Spacer family. Exact spacer size/count remain unknown,
   so preload one UNVERIFIED expected-content row rather than inventing quantity. */
WITH mat AS (
    SELECT setup_extra_material_id, default_uom
    FROM ref.setup_extra_material
    WHERE material_name='Standard Panel Spacer' AND active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, verification_state, notes, active_flag
)
SELECT
    60, m.setup_extra_material_id, NULL, m.default_uom,
    'Elf Choir Kit spacer set — size/count unverified', 'UNVERIFIED',
    '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY] Current Production Container 60 description is "Elf Choir Kit includes spacers". Spacer family is therefore explicit current Kit content; exact size and count require physical verification.',
    true
FROM mat m
WHERE NOT EXISTS (
    SELECT 1 FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=60
      AND cem.setup_extra_material_id=m.setup_extra_material_id
      AND cem.active_flag
);

/* Shared standard spacer inventory is countable stock. Current Production identifies
   Containers 123/124/125/128 as Display Spacers 21. Legacy 21-vs-22 wording is one
   normalized standard class; quantities remain uncounted until physical inventory. */
WITH seed(container_id) AS (VALUES (123),(124),(125),(128)), mat AS (
    SELECT setup_extra_material_id, default_uom
    FROM ref.setup_extra_material
    WHERE material_name='Standard Panel Spacer' AND active_flag
)
INSERT INTO ref.setup_container_extra_material(
    container_id, setup_extra_material_id, expected_quantity, quantity_uom,
    size_text, verification_state, notes, active_flag
)
SELECT
    s.container_id, m.setup_extra_material_id, NULL, m.default_uom,
    'standard panel spacer ~21-22 in', 'UNVERIFIED',
    '[#167 SHARED SPACER STOCK] Current Production Container description identifies shared standard Display Spacer stock. Physical count remains to verify.',
    true
FROM seed s CROSS JOIN mat m
WHERE EXISTS (SELECT 1 FROM ref.container c WHERE c.container_id=s.container_id)
AND NOT EXISTS (
    SELECT 1 FROM ref.setup_container_extra_material cem
    WHERE cem.container_id=s.container_id
      AND cem.setup_extra_material_id=m.setup_extra_material_id
      AND cem.quantity_uom=m.default_uom
      AND coalesce(lower(btrim(cem.size_text)), '')='standard panel spacer ~21-22 in'
      AND cem.length_value IS NULL AND cem.length_unit IS NULL
      AND cem.color IS NULL AND cem.active_flag
);

INSERT INTO ref.setup_container_extra_material_review(container_id, unverified_items_text)
SELECT 129,
       '[#167 SHARED SPACER STOCK]\n- Current Production identifies Container 129 as Misc Size Spacers.\n- Physical sizes and quantities must be normalized during inventory; do not flatten these into the standard panel-spacer class.'
WHERE EXISTS (SELECT 1 FROM ref.container WHERE container_id=129)
ON CONFLICT ON CONSTRAINT setup_container_extra_material_review_pkey DO UPDATE
SET unverified_items_text = CASE
    WHEN ref.setup_container_extra_material_review.unverified_items_text LIKE '%[#167 SHARED SPACER STOCK]%'
        THEN ref.setup_container_extra_material_review.unverified_items_text
    ELSE ref.setup_container_extra_material_review.unverified_items_text || E'\n\n' || EXCLUDED.unverified_items_text
END;

/* Every assigned physical Kit must have a meaningful inventory surface. If no
   normalized Extra Material/remainder exists, current Display contents are still
   authoritative. Truly empty reconstruction coverage gets an explicit review marker
   instead of silently appearing as an empty Kit. */
INSERT INTO ref.setup_container_extra_material_review(container_id, unverified_items_text)
SELECT
    c.container_id,
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM ref.display d
            LEFT JOIN ref.display_status ds ON ds.display_status_id=d.display_status_id
            WHERE d.container_id=c.container_id
              AND upper(coalesce(ds.display_status_name,'')) <> 'RECYCLED'
        ) THEN
            '[#167 ASSIGNED KIT COVERAGE]\n- Current physical Display contents are authoritative and are shown separately.\n- No additional normalized Extra Material inventory was recovered from available procedure evidence.\n- Confirm during physical inventory whether any non-Display contents are also present.'
        ELSE
            '[#167 ASSIGNED KIT COVERAGE]\n- This current assigned Kit has no normalized Extra Material inventory recovered from the available procedure set.\n- Physical Kit contents require field/warehouse verification; unknown does not mean empty.'
    END
FROM ref.container c
WHERE c.container_type_id=2
  AND EXISTS (
      SELECT 1 FROM ref.setup_task_container_support tc
      WHERE tc.container_id=c.container_id AND tc.relationship_type='KIT'
  )
  AND NOT EXISTS (
      SELECT 1 FROM ref.setup_container_extra_material cem
      WHERE cem.container_id=c.container_id AND cem.active_flag
  )
  AND NOT EXISTS (
      SELECT 1 FROM ref.setup_container_extra_material_review r
      WHERE r.container_id=c.container_id
  )
ON CONFLICT DO NOTHING;

DO $proof$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=63
          AND cem.active_flag
          AND m.material_name='Standard Panel Spacer'
          AND cem.notes LIKE 'Procedure-derived Kit preload v6.%03-Welcome Area-WA%'
    ) THEN
        RAISE EXCEPTION 'Stale Welcome Area spacer evidence still appears as current Fred Stars Kit inventory';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id=60
          AND cem.active_flag
          AND m.material_name='Standard Panel Spacer'
          AND cem.expected_quantity IS NULL
          AND cem.verification_state='UNVERIFIED'
          AND cem.notes LIKE '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY]%Elf Choir Kit includes spacers%'
    ) THEN
        RAISE EXCEPTION 'Current Container 60 Elf Choir spacer evidence was not normalized into Kit expected contents';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM ref.container c
        WHERE c.container_type_id=2
          AND EXISTS (
              SELECT 1 FROM ref.setup_task_container_support tc
              WHERE tc.container_id=c.container_id AND tc.relationship_type='KIT'
          )
          AND NOT EXISTS (
              SELECT 1 FROM ref.setup_container_extra_material cem
              WHERE cem.container_id=c.container_id AND cem.active_flag
          )
          AND NOT EXISTS (
              SELECT 1 FROM ref.setup_container_extra_material_review r
              WHERE r.container_id=c.container_id
          )
          AND NOT EXISTS (
              SELECT 1
              FROM ref.display d
              LEFT JOIN ref.display_status ds ON ds.display_status_id=d.display_status_id
              WHERE d.container_id=c.container_id
                AND upper(coalesce(ds.display_status_name,'')) <> 'RECYCLED'
          )
    ) THEN
        RAISE EXCEPTION 'One or more assigned Kits still have no Display contents, normalized Extra Material inventory, or durable review state';
    END IF;

    IF (SELECT count(*)
        FROM ref.setup_container_extra_material cem
        JOIN ref.setup_extra_material m USING (setup_extra_material_id)
        WHERE cem.container_id IN (123,124,125,128)
          AND cem.active_flag
          AND m.material_name='Standard Panel Spacer') <> 4 THEN
        RAISE EXCEPTION 'Expected four shared standard-spacer stock rows for Containers 123/124/125/128';
    END IF;

    IF EXISTS (
        SELECT 1 FROM ops.setup_extra_material_inventory_event e
        JOIN ref.setup_container_extra_material cem
          ON cem.setup_container_extra_material_id=e.setup_container_extra_material_id
        WHERE cem.notes LIKE '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY]%'
           OR cem.notes LIKE '[#167 SHARED SPACER STOCK]%'
    ) THEN
        RAISE EXCEPTION 'Kit/spacer reconciliation unexpectedly created physical inventory history';
    END IF;

    IF EXISTS (SELECT 1 FROM ops.setup_session WHERE season_year=2026) THEN
        RAISE EXCEPTION '#167 assigned-Kit inventory reconciliation unexpectedly created a 2026 Setup Session';
    END IF;
END
$proof$;

COMMIT;

SELECT
    (SELECT count(DISTINCT c.container_id)
     FROM ref.container c
     JOIN ref.setup_task_container_support tc ON tc.container_id=c.container_id
     WHERE c.container_type_id=2 AND tc.relationship_type='KIT') AS assigned_kit_count,
    (SELECT count(*) FROM ref.setup_container_extra_material
     WHERE active_flag AND notes LIKE '[#167 ASSIGNMENT-DRIVEN KIT INVENTORY]%') AS assignment_driven_inventory_rows,
    (SELECT count(*) FROM ref.setup_container_extra_material_review
     WHERE unverified_items_text LIKE '%[#167 ASSIGNED KIT COVERAGE]%') AS assigned_kits_with_explicit_inventory_review,
    (SELECT count(*) FROM ref.setup_container_extra_material
     WHERE active_flag AND notes LIKE '[#167 SHARED SPACER STOCK]%') AS shared_spacer_stock_rows;
