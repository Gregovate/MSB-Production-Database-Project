#!/usr/bin/env bash
set -euo pipefail

FIELDWIRING_ROOT="/opt/fieldwiring"
TARGET_REF="agent/controller-inventory-ref-sandbox"
TARGET_SHA="2fd2067958cc0a903260fe6f089f88ae63a857f1"
PROD_CONTAINER="msb-postgres"
PROD_DB="msb"
DB_ACTOR="msbadmin"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$SCRIPT_DIR/management-core"
STAMP="$(date +%Y%m%dT%H%M%S)"
REPORT="/tmp/MSB_Controller_Setup_Probe_Disposable_$STAMP.txt"
CANDIDATE_WORKTREE="/tmp/msb-controller-setup-probe-candidate-$STAMP"

exec > >(tee "$REPORT") 2>&1

echo "========== CONTROLLER SETUP PROBE + MANAGEMENT ACCEPTANCE =========="
echo "Report:        $REPORT"
echo "Candidate SHA: $TARGET_SHA"
echo "Production database access in this wrapper: SELECT only"
echo "Controller write testing: disposable clone only"
echo

cleanup() {
    status=$?
    trap - EXIT INT TERM
    set +e
    if sudo git -C "$FIELDWIRING_ROOT" worktree list --porcelain 2>/dev/null | grep -Fq "worktree $CANDIDATE_WORKTREE"; then
        sudo git -C "$FIELDWIRING_ROOT" worktree remove --force "$CANDIDATE_WORKTREE" >/dev/null 2>&1 || true
    fi
    rm -rf "$SCRIPT_DIR" >/dev/null 2>&1 || true
    echo
    echo "Acceptance report retained at: $REPORT"
    echo "Exit status: $status"
    exit "$status"
}
trap cleanup EXIT INT TERM

sudo -v

for required in \
    "$CORE_DIR/controller_management_disposable_server.sh" \
    "$CORE_DIR/023_create_controller_management_commands.sql"; do
    if [[ ! -s "$required" ]]; then
        echo "FAIL: required acceptance bundle file missing: $required"
        exit 2
    fi
done

if ! sudo docker inspect "$PROD_CONTAINER" >/dev/null 2>&1; then
    echo "FAIL: production PostgreSQL container $PROD_CONTAINER was not found"
    exit 3
fi

LIVE_HEAD="$(sudo git -C "$FIELDWIRING_ROOT" rev-parse HEAD)"
if [[ -n "$(sudo git -C "$FIELDWIRING_ROOT" status --porcelain)" ]]; then
    echo "FAIL: live shared checkout has uncommitted changes"
    sudo git -C "$FIELDWIRING_ROOT" status -sb
    exit 4
fi

echo "Live shared checkout: $LIVE_HEAD"

echo
echo "--- Fetch and verify exact candidate ---"
sudo git -C "$FIELDWIRING_ROOT" fetch origin "$TARGET_REF"
sudo git -C "$FIELDWIRING_ROOT" cat-file -e "$TARGET_SHA^{commit}"
if ! sudo git -C "$FIELDWIRING_ROOT" merge-base --is-ancestor "$LIVE_HEAD" "$TARGET_SHA"; then
    echo "FAIL: exact candidate is not a descendant of the live shared checkout"
    exit 5
fi

echo "Verified candidate ancestry: $LIVE_HEAD -> $TARGET_SHA"

echo
echo "--- Detached candidate regression ---"
sudo git -C "$FIELDWIRING_ROOT" worktree add --detach "$CANDIDATE_WORKTREE" "$TARGET_SHA"
sudo -u fieldwiring -H bash -c \
    "cd '$CANDIDATE_WORKTREE' && /opt/fieldwiring/.venv/bin/python -m pytest -q -p no:cacheprovider FieldWiring/Application Procedures/Application"
echo "DETACHED CONTROLLER PROBE/MAINTENANCE REGRESSION: PASS"

echo
echo "--- Read-only production planner data/permission probe ---"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" <<'SQL'
DO $block$
DECLARE
    v_numeric_uid_rows bigint;
    v_programmed_controllers bigint;
    v_stage_rows bigint;
    v_regular_rows bigint;
    v_fixed_models bigint;
BEGIN
    IF NOT has_table_privilege('fieldwiring_app', 'ref.stage', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'ref.controller', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'ref.controller_model', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'ref.controller_status', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'ref.controller_display', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'ref.display', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'lor_snap.preview_wiring_fieldlead_v6', 'SELECT')
       OR NOT has_table_privilege('fieldwiring_app', 'lor_snap.v_current_previews', 'SELECT') THEN
        RAISE EXCEPTION 'fieldwiring_app lacks one or more planner read privileges';
    END IF;

    SET LOCAL ROLE fieldwiring_app;

    SELECT count(*) INTO v_numeric_uid_rows
    FROM lor_snap.preview_wiring_fieldlead_v6 fw
    WHERE nullif(btrim(fw.network), '') IS NOT NULL
      AND btrim(fw.controller) ~* '^[0-9a-f]{1,2}$';

    SELECT count(*) INTO v_programmed_controllers
    FROM ref.controller c
    WHERE nullif(btrim(c.lor_network), '') IS NOT NULL
      AND c.lor_uid_start IS NOT NULL
      AND c.lor_uid_end IS NOT NULL;

    SELECT count(*) INTO v_stage_rows FROM ref.stage;

    SELECT count(*) INTO v_regular_rows
    FROM lor_snap.preview_wiring_fieldlead_v6 fw
    WHERE lower(btrim(fw.network)) = 'regular';

    SELECT count(*) INTO v_fixed_models
    FROM ref.controller_model m
    WHERE m.lor_uid_capacity > 1;

    RESET ROLE;

    IF v_numeric_uid_rows = 0 THEN
        RAISE EXCEPTION 'No current numeric LOR UID rows are available to the planner';
    END IF;
    IF v_programmed_controllers = 0 THEN
        RAISE EXCEPTION 'No current programmed physical Controllers are available to overlay';
    END IF;
    IF v_stage_rows = 0 THEN
        RAISE EXCEPTION 'No Stage rows are available to the planner';
    END IF;
    IF v_regular_rows = 0 THEN
        RAISE EXCEPTION 'Current LOR data contains no Regular-network rows';
    END IF;
    IF v_fixed_models = 0 THEN
        RAISE EXCEPTION 'No multi-UID Controller model capacity is available';
    END IF;

    RAISE NOTICE 'planner numeric UID rows=%', v_numeric_uid_rows;
    RAISE NOTICE 'planner programmed Controllers=%', v_programmed_controllers;
    RAISE NOTICE 'planner Stages=%', v_stage_rows;
    RAISE NOTICE 'planner Regular rows=%', v_regular_rows;
    RAISE NOTICE 'planner multi-UID models=%', v_fixed_models;
END
$block$;
SQL

echo "PLANNER PRODUCTION READ PROBE: PASS"

echo
echo "--- Read-only direct Stage SPARE attribution probe ---"
sudo docker exec -i "$PROD_CONTAINER" \
    psql -X -qAt -v ON_ERROR_STOP=1 -U "$DB_ACTOR" -d "$PROD_DB" -c "
        SELECT
            'direct_stage_spare_rows=' || count(*)
        FROM lor_snap.preview_wiring_fieldlead_v6 fw
        JOIN lor_snap.v_current_previews pv ON pv.name = fw.preview_name
        JOIN ref.stage st ON lower(st.stage_key) = lower(btrim(pv.stage_id))
        WHERE (
            coalesce(fw.display_name, '') ILIKE '%SPARE%'
            OR coalesce(fw.channel_name, '') ILIKE '%SPARE%'
        )
          AND nullif(btrim(fw.network), '') IS NOT NULL
          AND btrim(fw.controller) ~* '^[0-9a-f]{1,2}$';
    "
echo "SPARE attribution query executed; zero is allowed because shared/master Preview SPARE rows are deliberately not guessed."

echo
echo "--- Current-production disposable Controller maintenance proof ---"
chmod 700 "$CORE_DIR/controller_management_disposable_server.sh"
bash "$CORE_DIR/controller_management_disposable_server.sh"
echo "CONTROLLER MANAGEMENT DISPOSABLE CHILD: PASS"

echo
echo "CONTROLLER SETUP PROBE + MANAGEMENT ACCEPTANCE: PASS"
