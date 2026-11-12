// Synthetic sizes from the operator's measured Production snapshot; never live data.
export async function populatePowerScale(db) {
  await db.exec(`
INSERT INTO ref.site_waypoint SELECT i,'Waypoint '||i,'OUT-Combo' FROM generate_series(1,240) i ON CONFLICT DO NOTHING;
INSERT INTO ref.controller SELECT i,1,'fixture-'||i,'REG',1,1 FROM generate_series(1000,1177) i;
INSERT INTO ref.display SELECT i,'Display '||i,'prop-'||i,1,2 FROM generate_series(1000,2086) i;
INSERT INTO ref.controller_display SELECT i,i,NULL FROM generate_series(1000,1177) i;
INSERT INTO lor_snap.v_current_props SELECT 'prop-'||i,'prop-'||i,1,'REG','01','LOR' FROM generate_series(1000,1177) i;
-- Four original controllers are deliberately unresolved; 178 x 5 = 890 eligibility rows.
UPDATE ref.controller SET lor_network='AUX-A' WHERE controller_id<1000;
DELETE FROM ops.linkiq_intake_review; DELETE FROM ops.linkiq_test;
INSERT INTO ops.linkiq_test SELECT md5('test-'||i)::uuid,NULL,'2024-10-01',1,'REVIEWED','fixture','Cat6',123,'Synthetic FLW '||i FROM generate_series(1,517) i;
INSERT INTO ops.linkiq_intake_review(source_sha256,test_uuid,proposal)
 SELECT 'fixture',md5('test-'||i)::uuid,jsonb_build_object('endpoint_candidates',jsonb_build_array(jsonb_build_array(11),jsonb_build_array(12+(i%4))),'designation','REG','reasons','[]'::jsonb) FROM generate_series(1,475) i;
INSERT INTO ref.site_panel(panel_name,branch_position_count) SELECT 'Panel '||i,20 FROM generate_series(1,17) i;
INSERT INTO ref.site_power_breaker(site_panel_id,breaker_name,breaker_role,pole_count,panel_positions,rated_amps)
 SELECT 1+(i-1)%17,'Breaker '||i,'BRANCH',2,ARRAY[1+4*((i-1)/17),3+4*((i-1)/17)],20 FROM generate_series(1,83) i;
INSERT INTO ref.site_power_circuit(site_panel_id,circuit_code,site_power_breaker_id,breaker_pole)
 SELECT 1+((i-1)/2)%17,'Circuit '||i,1+(i-1)/2,1+(i-1)%2 FROM generate_series(1,139) i;
INSERT INTO ops.site_power_edit_log(revision,request_id,command,target_id,payload,after_data,directus_user_id,person_id,operator_email)
 SELECT i,md5('history-'||i)::uuid,'panel',1,'{}','{}','00000000-0000-0000-0000-000000000001',1,'crew@example.test' FROM generate_series(1,400) i;
UPDATE ref.site_power_revision SET revision=400;
ANALYZE;
`);
}
