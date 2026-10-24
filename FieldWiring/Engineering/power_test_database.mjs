import { PGlite } from "@electric-sql/pglite";
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import path from "node:path";
const root = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

export async function createFixtureDatabase() {
  const db = new PGlite();
  await db.exec(`CREATE SCHEMA ref; CREATE SCHEMA ops; CREATE ROLE fieldwiring_app;
CREATE TABLE ref.person(person_id integer PRIMARY KEY);
CREATE TABLE ref.controller_model(controller_model_id bigint PRIMARY KEY,model_code text);
CREATE TABLE ref.controller(controller_id bigint PRIMARY KEY,controller_model_id bigint REFERENCES ref.controller_model,serial_number text);
INSERT INTO ref.controller_model VALUES(1,'RS485 fixture'),(2,'PoE fixture');
INSERT INTO ref.controller VALUES(101,1,'fixture-101'),(102,1,'fixture-102'),(103,2,'fixture-103'),(104,2,'fixture-104');
CREATE TABLE ref.season(season_year integer PRIMARY KEY);
CREATE TABLE ref.site_waypoint(site_waypoint_id bigint PRIMARY KEY,canonical_label text,waypoint_type text);
CREATE TABLE ref.site_waypoint_alias(site_waypoint_id bigint,alias_text text,accepted_by text,accepted_at timestamptz);
CREATE TABLE ref.site_cable(site_cable_id bigint PRIMARY KEY,notes text);
INSERT INTO ref.site_cable VALUES(1,'Fixture physical cable');
CREATE TABLE ref.site_network(site_network_id bigint PRIMARY KEY,network_code text,network_kind text);
CREATE TABLE ref.fixture_user(email text PRIMARY KEY, active boolean,role_name text,person_id integer);
INSERT INTO ref.person VALUES(1),(2); INSERT INTO ref.season VALUES(2026),(2025);
INSERT INTO ref.fixture_user VALUES('crew@example.test',true,'Production Crew',1),('manager@example.test',true,'Manager',2),('volunteer@example.test',true,'Volunteer',1),('inactive@example.test',false,'Production Crew',1);
INSERT INTO ref.site_waypoint VALUES (10,'Panel A','Panel'),(11,'Outlet A','OUT-Combo'),(12,'Outlet B','OUT-Combo'),(13,'Power only','Power'),(99,'Light pole combo','Pole-Combo');
INSERT INTO ref.site_waypoint_alias VALUES(11,'Old Outlet A','manager',now());
INSERT INTO ref.site_network VALUES(1,'REG','LOR'),(2,'AUX-A','LOR');`);
  await db.exec(readFileSync(path.join(root,"FieldWiring/Engineering/power_lor_fixture.sql"),"utf8"));
  await db.exec(`
UPDATE ref.controller SET lor_network='REG',lor_uid_start=1,lor_uid_end=1;
INSERT INTO ref.display SELECT controller_id,'Display '||controller_id,'prop-'||controller_id,1,2 FROM ref.controller;
INSERT INTO ref.controller_display SELECT controller_id,controller_id,NULL FROM ref.controller;
INSERT INTO lor_snap.v_current_props SELECT lor_prop_id,lor_prop_id,1,'REG','01','LOR' FROM ref.display;
ALTER TABLE ref.site_cable ADD COLUMN endpoint_a_waypoint_id bigint,ADD COLUMN endpoint_b_waypoint_id bigint,ADD COLUMN site_network_id bigint,ADD COLUMN lifecycle_status text,ADD COLUMN reviewed_by text,ADD COLUMN reviewed_at timestamptz;
UPDATE ref.site_cable SET endpoint_a_waypoint_id=11,endpoint_b_waypoint_id=12,site_network_id=1,lifecycle_status='CURRENT',reviewed_by='Fixture',reviewed_at=now();
INSERT INTO ref.site_cable VALUES(2,'Pole route',12,99,1,'CURRENT','Fixture',now());
CREATE TABLE ref.site_track(site_track_id bigint PRIMARY KEY,lifecycle_status text,changed_at timestamptz);
CREATE TABLE ref.site_route_segment(site_route_segment_id bigint PRIMARY KEY,endpoint_a_waypoint_id bigint,endpoint_b_waypoint_id bigint,review_status text,reviewed_at timestamptz);
CREATE TABLE ref.site_cable_route_segment(site_cable_id bigint,segment_order integer,site_route_segment_id bigint,traversal_direction integer,reviewed_at timestamptz);
CREATE TABLE ref.site_route_source_track(site_route_segment_id bigint,site_track_id bigint,source_class text,reviewed_at timestamptz);
INSERT INTO ref.site_track VALUES(1,'CURRENT','2026-01-01');
INSERT INTO ref.site_route_segment VALUES(1,11,12,'REVIEWED','2026-02-01'),(2,12,99,'REVIEWED','2026-02-01');
INSERT INTO ref.site_route_source_track VALUES(1,1,'NET','2026-02-02'),(2,1,'NET','2026-02-02');
INSERT INTO ref.site_cable_route_segment VALUES(1,1,1,1,'2026-02-03'),(2,1,2,1,'2026-02-03');
CREATE TABLE ops.linkiq_intake_review(source_sha256 text,test_uuid uuid,proposal jsonb,recorded_at timestamptz DEFAULT now());
CREATE TABLE ops.linkiq_test(test_uuid uuid,physical_site_cable_id bigint,test_time_local text,test_status_code integer,identity_review_status text,first_seen_source_sha256 text,test_standard text,length_ft numeric,tester_original_name text);
`);
  // Load the actual role policy and actor SQL used by the application. Only the
  // external People reconciliation dependency is stubbed to a fixed fixture mapping.
  await db.exec(`CREATE TABLE public.directus_roles(id uuid PRIMARY KEY,name text);
CREATE TABLE public.directus_users(id uuid PRIMARY KEY,role uuid,email text,status text,first_name text,last_name text);
CREATE TABLE public.directus_policies(id uuid PRIMARY KEY,name text,admin_access boolean);
CREATE TABLE public.directus_access("user" uuid,role uuid,policy uuid);
INSERT INTO public.directus_roles VALUES('00000000-0000-0000-0000-000000000010','Production Crew'),('00000000-0000-0000-0000-000000000020','Manager'),('00000000-0000-0000-0000-000000000030','Volunteer');
INSERT INTO public.directus_users SELECT ('00000000-0000-0000-0000-'||lpad(row_number() OVER()::text,12,'0'))::uuid,r.id,u.email,CASE WHEN u.active THEN 'active' ELSE 'suspended' END,'Fixture','User' FROM ref.fixture_user u LEFT JOIN public.directus_roles r ON r.name=u.role_name;
INSERT INTO public.directus_policies VALUES('00000000-0000-0000-0000-000000000030','Volunteer',false);
INSERT INTO public.directus_access(role,policy) VALUES('00000000-0000-0000-0000-000000000030','00000000-0000-0000-0000-000000000030');
INSERT INTO public.directus_users VALUES('00000000-0000-0000-0000-000000000099',NULL,'norole@example.test','active','No','Role');
CREATE FUNCTION ref.reconcile_directus_person_identity(p_email text) RETURNS TABLE(directus_user_id uuid,person_id integer,display_name text) LANGUAGE sql AS $$ SELECT d.id,u.person_id,u.email FROM ref.fixture_user u JOIN public.directus_users d ON d.email=u.email WHERE u.email=p_email $$;`);
  function definition(file, name) {
    const source = readFileSync(path.join(root, file), "utf8");
    const start = source.indexOf(
      "CREATE OR REPLACE FUNCTION ref." + name + "(",
    );
    assert.ok(start >= 0);
    const end =
      source.indexOf("$function$;", source.indexOf("AS $function$", start)) +
      11;
    return source.slice(start, end);
  }
  await db.exec(
    definition(
      "Setup/Database/002_create_setup_browser_authorization_contract.sql",
      "setup_browser_capabilities",
    ),
  );
  await db.exec(
    definition(
      "People/Database/005_reconcile_directus_person_identity.sql",
      "setup_inventory_actor",
    ),
  );
  const sql = readFileSync(
    path.join(
      root,
      "Database/EngineeringTools/sql/171_panel_circuit_capture_candidate.sql",
    ),
    "utf8",
  );
  await db.exec(sql);

  return db;
}
