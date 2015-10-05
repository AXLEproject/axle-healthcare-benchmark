/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Setup.
 *
 * Copyright (c) 2014, Portavita B.V.
 */

\set ON_ERROR_STOP on
\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, hdl, hl7, r1, "$user";

\echo 'Check that post load document updates have been run.'
SELECT 1/EXISTS(SELECT * FROM pg_class WHERE relname='document_1_patient_id_idx')::int;
\set ON_ERROR_STOP off

/** create a one-time pseudonym **/
DROP TABLE IF EXISTS pseudonyms;
CREATE TABLE pseudonyms
AS
SELECT ids.value AS patient_id
,      crypt(ids.value, gen_salt('md5')) AS pseudonym
,      player AS patient_player
,     _id AS _id
FROM   "Patient",
       -- select only the extension from the id array where root is ...31.3.3
       jsonb_each_jsquery_text(id::"ANY"::jsonb, '#(root = "2.16.840.1.113883.2.4.3.31.3.3")') as ids
WHERE ids.key = 'extension'
;

ANALYZE pseudonyms;
