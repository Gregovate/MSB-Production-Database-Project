CREATE OR REPLACE FUNCTION ops.trg_create_work_order_on_repair()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_season_year integer;
  v_container_id integer;
  v_display_name text;
BEGIN
  -- Only act when status is REPAIR, and only on transition into REPAIR
  IF NEW.test_status IS DISTINCT FROM 'REPAIR' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND (OLD.test_status IS NOT DISTINCT FROM NEW.test_status) THEN
    RETURN NEW;
  END IF;

  -- If an OPEN work order already exists for this checklist row, do nothing (idempotent)
  IF EXISTS (
    SELECT 1
    FROM ops.work_order wo
    WHERE wo.display_test_session_id = NEW.display_test_session_id
      AND wo.date_completed IS NULL
  ) THEN
    RETURN NEW;
  END IF;

  -- Pull a little context for nicer notes (safe if null)
  SELECT ts.season_year, ts.container_id
    INTO v_season_year, v_container_id
  FROM ops.test_session ts
  WHERE ts.test_session_id = NEW.test_session_id;

  SELECT d.display_name
    INTO v_display_name
  FROM ref.display d
  WHERE d.display_id = NEW.display_id;

  -- Insert the work order (XOR satisfied: stage_id NULL, work_area_id=49)
  INSERT INTO ops.work_order (
      stage_id,
      work_area_id,
      task_type_id,
      urgency,
      target_year,
      problem,
      notes,
      display_test_session_id,
      display_id,
      display_lor_prop_id
  )
  VALUES (
      NULL,
      49,                         -- Electrical Dept
      10,                         -- Repair
      2,                          -- default urgency (change later if you want)
      v_season_year,              -- season year from test_session
      'Repair needed from seasonal testing',
      trim(both ' ' from concat_ws(' | ',
        concat('Auto-created from testing',
               case when v_season_year is not null then concat(' ', v_season_year) end,
               case when v_container_id is not null then concat(', Container: ', v_container_id) end,
               case when v_display_name is not null then concat(', Display: ', v_display_name) end
        ),
        nullif(btrim(NEW.notes),'')
      )),
      NEW.display_test_session_id,
      NEW.display_id,
      NEW.lor_prop_id
  );

  RETURN NEW;
END;
$function$
