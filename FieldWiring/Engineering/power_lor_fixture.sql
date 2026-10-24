-- Synthetic dependencies for isolated engineering tests only. Never a migration.
CREATE SCHEMA lor_snap;
ALTER TABLE ref.controller ADD COLUMN lor_network text, ADD COLUMN lor_uid_start integer, ADD COLUMN lor_uid_end integer;
CREATE TABLE ref.display(display_id bigint PRIMARY KEY,display_name text,lor_prop_id text,display_status_id integer,amps_measured numeric);
CREATE TABLE ref.controller_display(controller_id bigint REFERENCES ref.controller,display_id bigint REFERENCES ref.display,wiring_source_display_id bigint REFERENCES ref.display,PRIMARY KEY(controller_id,display_id));
CREATE TABLE lor_snap.v_current_props(raw_prop_id text,prop_id text,import_run_id bigint,network text,uid text,device_type text);
CREATE TABLE lor_snap.v_current_sub_props(master_prop_id text,import_run_id bigint,network text,uid text,device_type text);
