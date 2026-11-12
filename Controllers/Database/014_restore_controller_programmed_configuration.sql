/* ============================================================================
Controller Inventory: restore current programmed controller configuration
Issue: #110
Recovery source: Controller Inventory & Testing 2026(8).xlsx

The first permanent promotion preserved controller identity and Display
relationships but did not carry forward the physical controller's current
Network/UID/address configuration. This migration restores that operational
configuration without making it physical identity.

Operator rule:
  First UID + UID Count are entered; ending UID is calculated.
  Unit IDs are stored numerically and displayed as uppercase hexadecimal.
  Duplicate Network/UID ranges on different physical controllers are valid.
============================================================================ */

BEGIN;

DO $preflight$
DECLARE v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM ref.controller;
    IF v_count <> 177 THEN
        RAISE EXCEPTION 'Expected 177 permanent controllers; found %', v_count;
    END IF;
    IF (SELECT min(controller_id) FROM ref.controller) <> 1001
       OR (SELECT max(controller_id) FROM ref.controller) <> 1177 THEN
        RAISE EXCEPTION 'Expected permanent Controller IDs 1001..1177';
    END IF;
END
$preflight$;

ALTER TABLE ref.controller_model
    ADD COLUMN IF NOT EXISTS lor_uid_capacity smallint;

COMMENT ON COLUMN ref.controller_model.lor_uid_capacity IS
    'Maximum number of contiguous LOR Unit IDs this model may use. NULL means not applicable or not yet established.';

UPDATE ref.controller_model
SET lor_uid_capacity = CASE model_code
    WHEN 'CTB32' THEN 1
    WHEN 'CTB04Dg3' THEN 1
    WHEN 'CMB24D' THEN 1
    WHEN 'CF50D' THEN 1
    WHEN 'CCB100' THEN 2
    WHEN 'Pixie2D' THEN 2
    WHEN 'Pixie4D' THEN 4
    WHEN 'Pixie8D' THEN 8
    WHEN 'Pixie16D' THEN 16
    ELSE lor_uid_capacity
END
WHERE model_code IN (
    'CTB32','CTB04Dg3','CMB24D','CF50D','CCB100',
    'Pixie2D','Pixie4D','Pixie8D','Pixie16D'
);

ALTER TABLE ref.controller_model
    DROP CONSTRAINT IF EXISTS ck_controller_model_lor_uid_capacity;
ALTER TABLE ref.controller_model
    ADD CONSTRAINT ck_controller_model_lor_uid_capacity CHECK (
        lor_uid_capacity IS NULL OR lor_uid_capacity BETWEEN 1 AND 240
    );

ALTER TABLE ref.controller
    ADD COLUMN IF NOT EXISTS lor_network text,
    ADD COLUMN IF NOT EXISTS lor_uid_start smallint,
    ADD COLUMN IF NOT EXISTS lor_uid_count smallint,
    ADD COLUMN IF NOT EXISTS management_ip inet,
    ADD COLUMN IF NOT EXISTS programmed_config_verification_state text NOT NULL DEFAULT 'UNKNOWN',
    ADD COLUMN IF NOT EXISTS programmed_config_verified_at timestamptz,
    ADD COLUMN IF NOT EXISTS programmed_config_verified_by_person_id integer,
    ADD COLUMN IF NOT EXISTS programmed_config_source_note text;

ALTER TABLE ref.controller DROP COLUMN IF EXISTS lor_uid_end;
ALTER TABLE ref.controller
    ADD COLUMN lor_uid_end smallint GENERATED ALWAYS AS (
        CASE
            WHEN lor_uid_start IS NULL OR lor_uid_count IS NULL THEN NULL
            ELSE (lor_uid_start + lor_uid_count - 1)::smallint
        END
    ) STORED;

COMMENT ON COLUMN ref.controller.lor_network IS
    'Current programmed LOR network; mutable configuration, not controller identity.';
COMMENT ON COLUMN ref.controller.lor_uid_start IS
    'Current first LOR Unit ID stored numerically 1..240; application renders hexadecimal.';
COMMENT ON COLUMN ref.controller.lor_uid_count IS
    'Number of contiguous LOR Unit IDs currently programmed; operator enters ordinary decimal count.';
COMMENT ON COLUMN ref.controller.lor_uid_end IS
    'Calculated inclusive ending Unit ID from First UID + UID Count - 1.';
COMMENT ON COLUMN ref.controller.management_ip IS
    'Current management IP when applicable; mutable configuration, not controller identity.';

ALTER TABLE ref.controller
    DROP CONSTRAINT IF EXISTS fk_controller_programmed_config_verified_by;
ALTER TABLE ref.controller
    ADD CONSTRAINT fk_controller_programmed_config_verified_by
        FOREIGN KEY (programmed_config_verified_by_person_id)
        REFERENCES ref.person(person_id);

ALTER TABLE ref.controller
    DROP CONSTRAINT IF EXISTS ck_controller_programmed_config_state;
ALTER TABLE ref.controller
    ADD CONSTRAINT ck_controller_programmed_config_state CHECK (
        programmed_config_verification_state IN ('UNKNOWN','RECORDED_UNVERIFIED','VERIFIED')
    );

ALTER TABLE ref.controller
    DROP CONSTRAINT IF EXISTS ck_controller_lor_config_all_or_none;
ALTER TABLE ref.controller
    ADD CONSTRAINT ck_controller_lor_config_all_or_none CHECK (
        (lor_network IS NULL AND lor_uid_start IS NULL AND lor_uid_count IS NULL)
        OR
        (nullif(btrim(lor_network), '') IS NOT NULL
         AND lor_uid_start IS NOT NULL
         AND lor_uid_count IS NOT NULL)
    );

ALTER TABLE ref.controller
    DROP CONSTRAINT IF EXISTS ck_controller_lor_uid_start;
ALTER TABLE ref.controller
    ADD CONSTRAINT ck_controller_lor_uid_start CHECK (
        lor_uid_start IS NULL OR lor_uid_start BETWEEN 1 AND 240
    );

ALTER TABLE ref.controller
    DROP CONSTRAINT IF EXISTS ck_controller_lor_uid_count;
ALTER TABLE ref.controller
    ADD CONSTRAINT ck_controller_lor_uid_count CHECK (
        lor_uid_count IS NULL OR lor_uid_count BETWEEN 1 AND 240
    );

ALTER TABLE ref.controller
    DROP CONSTRAINT IF EXISTS ck_controller_lor_uid_end;
ALTER TABLE ref.controller
    ADD CONSTRAINT ck_controller_lor_uid_end CHECK (
        lor_uid_end IS NULL OR lor_uid_end BETWEEN 1 AND 240
    );

CREATE OR REPLACE FUNCTION ref.validate_controller_lor_configuration()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE v_capacity smallint;
BEGIN
    IF NEW.lor_uid_start IS NULL AND NEW.lor_uid_count IS NULL AND NEW.lor_network IS NULL THEN
        RETURN NEW;
    END IF;
    IF NEW.lor_uid_start IS NULL OR NEW.lor_uid_count IS NULL
       OR nullif(btrim(NEW.lor_network), '') IS NULL THEN
        RAISE EXCEPTION 'LOR Network, First UID, and UID Count must be supplied together';
    END IF;
    IF NEW.lor_uid_start < 1 OR NEW.lor_uid_start > 240 THEN
        RAISE EXCEPTION 'LOR First UID must be between hex 01 and F0';
    END IF;
    IF NEW.lor_uid_count < 1 THEN
        RAISE EXCEPTION 'LOR UID Count must be at least 1';
    END IF;
    IF NEW.lor_uid_start + NEW.lor_uid_count - 1 > 240 THEN
        RAISE EXCEPTION 'LOR UID range exceeds hex F0';
    END IF;

    SELECT lor_uid_capacity INTO v_capacity
    FROM ref.controller_model
    WHERE controller_model_id = NEW.controller_model_id;

    IF v_capacity IS NULL THEN
        RAISE EXCEPTION 'Selected controller model has no LOR UID capacity';
    END IF;
    IF NEW.lor_uid_count > v_capacity THEN
        RAISE EXCEPTION 'LOR UID Count % exceeds selected model capacity %',
            NEW.lor_uid_count, v_capacity;
    END IF;
    RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_controller_validate_lor_configuration ON ref.controller;
CREATE TRIGGER trg_controller_validate_lor_configuration
BEFORE INSERT OR UPDATE OF controller_model_id, lor_network, lor_uid_start, lor_uid_count
ON ref.controller
FOR EACH ROW EXECUTE FUNCTION ref.validate_controller_lor_configuration();

CREATE OR REPLACE FUNCTION ref.validate_controller_model_uid_capacity()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE v_max_count smallint;
BEGIN
    SELECT max(lor_uid_count) INTO v_max_count
    FROM ref.controller
    WHERE controller_model_id = NEW.controller_model_id
      AND lor_uid_count IS NOT NULL;

    IF v_max_count IS NOT NULL
       AND (NEW.lor_uid_capacity IS NULL OR NEW.lor_uid_capacity < v_max_count) THEN
        RAISE EXCEPTION 'Model LOR UID capacity cannot be lower than existing configured UID Count %',
            v_max_count;
    END IF;
    RETURN NEW;
END
$$;

DROP TRIGGER IF EXISTS trg_controller_model_validate_uid_capacity ON ref.controller_model;
CREATE TRIGGER trg_controller_model_validate_uid_capacity
BEFORE UPDATE OF lor_uid_capacity ON ref.controller_model
FOR EACH ROW EXECUTE FUNCTION ref.validate_controller_model_uid_capacity();

CREATE TEMP TABLE pg_temp.controller_config_recovery (
    controller_id bigint PRIMARY KEY,
    expected_model_code text NOT NULL,
    lor_network text,
    lor_uid_start smallint,
    lor_uid_count smallint,
    management_ip text
) ON COMMIT DROP;

INSERT INTO pg_temp.controller_config_recovery
(controller_id, expected_model_code, lor_network, lor_uid_start, lor_uid_count, management_ip)
VALUES
(1001,'CTB32','Aux E',128,1,NULL),
(1002,'CTB32','Aux E',129,1,NULL),
(1003,'CTB32','Aux E',130,1,NULL),
(1004,'CTB32','Aux E',131,1,NULL),
(1005,'CTB32','Aux J',38,1,NULL),
(1006,'CTB32','Aux J',39,1,NULL),
(1007,'CTB32','Aux J',48,1,NULL),
(1008,'CTB32','Aux J',49,1,NULL),
(1009,'CTB32','Aux N',73,1,NULL),
(1010,'CTB32','Regular',1,1,NULL),
(1011,'CTB32','Regular',2,1,NULL),
(1012,'CTB32','Regular',122,1,NULL),
(1013,'CTB32','Regular',11,1,NULL),
(1014,'CTB32','Regular',103,1,NULL),
(1015,'Pixie2D','Aux D',1,2,NULL),
(1016,'Pixie2D','Aux D',3,2,NULL),
(1017,'HolidayCoro Flex 48',NULL,NULL,NULL,'10.10.5.10'),
(1018,'CTB04Dg3','Regular',61,1,NULL),
(1019,'CTB32','Regular',100,1,NULL),
(1020,'CTB04Dg3','Regular',102,1,NULL),
(1021,'CTB32','Regular',112,1,NULL),
(1022,'CTB32','Regular',113,1,NULL),
(1023,'CTB32','Aux B',97,1,NULL),
(1024,'CTB32','Regular',16,1,NULL),
(1025,'CTB32','Regular',26,1,NULL),
(1026,'CTB32','Regular',27,1,NULL),
(1027,'CTB04Dg3','Regular',36,1,NULL),
(1028,'CTB32','Regular',59,1,NULL),
(1029,'CTB32','Regular',60,1,NULL),
(1030,'CTB32','Regular',66,1,NULL),
(1031,'CTB04Dg3','Regular',9,1,NULL),
(1032,'CTB04Dg3','Regular',9,1,NULL),
(1033,'CTB32','Aux C',98,1,NULL),
(1034,'Pixie8D','Aux D',16,8,NULL),
(1035,'Pixie8D','Aux D',24,8,NULL),
(1036,'CTB32','Aux J',40,1,NULL),
(1037,'CTB32','Director',1,1,NULL),
(1038,'CTB32','Regular',120,1,NULL),
(1039,'CTB04Dg3','Regular',9,1,NULL),
(1040,'CF50D','Regular',234,1,NULL),
(1041,'CF50D','Regular',234,1,NULL),
(1042,'CF50D','Regular',235,1,NULL),
(1043,'CF50D','Regular',235,1,NULL),
(1044,'CF50D','Regular',236,1,NULL),
(1045,'CF50D','Regular',236,1,NULL),
(1046,'CF50D','Regular',237,1,NULL),
(1047,'CF50D','Regular',237,1,NULL),
(1048,'CTB32','Aux I',32,1,NULL),
(1049,'CTB32','Aux I',33,1,NULL),
(1050,'CTB32','Aux I',177,1,NULL),
(1051,'CTB32','Aux I',178,1,NULL),
(1052,'CTB32','Aux I',179,1,NULL),
(1053,'CTB32','Aux I',180,1,NULL),
(1054,'CTB32','Aux I',181,1,NULL),
(1055,'CTB32','Aux I',182,1,NULL),
(1056,'CTB32','Aux I',183,1,NULL),
(1057,'CTB32','Aux I',184,1,NULL),
(1058,'CTB32','Aux I',186,1,NULL),
(1059,'CTB32','Aux I',187,1,NULL),
(1060,'CTB32','Aux I',188,1,NULL),
(1061,'CTB32','Aux I',189,1,NULL),
(1062,'CTB32','Regular',6,1,NULL),
(1063,'CF50D','Regular',225,1,NULL),
(1064,'CF50D','Regular',226,1,NULL),
(1065,'CF50D','Regular',227,1,NULL),
(1066,'CF50D','Regular',228,1,NULL),
(1067,'CF50D','Regular',229,1,NULL),
(1068,'CF50D','Regular',230,1,NULL),
(1069,'CF50D','Regular',231,1,NULL),
(1070,'CF50D','Regular',232,1,NULL),
(1071,'Pixie2D','Director',1,2,NULL),
(1072,'CTB32','Regular',10,1,NULL),
(1073,'CTB32','Regular',3,1,NULL),
(1074,'CTB04Dg3','Regular',99,1,NULL),
(1075,'CTB32','Regular',114,1,NULL),
(1076,'CTB32','Regular',115,1,NULL),
(1077,'CTB32','Aux B',96,1,NULL),
(1078,'CTB32','Aux C',109,1,NULL),
(1079,'CTB32','Aux C',110,1,NULL),
(1080,'CTB32','Aux D',106,1,NULL),
(1081,'CTB32','Aux D',107,1,NULL),
(1082,'CTB32','Aux D',108,1,NULL),
(1083,'CTB04Dg3','Regular',12,1,NULL),
(1084,'CTB32','Regular',14,1,NULL),
(1085,'CTB32','Regular',58,1,NULL),
(1086,'CTB04Dg3','Regular',7,1,NULL),
(1087,'CTB32','Regular',117,1,NULL),
(1088,'CTB32','Regular',121,1,NULL),
(1089,'CTB04Dg3','Regular',9,1,NULL),
(1090,'Pixie8D','Aux I',80,8,NULL),
(1091,'Pixie8D','Aux I',96,8,NULL),
(1092,'Pixie8D','Aux I',104,8,NULL),
(1093,'Pixie8D','Aux I',128,8,NULL),
(1094,'Pixie8D','Aux I',136,8,NULL),
(1095,'Pixie16D','Aux N',48,16,NULL),
(1096,'Pixie2D','Aux O',32,1,NULL),
(1097,'Pixie2D','Aux O',32,1,NULL),
(1098,'Pixie2D','Aux O',32,1,NULL),
(1099,'Pixie2D','Aux O',32,1,NULL),
(1100,'Pixie2D','Aux O',34,1,NULL),
(1101,'Pixie2D','Aux O',34,1,NULL),
(1102,'Pixie2D','Aux O',34,1,NULL),
(1103,'Pixie2D','Aux O',34,1,NULL),
(1104,'Pixie2D','Aux O',36,1,NULL),
(1105,'Pixie2D','Aux O',36,1,NULL),
(1106,'Pixie2D','Aux O',36,1,NULL),
(1107,'Pixie2D','Aux O',36,1,NULL),
(1108,'Pixie2D','Aux O',38,1,NULL),
(1109,'Pixie2D','Aux O',38,1,NULL),
(1110,'Pixie2D','Aux O',38,1,NULL),
(1111,'Pixie2D','Aux O',38,1,NULL),
(1112,'CTB32','Regular',34,1,NULL),
(1113,'CTB32','Regular',34,1,NULL),
(1114,'CTB32','Regular',35,1,NULL),
(1115,'CTB32','Regular',62,1,NULL),
(1116,'CTB32','Regular',193,1,NULL),
(1117,'Pixie16D','Aux C',80,16,NULL),
(1118,'Pixie2D','Aux E',145,2,NULL),
(1119,'Pixie2D','Aux N',64,1,NULL),
(1120,'CCB100','Aux N',66,2,NULL),
(1121,'CCB100','Aux N',68,2,NULL),
(1122,'CTB32','Regular',33,1,NULL),
(1123,'CTB32','Regular',65,1,NULL),
(1124,'CTB32','Regular',123,1,NULL),
(1125,'CTB04Dg3','Regular',144,1,NULL),
(1126,'CTB04Dg3','Regular',145,1,NULL),
(1127,'CTB04Dg3','Regular',146,1,NULL),
(1128,'CTB04Dg3','Regular',147,1,NULL),
(1129,'CTB32','Aux C',98,1,NULL),
(1130,'CTB32','Aux D',101,1,NULL),
(1131,'PixCon16',NULL,NULL,NULL,'10.10.5.11'),
(1132,'CTB04Dg3','Regular',5,1,NULL),
(1133,'CTB32','Regular',196,1,NULL),
(1134,'Pixie4D','Aux A',33,4,NULL),
(1135,'Pixie4D','Aux A',33,4,NULL),
(1136,'Pixie4D','Aux A',33,4,NULL),
(1137,'CTB32','Aux E',124,1,NULL),
(1138,'Pixie8D','Aux I',88,8,NULL),
(1139,'Pixie8D','Aux I',112,8,NULL),
(1140,'Pixie8D','Aux I',120,8,NULL),
(1141,'Pixie4D','Aux N',33,4,NULL),
(1142,'Pixie4D','Aux N',33,4,NULL),
(1143,'PixCon16',NULL,NULL,NULL,'10.10.5.15'),
(1144,'PixCon16',NULL,NULL,NULL,'10.10.5.16'),
(1145,'CTB32','Regular',9,1,NULL),
(1146,'CTB04Dg3','Regular',9,1,NULL),
(1147,'CTB32','Regular',194,1,NULL),
(1148,'CTB32','Regular',195,1,NULL),
(1149,'PixCon16',NULL,NULL,NULL,'10.10.5.17'),
(1150,'CTB04Dg3','Regular',53,1,NULL),
(1151,'CTB32','Regular',119,1,NULL),
(1152,'CTB04Dg3','Regular',148,1,NULL),
(1153,'Pixie2D','Aux A',2,2,NULL),
(1154,'Pixie2D','Aux F',48,1,NULL),
(1155,'Pixie2D','Aux F',48,1,NULL),
(1156,'Pixie2D','Aux F',50,1,NULL),
(1157,'Pixie2D','Aux F',50,1,NULL),
(1158,'Pixie2D','Aux F',52,1,NULL),
(1159,'Pixie2D','Aux F',52,1,NULL),
(1160,'Pixie2D','Aux F',54,1,NULL),
(1161,'Pixie2D','Aux F',54,1,NULL),
(1162,'Pixie2D','Aux F',65,1,NULL),
(1163,'Pixie2D','Aux H',1,2,NULL),
(1164,'Pixie2D','Aux H',3,2,NULL),
(1165,'CTB32','Aux H',5,1,NULL),
(1166,'Pixie2D','Aux I',37,2,NULL),
(1167,'HolidayCoro Flex 48',NULL,NULL,NULL,'10.10.5.12'),
(1168,'PixCon16',NULL,NULL,NULL,'10.10.5.19'),
(1169,'PixCon16',NULL,NULL,NULL,'10.10.5.18'),
(1170,'CMB24D','Regular',16,1,NULL),
(1171,'CF50D','Regular',24,1,NULL),
(1172,'CF50D','Regular',25,1,NULL),
(1173,'CF50D','Regular',25,1,NULL),
(1174,'CTB32','Regular',63,1,NULL),
(1175,'CTB32','Regular',125,1,NULL),
(1176,'PixCon16',NULL,NULL,NULL,'10.10.5.20'),
(1177,'CTB32','Regular',57,1,NULL);

DO $mapping_preflight$
DECLARE v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM pg_temp.controller_config_recovery;
    IF v_count <> 177 THEN
        RAISE EXCEPTION 'Recovery mapping must contain 177 rows; found %', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM pg_temp.controller_config_recovery r
    LEFT JOIN ref.controller c ON c.controller_id = r.controller_id
    LEFT JOIN ref.controller_model m ON m.controller_model_id = c.controller_model_id
    WHERE c.controller_id IS NULL OR m.model_code IS DISTINCT FROM r.expected_model_code;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Recovery mapping has % Controller ID/model mismatches', v_count;
    END IF;

    SELECT count(*) INTO v_count
    FROM pg_temp.controller_config_recovery r
    JOIN ref.controller c ON c.controller_id = r.controller_id
    JOIN ref.controller_model m ON m.controller_model_id = c.controller_model_id
    WHERE r.lor_uid_count IS NOT NULL
      AND (m.lor_uid_capacity IS NULL
           OR r.lor_uid_count > m.lor_uid_capacity
           OR r.lor_uid_start < 1
           OR r.lor_uid_start + r.lor_uid_count - 1 > 240);
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Recovery mapping has % invalid LOR UID configurations', v_count;
    END IF;
END
$mapping_preflight$;

UPDATE ref.controller c
SET lor_network = r.lor_network,
    lor_uid_start = r.lor_uid_start,
    lor_uid_count = r.lor_uid_count,
    management_ip = CASE WHEN r.management_ip IS NULL THEN NULL ELSE r.management_ip::inet END,
    programmed_config_verification_state = 'RECORDED_UNVERIFIED',
    programmed_config_verified_at = NULL,
    programmed_config_verified_by_person_id = NULL,
    programmed_config_source_note =
        'Recovered from Controller Inventory & Testing 2026(8).xlsx; original bootstrap configuration evidence; physical verification pending'
FROM pg_temp.controller_config_recovery r
WHERE r.controller_id = c.controller_id;

DO $postflight$
DECLARE v_count integer;
BEGIN
    SELECT count(*) INTO v_count FROM ref.controller WHERE lor_uid_start IS NOT NULL;
    IF v_count <> 168 THEN
        RAISE EXCEPTION 'Expected 168 restored LOR UID configurations; found %', v_count;
    END IF;
    SELECT count(*) INTO v_count FROM ref.controller WHERE management_ip IS NOT NULL;
    IF v_count <> 9 THEN
        RAISE EXCEPTION 'Expected 9 restored management IP values; found %', v_count;
    END IF;
    SELECT count(*) INTO v_count
    FROM ref.controller
    WHERE programmed_config_verification_state = 'RECORDED_UNVERIFIED';
    IF v_count <> 177 THEN
        RAISE EXCEPTION 'Expected 177 recorded-unverified programmed configurations; found %', v_count;
    END IF;
END
$postflight$;

COMMIT;

SELECT
    count(*) AS controllers,
    count(*) FILTER (WHERE lor_uid_start IS NOT NULL) AS lor_uid_configured,
    count(*) FILTER (WHERE management_ip IS NOT NULL) AS management_ip_configured,
    count(*) FILTER (WHERE programmed_config_verification_state='RECORDED_UNVERIFIED') AS config_recorded_unverified
FROM ref.controller;

SELECT
    c.controller_id,
    m.model_code,
    c.lor_network,
    upper(lpad(to_hex(c.lor_uid_start), 2, '0')) AS first_uid,
    c.lor_uid_count,
    upper(lpad(to_hex(c.lor_uid_end), 2, '0')) AS last_uid,
    host(c.management_ip) AS management_ip,
    c.programmed_config_verification_state
FROM ref.controller c
JOIN ref.controller_model m ON m.controller_model_id = c.controller_model_id
WHERE c.controller_id IN (
    1015,1016,1058,1059,1060,1061,1112,1113,
    1134,1135,1136,1141,1142,1143,1144,1163,1164,1176
)
ORDER BY c.controller_id;
