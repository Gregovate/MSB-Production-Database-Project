update ref.container
set location_code = 'Z-FIX LOCATION-UNKNOWN',
    notes = coalesce(notes,'') ||
            case when notes is null or btrim(notes) = '' then '' else E'\n' end ||
            '2026-03-01: TEMP moved to UNKNOWN bucket until UI/go-live cleanup (Greg)'
where container_id = 225;