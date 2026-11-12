/* ============================================================================
Object group: Automatic exact-name LOR UUID relink
Repository:   LOR2DB/Reconciliation/reconciliation/migrations/
Filename:     0028_auto_approve_safe_uuid_relinks.sql
Revision:     2026-08-05-auto-approve-safe-uuid-relinks-v2

Purpose:
  Remove false-positive operator review when an ACTIVE production display has
  the exact same unique display name as one unique, unclaimed raw LOR UUID.
  The frozen candidate remains immutable and auditable. An append-only automatic
  UPDATE_LOR_LINK action removes it from operator review and P2 applies its
  changed lor_prop_id during Finish.

Safety boundary:
  - Does not call Finish, P1, P2, P3, or P4.
  - Does not modify ref.display or lor_snap.
  - Does not auto-approve identity components, duplicate evidence, inactive
    displays, name changes, new displays, or lifecycle decisions.
  - Corrects qualifying unresolved open-run candidates, including Run 4,
    without creating a new reconciliation or ingest.

Revision history:
  2026-08-05  GAL / OpenAI  v2: Preserve immutable evidence and append an
                            automatic UPDATE_LOR_LINK action.
  2026-08-05  GAL / OpenAI  Initial safe exact-name UUID relink policy.
============================================================================ */

BEGIN;

/* Do not race an in-progress Start Reconciliation candidate build. */
SELECT pg_advisory_xact_lock(hashtext('ops.lor_reconciliation.start'));

/*
  Candidate classification occurs only after the live preflight has rejected
  duplicate source UUIDs, duplicate source names, duplicate production UUIDs,
  duplicate production names, claimed UUIDs, and non-ACTIVE name matches.
  Recheck the frozen group boundary here so a multi-member or atomic identity
  group can never be converted by this policy.
*/
CREATE OR REPLACE FUNCTION ops.trg_auto_approve_safe_uuid_relink()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, ops
AS $function$
BEGIN
    IF NEW.classification_code <> 'UUID_CHANGED_SAME_NAME' THEN
        RETURN NEW;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_group AS g
        WHERE g.lor_reconciliation_group_id =
              NEW.lor_reconciliation_group_id
          AND g.entity_type = 'DISPLAY'
          AND g.group_kind = 'SINGLE_CANDIDATE'
          AND g.member_count = 1
          AND NOT g.requires_atomic_decision
    ) THEN
        RETURN NEW;
    END IF;

    /* Frozen candidates and groups are immutable; approval is append-only. */
    INSERT INTO ops.lor_reconciliation_action (
        lor_reconciliation_run_id,
        lor_reconciliation_group_id,
        import_run_id,
        action_type,
        reason,
        action_payload,
        acted_by_application
    )
    SELECT
        NEW.lor_reconciliation_run_id,
        NEW.lor_reconciliation_group_id,
        NEW.import_run_id,
        'UPDATE_LOR_LINK',
        format(
            'Automatic exact-name UUID relink for display_id %s: the unique ACTIVE display name is unchanged and the new UUID is unique and unclaimed.',
            NEW.display_id
        ),
        jsonb_build_object(
            'policy', 'SAFE_EXACT_NAME_UUID_RELINK',
            'candidate_id', NEW.lor_reconciliation_display_candidate_id
        ),
        'reconciliation:auto-safe-uuid-relink'
    WHERE NOT EXISTS (
        SELECT 1
        FROM ops.lor_reconciliation_action AS a
        WHERE a.lor_reconciliation_group_id =
              NEW.lor_reconciliation_group_id
    );

    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS trg_auto_approve_safe_uuid_relink
    ON ops.lor_reconciliation_display_candidate;
CREATE TRIGGER trg_auto_approve_safe_uuid_relink
AFTER INSERT ON ops.lor_reconciliation_display_candidate
FOR EACH ROW
EXECUTE FUNCTION ops.trg_auto_approve_safe_uuid_relink();

/*
  Apply the same narrow policy to qualifying unresolved candidates already
  frozen in an open reconciliation attempt. An existing recorded decision is
  never replaced or reinterpreted.
*/
WITH eligible AS (
    SELECT
        c.lor_reconciliation_display_candidate_id,
        c.lor_reconciliation_group_id,
        c.display_id
    FROM ops.lor_reconciliation_display_candidate AS c
    JOIN ops.lor_reconciliation_group AS g
      ON g.lor_reconciliation_group_id = c.lor_reconciliation_group_id
    JOIN ops.lor_reconciliation_run AS r
      ON r.lor_reconciliation_run_id = c.lor_reconciliation_run_id
    WHERE c.classification_code = 'UUID_CHANGED_SAME_NAME'
      AND c.initial_resolution_state = 'DECISION_REQUIRED'
      AND g.entity_type = 'DISPLAY'
      AND g.group_kind = 'SINGLE_CANDIDATE'
      AND g.member_count = 1
      AND NOT g.requires_atomic_decision
      AND r.status IN ('PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH')
      AND NOT EXISTS (
          SELECT 1
          FROM ops.lor_reconciliation_action AS a
          WHERE a.lor_reconciliation_group_id =
                c.lor_reconciliation_group_id
      )
)
INSERT INTO ops.lor_reconciliation_action (
    lor_reconciliation_run_id,
    lor_reconciliation_group_id,
    import_run_id,
    action_type,
    reason,
    action_payload,
    acted_by_application
)
SELECT
    c.lor_reconciliation_run_id,
    e.lor_reconciliation_group_id,
    c.import_run_id,
    'UPDATE_LOR_LINK',
    format(
        'Automatic exact-name UUID relink for display_id %s: the unique ACTIVE display name is unchanged and the new UUID is unique and unclaimed.',
        e.display_id
    ),
    jsonb_build_object(
        'policy', 'SAFE_EXACT_NAME_UUID_RELINK',
        'candidate_id', e.lor_reconciliation_display_candidate_id
    ),
    'reconciliation:auto-safe-uuid-relink'
FROM eligible AS e
JOIN ops.lor_reconciliation_display_candidate AS c
  ON c.lor_reconciliation_display_candidate_id =
     e.lor_reconciliation_display_candidate_id;

/* Refresh open-run counters and readiness after removing the false positive. */
WITH counts AS (
    SELECT
        r.lor_reconciliation_run_id,
        count(*) FILTER (
            WHERE gr.effective_resolution_state = 'UNRESOLVED'
        )::integer AS unresolved_count,
        count(*) FILTER (
            WHERE gr.effective_resolution_state = 'DEFERRED'
        )::integer AS deferred_count,
        count(*) FILTER (
            WHERE gr.effective_resolution_state = 'BLOCKED'
        )::integer AS blocked_count
    FROM ops.lor_reconciliation_run AS r
    LEFT JOIN ops.v_lor_reconciliation_group_review AS gr
      ON gr.lor_reconciliation_run_id = r.lor_reconciliation_run_id
    WHERE r.status IN ('PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH')
    GROUP BY r.lor_reconciliation_run_id
)
UPDATE ops.lor_reconciliation_run AS r
   SET unresolved_count = c.unresolved_count,
       deferred_count = c.deferred_count,
       blocked_count = c.blocked_count,
       status = CASE
           WHEN c.unresolved_count = 0 AND c.blocked_count = 0
               THEN 'READY_TO_FINISH'
           ELSE 'AWAITING_DECISIONS'
       END,
       paused_at = CASE
           WHEN c.unresolved_count = 0 AND c.blocked_count = 0 THEN NULL
           ELSE coalesce(r.paused_at, now())
       END
  FROM counts AS c
 WHERE r.lor_reconciliation_run_id = c.lor_reconciliation_run_id;

COMMENT ON FUNCTION ops.trg_auto_approve_safe_uuid_relink() IS
'Appends an automatic UPDATE_LOR_LINK action for only a single, non-atomic UUID_CHANGED_SAME_NAME frozen candidate after the reconciliation preflight uniqueness and collision guards pass.';

REVOKE EXECUTE ON FUNCTION
    ops.trg_auto_approve_safe_uuid_relink() FROM PUBLIC;

COMMIT;

SELECT
    '2026-08-05-auto-approve-safe-uuid-relinks-v2'::text
        AS installed_revision,
    to_regprocedure('ops.trg_auto_approve_safe_uuid_relink()') IS NOT NULL
        AS has_safe_uuid_relink_trigger,
    count(*) FILTER (
        WHERE gr.effective_resolution_state = 'UNRESOLVED'
    ) AS uuid_relinks_still_requiring_review,
    count(*) FILTER (
        WHERE gr.effective_action_type = 'UPDATE_LOR_LINK'
          AND gr.acted_by_application =
              'reconciliation:auto-safe-uuid-relink'
    ) AS auto_approved_uuid_relinks
FROM ops.lor_reconciliation_display_candidate AS c
JOIN ops.lor_reconciliation_run AS r
  ON r.lor_reconciliation_run_id = c.lor_reconciliation_run_id
JOIN ops.v_lor_reconciliation_group_review AS gr
  ON gr.lor_reconciliation_group_id = c.lor_reconciliation_group_id
WHERE c.classification_code = 'UUID_CHANGED_SAME_NAME'
  AND r.status IN ('PREFLIGHT', 'AWAITING_DECISIONS', 'READY_TO_FINISH');
