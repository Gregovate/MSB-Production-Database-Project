"""Task-scoped QC read model. Existing annual Setup task remains authoritative."""
from __future__ import annotations

import psycopg2
from psycopg2.extras import RealDictCursor


class SetupQcRepository:
    def __init__(self, dsn: str):
        self.dsn = dsn

    def snapshot(self, season_year: int) -> dict:
        with psycopg2.connect(self.dsn) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                  SELECT f.qc_finding_id, f.setup_session_task_id, f.title,
                         f.location_detail, f.discovery_phase, f.status,
                         f.created_at, f.updated_at,
                         f.created_by_person_id, f.claimed_by_person_id,
                         coalesce(nullif(btrim(concat_ws(' ',cp.first_name,cp.last_name)),''),
                           cp.email) AS reporter,
                         coalesce(nullif(btrim(concat_ws(' ',rp.first_name,rp.last_name)),''),
                           rp.email) AS repair_owner,
                         t.annual_task_name AS task_name,
                         s.stage_key,s.stage_name,ls.scene_name,
                         coalesce((
                           SELECT jsonb_agg(jsonb_build_object(
                             'id',e.qc_event_id,'type',e.event_type,'note',e.note,
                             'person_id',e.person_id,'at',e.created_at,
                             'person',coalesce(nullif(btrim(concat_ws(' ',p.first_name,p.last_name)),''),
                               p.email)) ORDER BY e.created_at,e.qc_event_id)
                           FROM ops.setup_qc_event e
                           LEFT JOIN ref.person p ON p.person_id=e.person_id
                           WHERE e.qc_finding_id=f.qc_finding_id
                         ),'[]'::jsonb) AS events,
                         coalesce((
                           SELECT jsonb_agg(l.intake_id ORDER BY l.intake_id)
                           FROM ops.setup_qc_intake_link l
                           WHERE l.qc_finding_id=f.qc_finding_id
                         ),'[]'::jsonb) AS linked_intake_ids
                  FROM ops.setup_qc_finding f
                  JOIN ops.setup_session_task t ON t.setup_session_task_id=f.setup_session_task_id
                  JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
                  LEFT JOIN ref.stage s ON s.stage_id=t.annual_stage_id
                  LEFT JOIN ref.lor_scene ls ON ls.lor_scene_id=t.annual_lor_scene_id
                  LEFT JOIN ref.person cp ON cp.person_id=f.created_by_person_id
                  LEFT JOIN ref.person rp ON rp.person_id=f.claimed_by_person_id
                  WHERE ss.season_year=%s
                  ORDER BY s.stage_key,ls.scene_name,f.setup_session_task_id,f.qc_finding_id
                """, (season_year,))
                findings = [dict(row) for row in cur.fetchall()]
                cur.execute("""
                  SELECT a.setup_session_task_id,a.person_id,a.claimed_at,
                         coalesce(nullif(btrim(concat_ws(' ',p.first_name,p.last_name)),''),
                           p.email) AS auditor
                  FROM ops.setup_qc_auditor a
                  JOIN ops.setup_session_task t ON t.setup_session_task_id=a.setup_session_task_id
                  JOIN ops.setup_session ss ON ss.setup_session_id=t.setup_session_id
                  JOIN ref.person p ON p.person_id=a.person_id
                  WHERE ss.season_year=%s
                  ORDER BY a.setup_session_task_id,a.claimed_at
                """,(season_year,))
                auditors=[dict(row) for row in cur.fetchall()]
        return {'findings':findings,'auditors':auditors}

    def intake_candidates(self, season_year: int) -> list[dict]:
        """Review original unpromoted Intake; never mutate it or infer QC identity."""
        with psycopg2.connect(self.dsn) as conn:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                  SELECT i.intake_id,i.problem_raw,i.stage_id,
                         s.stage_name,s.stage_key,i.submitter_name_raw,
                         i.source_form_name,i.updated_at,
                         coalesce(links.linked_findings,'[]'::jsonb) AS linked_findings
                  FROM stage.work_order_intake i
                  LEFT JOIN ref.stage s ON s.stage_id=i.stage_id
                  LEFT JOIN LATERAL (
                    SELECT jsonb_agg(l.qc_finding_id ORDER BY l.qc_finding_id)
                      AS linked_findings
                    FROM ops.setup_qc_intake_link l
                    WHERE l.intake_id=i.intake_id
                  ) links ON true
                  WHERE i.target_year=%s
                    AND NOT EXISTS (
                      SELECT 1 FROM ops.work_order w
                      WHERE w.source_intake_id=i.intake_id
                    )
                  ORDER BY i.intake_id DESC
                  LIMIT 300
                """,(season_year,))
                return [dict(row) for row in cur.fetchall()]

    def command(self, email: str, payload: dict) -> dict:
        with psycopg2.connect(self.dsn) as conn:
            # Installed fieldwiring_app defaults to read-only; explicitly opt in
            # only for the narrow authenticated SECURITY DEFINER QC command.
            conn.set_session(readonly=False, autocommit=False)
            with conn.cursor() as cur:
                cur.execute("""
                   SELECT ops.setup_qc_command(
                     %s,%s,%s,%s,%s,%s,%s,%s,%s
                   )
                """, (
                    email, payload['action'], payload['setup_session_task_id'],
                    payload.get('qc_finding_id'), payload.get('note'),
                    payload.get('title'), payload.get('discovery_phase'),
                    payload.get('location_detail'), payload.get('intake_id'),
                ))
                result=cur.fetchone()[0]
            conn.commit()
        return result
