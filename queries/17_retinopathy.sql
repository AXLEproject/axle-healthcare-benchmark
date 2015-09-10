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
\i retinopathy_checks.sql
\set ON_ERROR_STOP off

/** create a one-time pseudonym **/
DROP TABLE IF EXISTS pseudonyms;
CREATE TABLE pseudonyms
AS
SELECT ids.value AS patient_id
,      crypt(ids.value, gen_salt('md5')) AS pseudonym
,      player AS patient_player
FROM   "Patient",
       -- select only the extension from the id array where root is ...31.3.3
       jsonb_each_jsquery_text(id::"ANY"::jsonb, '#(root = "2.16.840.1.113883.2.4.3.31.3.3")') as ids
WHERE ids.key = 'extension'
;
