--
-- PostgreSQL database dump
--

\restrict yPmMLFaQh9SddBGHLc3ZhtFGsGlfRkmgjdYyMvdtCJgcc3Anr1hHuG0GFI6xapJ

-- Dumped from database version 16.9 (Debian 16.9-1.pgdg110+1)
-- Dumped by pg_dump version 18.4

-- Started on 2026-08-31 22:58:29

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 366 (class 1259 OID 18687)
-- Name: work_order_completed_raw_src_row_num_seq; Type: SEQUENCE; Schema: stage; Owner: msbadmin
--

CREATE SEQUENCE stage.work_order_completed_raw_src_row_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stage.work_order_completed_raw_src_row_num_seq OWNER TO msbadmin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 380 (class 1259 OID 18976)
-- Name: work_order_intake; Type: TABLE; Schema: stage; Owner: directus_app
--

CREATE TABLE stage.work_order_intake (
    intake_id bigint NOT NULL,
    source_system character varying(30) DEFAULT 'GOOGLE_FORM'::text NOT NULL,
    source_form_name character varying(30),
    source_payload jsonb,
    source_row_hash character varying(64),
    submitter_email_raw character varying(64),
    submitter_name_raw character varying(100),
    submitted_at timestamp with time zone DEFAULT now() NOT NULL,
    priority_raw character varying(10) NOT NULL,
    task_type_raw character varying(50) NOT NULL,
    stage_raw character varying(100),
    problem_raw character varying(255) NOT NULL,
    notes_raw text,
    photo_url_raw character varying(255),
    triaged_at timestamp with time zone,
    triaged_by_person_id integer,
    triage_notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    location_type_raw character varying(20),
    work_area_raw character varying(100),
    submitter_person_id integer,
    stage_id bigint,
    work_area_id bigint,
    task_type_id bigint,
    urgency_id smallint,
    target_year integer,
    created_by text DEFAULT CURRENT_USER NOT NULL,
    updated_by text DEFAULT CURRENT_USER NOT NULL,
    created_by_person_id integer,
    updated_by_person_id integer,
    triage_dropdown character varying(255) DEFAULT '1'::character varying,
    CONSTRAINT ck_work_order_intake_triage_dropdown CHECK (((triage_dropdown)::text = ANY ((ARRAY['1'::character varying, '3'::character varying, '4'::character varying])::text[])))
);


ALTER TABLE stage.work_order_intake OWNER TO directus_app;

--
-- TOC entry 5101 (class 0 OID 0)
-- Dependencies: 380
-- Name: COLUMN work_order_intake.stage_raw; Type: COMMENT; Schema: stage; Owner: directus_app
--

COMMENT ON COLUMN stage.work_order_intake.stage_raw IS 'Raw stage value selected in the Google Form when STAGE branch is used';


--
-- TOC entry 5102 (class 0 OID 0)
-- Dependencies: 380
-- Name: COLUMN work_order_intake.location_type_raw; Type: COMMENT; Schema: stage; Owner: directus_app
--

COMMENT ON COLUMN stage.work_order_intake.location_type_raw IS 'Branch selected in the Google Form: WORK_AREA or STAGE';


--
-- TOC entry 5103 (class 0 OID 0)
-- Dependencies: 380
-- Name: COLUMN work_order_intake.work_area_raw; Type: COMMENT; Schema: stage; Owner: directus_app
--

COMMENT ON COLUMN stage.work_order_intake.work_area_raw IS 'Raw work area selected in the Google Form when WORK_AREA branch is used';


--
-- TOC entry 379 (class 1259 OID 18975)
-- Name: work_order_intake_intake_id_seq; Type: SEQUENCE; Schema: stage; Owner: directus_app
--

ALTER TABLE stage.work_order_intake ALTER COLUMN intake_id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME stage.work_order_intake_intake_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- TOC entry 364 (class 1259 OID 18652)
-- Name: work_order_todo_raw_src_row_num_seq; Type: SEQUENCE; Schema: stage; Owner: msbadmin
--

CREATE SEQUENCE stage.work_order_todo_raw_src_row_num_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE stage.work_order_todo_raw_src_row_num_seq OWNER TO msbadmin;

--
-- TOC entry 5094 (class 0 OID 18976)
-- Dependencies: 380
-- Data for Name: work_order_intake; Type: TABLE DATA; Schema: stage; Owner: directus_app
--

COPY stage.work_order_intake (intake_id, source_system, source_form_name, source_payload, source_row_hash, submitter_email_raw, submitter_name_raw, submitted_at, priority_raw, task_type_raw, stage_raw, problem_raw, notes_raw, photo_url_raw, triaged_at, triaged_by_person_id, triage_notes, created_at, updated_at, location_type_raw, work_area_raw, submitter_person_id, stage_id, work_area_id, task_type_id, urgency_id, target_year, created_by, updated_by, created_by_person_id, updated_by_person_id, triage_dropdown) FROM stdin;
40	GOOGLE_FORM	Work Order Form v2	{"Notes": [""], "Priority": ["2"], "Task Type": ["Repair"], "Work Area": ["Workshop"], "Issue or Suggestion": ["Magic Igloo - Section P & R need attention during set-up in 2026."], "Where is the problem located?": ["Workshop / Operations Area?"]}	323ba2e95a8b52644837e0044fc38c81e40aea99b92f497e75ca3a9cf7ec9bb4	rhoffmann@sheboyganlights.org	\N	2026-06-25 21:08:33.085+00	2	Repair	\N	Magic Igloo - Section P & R need attention during set-up in 2026.	\N	\N	\N	\N	\N	2026-06-25 21:08:33.363924+00	2026-06-25 21:08:33.363924+00	WORK_AREA	Workshop	15	\N	\N	\N	\N	\N	directus_app	directus_app	\N	\N	1
\.


--
-- TOC entry 5105 (class 0 OID 0)
-- Dependencies: 366
-- Name: work_order_completed_raw_src_row_num_seq; Type: SEQUENCE SET; Schema: stage; Owner: msbadmin
--

SELECT pg_catalog.setval('stage.work_order_completed_raw_src_row_num_seq', 256, true);


--
-- TOC entry 5106 (class 0 OID 0)
-- Dependencies: 379
-- Name: work_order_intake_intake_id_seq; Type: SEQUENCE SET; Schema: stage; Owner: directus_app
--

SELECT pg_catalog.setval('stage.work_order_intake_intake_id_seq', 54, true);


--
-- TOC entry 5107 (class 0 OID 0)
-- Dependencies: 364
-- Name: work_order_todo_raw_src_row_num_seq; Type: SEQUENCE SET; Schema: stage; Owner: msbadmin
--

SELECT pg_catalog.setval('stage.work_order_todo_raw_src_row_num_seq', 50, true);


--
-- TOC entry 4886 (class 2606 OID 18987)
-- Name: work_order_intake work_order_intake_pkey; Type: CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT work_order_intake_pkey PRIMARY KEY (intake_id);


--
-- TOC entry 4879 (class 1259 OID 19003)
-- Name: ix_intake_submitted_at; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_intake_submitted_at ON stage.work_order_intake USING btree (submitted_at DESC);


--
-- TOC entry 4880 (class 1259 OID 19654)
-- Name: ix_work_order_intake_stage_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_stage_id ON stage.work_order_intake USING btree (stage_id);


--
-- TOC entry 4881 (class 1259 OID 19876)
-- Name: ix_work_order_intake_submitter_person; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_submitter_person ON stage.work_order_intake USING btree (submitter_person_id);


--
-- TOC entry 4882 (class 1259 OID 19656)
-- Name: ix_work_order_intake_task_type_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_task_type_id ON stage.work_order_intake USING btree (task_type_id);


--
-- TOC entry 4883 (class 1259 OID 19657)
-- Name: ix_work_order_intake_urgency_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_urgency_id ON stage.work_order_intake USING btree (urgency_id);


--
-- TOC entry 4884 (class 1259 OID 19655)
-- Name: ix_work_order_intake_work_area_id; Type: INDEX; Schema: stage; Owner: directus_app
--

CREATE INDEX ix_work_order_intake_work_area_id ON stage.work_order_intake USING btree (work_area_id);


--
-- TOC entry 4895 (class 2620 OID 20088)
-- Name: work_order_intake trg_process_work_order_intake_on_triage; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_process_work_order_intake_on_triage AFTER UPDATE OF triage_dropdown ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION stage.tf_process_work_order_intake_on_triage();


--
-- TOC entry 4896 (class 2620 OID 20098)
-- Name: work_order_intake trg_resolve_work_order_intake_submitter; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_resolve_work_order_intake_submitter BEFORE INSERT OR UPDATE OF submitter_email_raw, submitter_person_id, created_by_person_id ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION stage.tf_resolve_work_order_intake_submitter();


--
-- TOC entry 4897 (class 2620 OID 19845)
-- Name: work_order_intake trg_work_order_intake_set_actor_insert; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_work_order_intake_set_actor_insert BEFORE INSERT ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_insert();


--
-- TOC entry 4898 (class 2620 OID 19846)
-- Name: work_order_intake trg_work_order_intake_set_actor_update; Type: TRIGGER; Schema: stage; Owner: directus_app
--

CREATE TRIGGER trg_work_order_intake_set_actor_update BEFORE UPDATE ON stage.work_order_intake FOR EACH ROW EXECUTE FUNCTION ref.set_actor_on_update();


--
-- TOC entry 4887 (class 2606 OID 19943)
-- Name: work_order_intake fk_intake_triaged_by; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_intake_triaged_by FOREIGN KEY (triaged_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 4888 (class 2606 OID 19987)
-- Name: work_order_intake fk_work_order_intake_created_by_person; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_created_by_person FOREIGN KEY (created_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 4889 (class 2606 OID 19634)
-- Name: work_order_intake fk_work_order_intake_stage; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_stage FOREIGN KEY (stage_id) REFERENCES ref.stage(stage_id);


--
-- TOC entry 4890 (class 2606 OID 19948)
-- Name: work_order_intake fk_work_order_intake_submitter_person; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_submitter_person FOREIGN KEY (submitter_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 4891 (class 2606 OID 19644)
-- Name: work_order_intake fk_work_order_intake_task_type; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_task_type FOREIGN KEY (task_type_id) REFERENCES ref.task_type(task_type_id);


--
-- TOC entry 4892 (class 2606 OID 19992)
-- Name: work_order_intake fk_work_order_intake_updated_by_person; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_updated_by_person FOREIGN KEY (updated_by_person_id) REFERENCES ref.person(person_id);


--
-- TOC entry 4893 (class 2606 OID 19649)
-- Name: work_order_intake fk_work_order_intake_urgency; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_urgency FOREIGN KEY (urgency_id) REFERENCES ref.urgency(urgency_id);


--
-- TOC entry 4894 (class 2606 OID 19639)
-- Name: work_order_intake fk_work_order_intake_work_area; Type: FK CONSTRAINT; Schema: stage; Owner: directus_app
--

ALTER TABLE ONLY stage.work_order_intake
    ADD CONSTRAINT fk_work_order_intake_work_area FOREIGN KEY (work_area_id) REFERENCES ref.work_area(work_area_id);


--
-- TOC entry 5100 (class 0 OID 0)
-- Dependencies: 366
-- Name: SEQUENCE work_order_completed_raw_src_row_num_seq; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT ALL ON SEQUENCE stage.work_order_completed_raw_src_row_num_seq TO directus_app;


--
-- TOC entry 5104 (class 0 OID 0)
-- Dependencies: 364
-- Name: SEQUENCE work_order_todo_raw_src_row_num_seq; Type: ACL; Schema: stage; Owner: msbadmin
--

GRANT ALL ON SEQUENCE stage.work_order_todo_raw_src_row_num_seq TO directus_app;


-- Completed on 2026-08-31 22:58:34

--
-- PostgreSQL database dump complete
--

\unrestrict yPmMLFaQh9SddBGHLc3ZhtFGsGlfRkmgjdYyMvdtCJgcc3Anr1hHuG0GFI6xapJ

