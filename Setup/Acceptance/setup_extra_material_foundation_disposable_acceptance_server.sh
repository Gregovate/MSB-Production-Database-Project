#!/usr/bin/env bash
set -euo pipefail

# Issue #167 — current-Production disposable Extra Material acceptance.
# Authority: MSB-Server-Management PostgreSQL_Disposable_Acceptance_Standard.md.
# Production PostgreSQL is pg_dump + SELECT only; candidate writes are disposable only.

PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
IMAGE="postgis/postgis:16-3.5"
NETWORK="msb-stack_default"
TEST_DB="msb_setup_167_acceptance"
BUNDLE_DIR="${1:?bundle directory is required}"
CANDIDATE_SHA="${2:?candidate SHA is required}"
STAMP="$(date +%Y%m%dT%H%M%S)"
TEST_CONTAINER="msb-setup-167-acceptance-${$}"
TEST_PASSWORD="setup-167-${$}-$(date +%s)"
DUMP_FILE="/tmp/msb-setup-167-production-${STAMP}-${$}.dump"
REPORT_DIR="$HOME/setup-acceptance-reports"
REPORT="$REPORT_DIR/Setup_167_Extra_Material_Disposable_${STAMP}.txt"

M032="$BUNDLE_DIR/Setup/Database/032_add_setup_extra_material_schema.sql"
M033="$BUNDLE_DIR/Setup/Database/033_add_setup_extra_material_manager_commands.sql"
M034="$BUNDLE_DIR/Setup/Database/034_add_setup_extra_material_container_commands.sql"
M035="$BUNDLE_DIR/Setup/Database/035_add_setup_extra_material_inventory_commands.sql"
M036="$BUNDLE_DIR/Setup/Database/036_seed_setup_extra_material_catalog.sql"
M037="$BUNDLE_DIR/Setup/Database/037_harden_setup_extra_material_duplicate_rows.sql"
M038="$BUNDLE_DIR/Setup/Database/038_preload_setup_extra_material_known_evidence.sql"
M043="$BUNDLE_DIR/Setup/Database/043_preload_setup_kit_inventory_and_tpost_stock.sql"
M044="$BUNDLE_DIR/Setup/Database/044_preload_elf_choir_tpost_requirement.sql"
M045="$BUNDLE_DIR/Setup/Database/045_preload_reviewed_kit_assignments.sql"
M046="$BUNDLE_DIR/Setup/Database/046_preload_explicit_tpost_requirements.sql"
M047="$BUNDLE_DIR/Setup/Database/047_finalize_assigned_kit_inventory_coverage.sql"
M048="$BUNDLE_DIR/Setup/Database/048_complete_tpost_requirements_and_stock_variants.sql"
PRELOAD_VALIDATION="$BUNDLE_DIR/Setup/Acceptance/setup_extra_material_preload_disposable_validation.sql"
VALIDATION="$BUNDLE_DIR/Setup/Acceptance/setup_extra_material_foundation_disposable_validation.sql"
PROD_BEFORE=""

mkdir -p "$REPORT_DIR"
exec > >(tee "$REPORT") 2>&1

echo "========== SETUP #167 EXTRA MATERIAL DISPOSABLE ACCEPTANCE =========="
echo "Candidate SHA: $CANDIDATE_SHA"
echo "Report:        $REPORT"
echo "Production DB: pg_dump + SELECT only"
echo "Test writes:   disposable PostgreSQL clone only"
echo

prod_fingerprint() {
    sudo docker exec "$PROD_CONTAINER" \
        psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
            SELECT md5(
                coalesce((SELECT string_agg(row_to_json(t)::text, '' ORDER BY t.setup_task_id) FROM ref.setup_task t), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(d)::text, '' ORDER BY d.setup_task_id, d.prerequisite_setup_task_id) FROM ref.setup_task_dependency d), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(td)::text, '' ORDER BY td.setup_task_id, td.display_id) FROM ref.setup_task_display td), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tc)::text, '' ORDER BY tc.setup_task_id, tc.container_id) FROM ref.setup_task_container_support tc), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(tr)::text, '' ORDER BY tr.setup_task_id, tr.setup_resource_id) FROM ref.setup_task_resource tr), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(s)::text, '' ORDER BY s.setup_session_id) FROM ops.setup_session s), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(st)::text, '' ORDER BY st.setup_session_task_id) FROM ops.setup_session_task st), '') || '|' ||
                coalesce((SELECT string_agg(row_to_json(me)::text, '' ORDER BY me.setup_movement_event_id) FROM ops.setup_movement_event me), '')
            );
        "
}

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e
    echo
    echo "--- Disposable cleanup ---"
    sudo docker rm -f "$TEST_CONTAINER" >/dev/null 2>&1 || true
    rm -f "$DUMP_FILE" >/dev/null 2>&1 || true
    rm -rf "$BUNDLE_DIR" >/dev/null 2>&1 || true

    echo "--- Production Setup fingerprint after-check ---"
    if [[ -n "$PROD_BEFORE" ]]; then
        PROD_AFTER="$(prod_fingerprint 2>/dev/null)"
        echo "Before: $PROD_BEFORE"
        echo "After:  $PROD_AFTER"
        if [[ -z "$PROD_AFTER" || "$PROD_AFTER" != "$PROD_BEFORE" ]]; then
            echo "FAIL: Production Setup fingerprint changed during disposable acceptance"
            status=97
        else
            echo "PASS: Production Setup fingerprint unchanged"
        fi
    else
        echo "No pre-test Production fingerprint was captured."
    fi
    echo "Report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v
required_files=("$M032" "$M033" "$M034" "$M035" "$M036" "$M037" "$M038" "$M043" "$M044" "$M045" "$M046" "$M047" "$M048" "$PRELOAD_VALIDATION" "$VALIDATION")
for file in "${required_files[@]}"; do
    [[ -s "$file" ]] || { echo "FAIL: required acceptance file missing: $file"; exit 2; }
done

sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1 || { echo "FAIL: Production PostgreSQL container was not found"; exit 3; }
[[ "$(sudo docker inspect "$PROD_CONTAINER" --format '{{.Config.Image}}')" == "$IMAGE" ]] || { echo "FAIL: Production PostgreSQL image is not $IMAGE"; exit 4; }
sudo docker network inspect "$NETWORK" >/dev/null 2>&1 || { echo "FAIL: Docker network $NETWORK was not found"; exit 5; }
if sudo docker inspect "$TEST_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: disposable container name already exists: $TEST_CONTAINER"
    exit 6
fi

echo "--- Exact candidate file hashes ---"
sha256sum "${required_files[@]}"

PROD_BEFORE="$(prod_fingerprint)"
[[ -n "$PROD_BEFORE" ]] || { echo "FAIL: Production Setup fingerprint was empty"; exit 7; }
echo "Production Setup fingerprint before: $PROD_BEFORE"

echo
echo "--- Capture current Production into disposable clone ---"
sudo docker exec "$PROD_CONTAINER" pg_dump -U "$DB_ACTOR" -d "$PROD_DB" -Fc > "$DUMP_FILE"
test -s "$DUMP_FILE"
sudo docker exec -i "$PROD_CONTAINER" pg_restore --list < "$DUMP_FILE" >/dev/null
echo "Production dump captured and validated: $(du -h "$DUMP_FILE" | awk '{print $1}')"

sudo docker run -d \
    --name "$TEST_CONTAINER" \
    --network "$NETWORK" \
    -e POSTGRES_USER="$DB_ACTOR" \
    -e POSTGRES_PASSWORD="$TEST_PASSWORD" \
    -e POSTGRES_DB=postgres \
    "$IMAGE" >/dev/null

ready=0
pid1=""
for _ in $(seq 1 120); do
    [[ "$(sudo docker inspect "$TEST_CONTAINER" --format '{{.State.Running}}' 2>/dev/null || true)" == "true" ]] || break
    pid1="$(sudo docker exec "$TEST_CONTAINER" sh -c 'cat /proc/1/comm' 2>/dev/null | tr -d '\r\n' || true)"
    if [[ "$pid1" == "postgres" ]] && sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" pg_isready -U "$DB_ACTOR" -d postgres >/dev/null 2>&1; then
        ready=1
        break
    fi
    sleep 1
done
if [[ "$ready" -ne 1 ]]; then
    echo "FAIL: disposable PostgreSQL did not reach final post-init ready state"
    echo "Observed PID 1 command: ${pid1:-unknown}"
    sudo docker logs "$TEST_CONTAINER" || true
    exit 8
fi

sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" createdb -U "$DB_ACTOR" -T template0 "$TEST_DB"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    pg_restore -U "$DB_ACTOR" -d "$TEST_DB" --no-owner --no-acl --exit-on-error < "$DUMP_FILE"
echo "Disposable current-Production clone restored"

psql_test() {
    sudo docker exec -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" "$@"
}

# Database dumps do not carry cluster-level roles.
psql_test -c "DO \$role\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='fieldwiring_app') THEN CREATE ROLE fieldwiring_app LOGIN; END IF; END \$role\$;"

echo
echo "--- Apply exact #167 candidate migrations to disposable clone only ---"
for migration in "$M032" "$M033" "$M034" "$M035" "$M036" "$M037" "$M038" "$M043" "$M044" "$M045" "$M046" "$M047" "$M048"; do
    echo "Applying $(basename "$migration")"
    sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
        psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" < "$migration"
done

echo
echo "--- Validate one-time inventory preload + durable runtime state ---"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" < "$PRELOAD_VALIDATION"

echo
echo "--- Run transactional #167 behavior assertions ---"
sudo docker exec -i -e PGPASSWORD="$TEST_PASSWORD" "$TEST_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$TEST_DB" < "$VALIDATION"

echo
echo "--- Post-validation state ---"
psql_test -c "
    SELECT
        (SELECT count(*) FROM ref.setup_extra_material WHERE active_flag) AS active_catalog_rows,
        (SELECT count(*) FROM ref.setup_task_extra_material WHERE active_flag) AS active_task_material_rows,
        (SELECT count(*) FROM ref.setup_task_extra_material WHERE active_flag AND notes LIKE '[TPOST_RECON_2026_09_14]%') AS tpost_recon_046_rows,
        (SELECT count(*) FROM ref.setup_task_extra_material WHERE active_flag AND notes LIKE '[TPOST_FINAL_RECON_2026_09_14]%') AS tpost_final_048_rows,
        (SELECT count(*) FROM ref.setup_container_extra_material WHERE active_flag) AS active_container_material_rows,
        (SELECT count(*) FROM ref.setup_container_extra_material WHERE active_flag AND notes LIKE 'Procedure-derived Kit preload v6.%') AS procedure_loaded_kit_rows,
        (SELECT count(*) FROM ref.setup_container_extra_material_review WHERE unverified_items_text LIKE '%[#167 PROCEDURE REMAINDERS v6]%') AS kits_with_remainders,
        (SELECT count(*) FROM ref.setup_container_extra_material_review WHERE unverified_items_text LIKE '%[#167 ASSIGNED KIT COVERAGE]%') AS assigned_kits_with_inventory_review,
        (SELECT count(*) FROM ref.setup_task_container_support WHERE relationship_type='KIT' AND notes='Initial Kit assignment reviewed in disposable reconstruction workbench.') AS reviewed_kit_assignment_rows,
        (SELECT count(*) FROM ops.setup_session WHERE season_year=2026) AS setup_2026_sessions,
        has_table_privilege('fieldwiring_app','ref.setup_extra_material','INSERT') AS broad_catalog_insert,
        has_table_privilege('fieldwiring_app','ops.setup_extra_material_inventory_event','UPDATE') AS broad_inventory_update;
"

echo
echo "--- Assigned Kit inventory coverage ---"
psql_test -c "
    SELECT
        c.container_id,
        c.description AS kit_name,
        count(DISTINCT tc.setup_task_id) FILTER (WHERE tc.relationship_type='KIT') AS assigned_task_count,
        count(DISTINCT cem.setup_container_extra_material_id) FILTER (WHERE cem.active_flag) AS expected_extra_material_rows,
        (review.container_id IS NOT NULL) AS has_inventory_review,
        count(DISTINCT d.display_id) FILTER (WHERE upper(coalesce(ds.display_status_name,'')) <> 'RECYCLED') AS current_display_rows
    FROM ref.container c
    JOIN ref.setup_task_container_support tc
      ON tc.container_id=c.container_id AND tc.relationship_type='KIT'
    LEFT JOIN ref.setup_container_extra_material cem ON cem.container_id=c.container_id AND cem.active_flag
    LEFT JOIN ref.setup_container_extra_material_review review ON review.container_id=c.container_id
    LEFT JOIN ref.display d ON d.container_id=c.container_id
    LEFT JOIN ref.display_status ds ON ds.display_status_id=d.display_status_id
    WHERE c.container_type_id=2
    GROUP BY c.container_id,c.description,review.container_id
    ORDER BY c.container_id;
"

echo
echo "--- All active T-Post task requirements and expected sources ---"
psql_test -c "
    SELECT
        s.stage_key,
        tm.setup_task_id,
        t.task_name,
        ls.scene_name,
        tm.quantity_required,
        tm.quantity_qualifier,
        tm.size_text,
        tm.length_value,
        tm.length_unit,
        tm.verification_state,
        src.container_id AS source_container_id,
        src.expected_quantity AS source_expected_quantity
    FROM ref.setup_task_extra_material tm
    JOIN ref.setup_extra_material m USING (setup_extra_material_id)
    JOIN ref.setup_task t USING (setup_task_id)
    LEFT JOIN ref.stage s ON s.stage_id=t.stage_id
    LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id=t.lor_scene_id
    LEFT JOIN ref.setup_task_extra_material_source src
      ON src.setup_task_extra_material_id=tm.setup_task_extra_material_id
     AND src.active_flag
    WHERE tm.active_flag AND m.material_name='T-Post'
    ORDER BY s.park_order NULLS LAST,s.sub_order NULLS LAST,t.display_order,
             tm.setup_task_id,tm.length_value NULLS LAST,tm.setup_task_extra_material_id,src.container_id;
"

echo
echo "--- Active T-Post physical inventory/source rows ---"
psql_test -c "
    SELECT
        cem.container_id,
        c.description AS container_description,
        cem.expected_quantity,
        cem.quantity_uom,
        cem.size_text,
        cem.length_value,
        cem.length_unit,
        cem.verification_state,
        coalesce(b.inventory_event_count,0) AS inventory_event_count,
        b.on_hand_quantity,
        cem.notes
    FROM ref.setup_container_extra_material cem
    JOIN ref.setup_extra_material m USING (setup_extra_material_id)
    JOIN ref.container c ON c.container_id=cem.container_id
    LEFT JOIN ops.setup_extra_material_inventory_balance b
      ON b.setup_container_extra_material_id=cem.setup_container_extra_material_id
    WHERE cem.active_flag AND m.material_name='T-Post'
    ORDER BY cem.container_id,cem.length_value NULLS LAST,cem.setup_container_extra_material_id;
"

echo
echo "--- Reviewed disposable Kit assignment preload ---"
psql_test -c "
    SELECT
        tc.setup_task_id,
        s.stage_key,
        t.task_name,
        tc.container_id,
        c.description AS container_description
    FROM ref.setup_task_container_support tc
    JOIN ref.setup_task t ON t.setup_task_id=tc.setup_task_id
    LEFT JOIN ref.stage s ON s.stage_id=t.stage_id
    JOIN ref.container c ON c.container_id=tc.container_id
    WHERE tc.relationship_type='KIT'
      AND tc.notes='Initial Kit assignment reviewed in disposable reconstruction workbench.'
    ORDER BY tc.setup_task_id,tc.container_id;
"

echo
echo "DISPOSABLE_SETUP_167_EXTRA_MATERIAL_ACCEPTANCE_PASS"
