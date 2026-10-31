\set ON_ERROR_STOP on

CREATE ROLE printservice LOGIN;
CREATE ROLE label_print_mail LOGIN;
CREATE ROLE directus_app LOGIN;

CREATE SCHEMA ref;
CREATE SCHEMA ops;

CREATE TABLE ref.person (
    person_id integer PRIMARY KEY,
    preferred_name text NOT NULL,
    email text,
    active_flag boolean NOT NULL DEFAULT true
);

CREATE TABLE ref.display (
    display_id bigint PRIMARY KEY,
    display_name text NOT NULL,
    print_label boolean NOT NULL DEFAULT false,
    updated_by_person_id integer REFERENCES ref.person(person_id)
);
CREATE TABLE ref.container (
    container_id bigint PRIMARY KEY,
    location_code text,
    description text,
    print_label boolean NOT NULL DEFAULT false,
    updated_by_person_id integer REFERENCES ref.person(person_id)
);
CREATE TABLE ref.controller_model (
    controller_model_id integer PRIMARY KEY,
    model_code text NOT NULL UNIQUE,
    model_name text NOT NULL
);
CREATE TABLE ref.controller (
    controller_id bigint PRIMARY KEY,
    controller_model_id integer NOT NULL
        REFERENCES ref.controller_model(controller_model_id),
    print_label boolean NOT NULL DEFAULT false,
    updated_by_person_id integer REFERENCES ref.person(person_id)
);

CREATE TABLE ops.display_label_batch_item (
    display_label_batch_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    display_label_batch_id bigint NOT NULL,
    display_id bigint NOT NULL REFERENCES ref.display(display_id),
    printed_flag boolean NOT NULL DEFAULT false,
    printed_at timestamptz
);
CREATE TABLE ops.container_label_batch_item (
    container_label_batch_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    container_label_batch_id bigint NOT NULL,
    container_id bigint NOT NULL REFERENCES ref.container(container_id),
    printed_flag boolean NOT NULL DEFAULT false,
    printed_at timestamptz
);
CREATE TABLE ops.controller_label_batch_item (
    controller_label_batch_item_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    controller_label_batch_id bigint NOT NULL,
    controller_id bigint NOT NULL REFERENCES ref.controller(controller_id),
    printed_flag boolean NOT NULL DEFAULT false,
    printed_at timestamptz
);

INSERT INTO ref.person(person_id, preferred_name, email)
VALUES (15, 'Rick', 'rick@example.invalid'),
       (17, 'Greg', 'greg@example.invalid');
INSERT INTO ref.display(display_id, display_name)
VALUES (8, 'WV-MtCrumpit-Scaffold-01');
INSERT INTO ref.container(container_id, location_code, description)
VALUES (37, 'WAREHOUSE', 'Mt. Crumpit controller tote');
INSERT INTO ref.controller_model(
    controller_model_id, model_code, model_name
) VALUES (1, 'CTB32', 'CTB32 Generation 3 Controller Board');
INSERT INTO ref.controller(
    controller_id, controller_model_id, updated_by_person_id
) VALUES (1001, 1, 15), (1002, 1, 15), (1003, 1, 15);

GRANT USAGE ON SCHEMA ref, ops TO directus_app, printservice, label_print_mail;
GRANT SELECT, UPDATE ON ref.display, ref.container, ref.controller
    TO directus_app, printservice;

