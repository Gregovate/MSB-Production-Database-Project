/* ============================================================================
Object group: LOR current-snapshot raw identity interface
Repository:   LOR2DB/Reconciliation/reconciliation/migrations/
File:         0013_expose_current_raw_prop_identity.sql

Purpose:
  Expose the original unscoped LOR PropClass UUID through the current props and
  subprops views. The scene-membership current view already exposes raw_prop_id.

Safety:
  This file replaces read-only views only. It does not modify snapshot rows,
  production reference data, or promotion procedures.

Revision history:
  2026-08-02  GAL / OpenAI  Initial raw_prop_id current-view alignment.
============================================================================ */

BEGIN;

CREATE OR REPLACE VIEW lor_snap.v_current_props AS
SELECT
    p.import_run_id,
    p.int_prop_id,
    p.prop_id,
    p.name,
    p.lor_comment,
    p.device_type,
    p.bulb_shape,
    p.network,
    p.uid,
    p.start_channel,
    p.end_channel,
    p.unknown,
    p.color,
    p.custom_bulb_color,
    p.dimming_curve_name,
    p.individual_channels,
    p.legacy_sequence_method,
    p.max_channels,
    p.opacity,
    p.master_dimmable,
    p.preview_bulb_size,
    p.master_prop_id,
    p.separate_ids,
    p.start_location,
    p.string_type,
    p.traditional_colors,
    p.traditional_type,
    p.effect_bulb_size,
    p.tag,
    p.parm1,
    p.parm2,
    p.parm3,
    p.parm4,
    p.parm5,
    p.parm6,
    p.parm7,
    p.parm8,
    p.lights,
    p.preview_id,
    p.raw_prop_id
FROM lor_snap.props AS p
JOIN lor_snap.v_current_run AS r
  ON r.import_run_id = p.import_run_id;

CREATE OR REPLACE VIEW lor_snap.v_current_sub_props AS
SELECT
    sp.import_run_id,
    sp.int_sub_prop_id,
    sp.sub_prop_id,
    sp.name,
    sp.lor_comment,
    sp.device_type,
    sp.bulb_shape,
    sp.network,
    sp.uid,
    sp.start_channel,
    sp.end_channel,
    sp.unknown,
    sp.color,
    sp.custom_bulb_color,
    sp.dimming_curve_name,
    sp.individual_channels,
    sp.legacy_sequence_method,
    sp.max_channels,
    sp.opacity,
    sp.master_dimmable,
    sp.preview_bulb_size,
    sp.rgb_order,
    sp.master_prop_id,
    sp.separate_ids,
    sp.start_location,
    sp.string_type,
    sp.traditional_colors,
    sp.traditional_type,
    sp.effect_bulb_size,
    sp.tag,
    sp.parm1,
    sp.parm2,
    sp.parm3,
    sp.parm4,
    sp.parm5,
    sp.parm6,
    sp.parm7,
    sp.parm8,
    sp.lights,
    sp.preview_id,
    sp.raw_prop_id
FROM lor_snap.sub_props AS sp
JOIN lor_snap.v_current_run AS r
  ON r.import_run_id = sp.import_run_id;

COMMENT ON VIEW lor_snap.v_current_props IS
'Latest completed prop snapshot, including scoped prop_id and original unscoped raw_prop_id.';

COMMENT ON VIEW lor_snap.v_current_sub_props IS
'Latest completed subprop snapshot, including scoped sub_prop_id and original unscoped raw_prop_id.';

COMMIT;
