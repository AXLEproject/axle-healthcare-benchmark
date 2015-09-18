/*
 * (c) 2015 Portavita B.V.
 * All rights reserved
 *
 * Create the blobstore
 *
 */
SET client_min_messages to warning;

CREATE SEQUENCE document_sequence CACHE 64;

CREATE TABLE document_template (
       id                      bigint,
       patient_id              text,
       row_name                jsonb,
       _lake_timestamp         timestamptz,
       document                jsonb
);

CREATE TABLE document (LIKE document_template);

CREATE OR REPLACE FUNCTION add_document_partition(name text)
RETURNS void
AS $create$
BEGIN
EXECUTE 'CREATE TABLE document_' || name || '(LIKE document_template)';

EXECUTE $sql$
       ALTER TABLE document_$sql$||name||$sql$ INHERIT document;$sql$;
EXECUTE $sql$
       ALTER TABLE document_$sql$||name||$sql$ ALTER COLUMN id SET DEFAULT nextval('document_sequence');$sql$;
EXECUTE $sql$
       ALTER TABLE document_$sql$||name||$sql$ ALTER COLUMN _lake_timestamp SET DEFAULT now();$sql$;
END;
$create$
LANGUAGE plpgsql;

/* Create 400 partitions */
WITH part AS (
  SELECT add_document_partition(i::text) FROM generate_series(1,400) AS g(i)
)
SELECT count(*) from part;

CREATE OR REPLACE FUNCTION alter_document_index(name text, action text)
RETURNS void
AS $index$
BEGIN
IF action = 'create' THEN
  EXECUTE $sql$
          CREATE INDEX document_$sql$ || name ||
                 $sql$_patient_id_idx ON document_$sql$ || name || $sql$(patient_id)$sql$;
ELSIF ACTION = 'drop' THEN
  EXECUTE $sql$
          DROP INDEX document_$sql$ || name || $sql$_patient_id_idx$sql$;
END IF;
END;
$index$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_document_indexes()
RETURNS bigint
AS $indexes$
  /* Create 400 indexes */
  WITH part AS (
    SELECT alter_document_index(i::text, 'create') FROM generate_series(1,400) AS g(i)
  )
  SELECT count(*) from part;
$indexes$
LANGUAGE sql;

CREATE OR REPLACE FUNCTION drop_document_indexes()
RETURNS bigint
AS $indexes$
  /* Create 400 indexes */
  WITH part AS (
    SELECT alter_document_index(i::text, 'drop') FROM generate_series(1,400) AS g(i)
  )
  SELECT count(*) from part;
$indexes$
LANGUAGE sql;

