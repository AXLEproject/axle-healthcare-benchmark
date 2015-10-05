/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Step 1: create base values.
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

\set number_of_patients_in_sample 30
\set patient_sample_seed 250502

SET random_page_cost to 0.1;

/** step one create base values **/
DROP TABLE IF EXISTS base_values CASCADE;

/* The following view gets the extension of id root 31.3.3 from a % of the Patient */
CREATE OR REPLACE FUNCTION create_patient_sample_view(number_of_patients_in_sample int, seed int) RETURNS VOID
AS $block$
DECLARE percentage float;
BEGIN
  SELECT number_of_patients_in_sample * 100::float /*percent*/ /count(*)
  INTO percentage
  from pseudonyms;

  EXECUTE $create$
    CREATE OR REPLACE VIEW Patient_sample
    AS
    SELECT patient_id
    ,      _id
    FROM   pseudonyms
                TABLESAMPLE BERNOULLI ($create$ || percentage || $create$)
                REPEATABLE ($create$ || seed || $create$)
  $create$;
END $block$
LANGUAGE plpgsql;

SELECT create_patient_sample_view(:number_of_patients_in_sample, :patient_sample_seed);


CREATE OR REPLACE VIEW Document_of_patient_sample
AS
 WITH docinfo AS
 (
  -- use WITH QUERY query as optimization fence to prevent parsing the id columns for each object
  -- key value pair from the jsonb_each_jsquery call below
  SELECT document, json_build_object(
   'row_id', id,
   'document_id', document#>>'{id,extension}',
   'patient_id', document#>>'{recordTarget,0,patientRole,id,0,extension}',
   'author_id', document#>>'{author,0,assignedAuthor,id,0,extension}',
   'legalauthenticator_id', document#>>'{legalAuthenticator,assignedEntity,id,0,extension}',
   'serviceevent_id', document#>>'{documentationOf,0,serviceEvent,id,0,extension}')::jsonb
   AS row_name
  FROM document
  NATURAL JOIN Patient_sample
 )
 SELECT docinfo.row_name || json_build_object('number', observations.number)::jsonb as row_name,
        observations.key, observations.value
 FROM docinfo,
      jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
 WHERE observations.key IN ('id', 'classCode', 'moodCode', 'statusCode', 'code', 'value', 'negationInd', 'effectiveTime')
 /* not needed since SRF scan returns rows in the right order  ORDER BY row_name, observations.key */
;

/** Query to get Observation objects pivoted from JSON blobs **/
CREATE OR REPLACE VIEW Observations_of_patient_sample
AS
SELECT *
FROM crosstab
(
 $ct$
 SELECT * FROM Document_of_patient_sample
$ct$,
$ct$VALUES('id'), ('classCode'), ('moodCode'), ('statusCode'), ('code'), ('value'), ('negationInd'), ('effectiveTime')
$ct$
) -- crosstab(
AS ct(row_name jsonb,
   "id" jsonb,
   "classCode" jsonb,
   "moodCode" jsonb,
   "statusCode" jsonb,
   "code" jsonb,
   "value" jsonb,
   "negationInd" jsonb,
   "effectiveTime" jsonb
)
;

CREATE TABLE base_values
AS
      SELECT  pseudonym                                          AS unit_of_observation
      ,       null::text                                         AS location
      ,       null::text[]                                       AS provider
      ,       obse.row_name->>'legalauthenticator_id'            AS organisation
      ,       'Portavita'::text                                  AS datasource_organisation
      ,       'CDA R2, FHIR DSTU1'::text                         AS datasource_standard
      ,       'Portavita Benchmark'::text                        AS datasource_software
      ,       null::text                                         AS feature_id
      ,       obse.id#>>'{0,extension}'                          AS source_id
      ,       obse."classCode"::text                             AS class_code
      ,       obse."moodCode"::text                              AS mood_code
      ,       obse."statusCode"->>'code'                         AS status_code
      ,       obse.code->>'code'                                 AS code
      ,       obse.code->>'codeSystem'                           AS code_codesystem
      ,       obse.code->>'displayName'                          AS code_displayname
      ,       obse.value#>>'{0,code}'                            AS value_code
      ,       obse.value#>>'{0,codeSystem}'                      AS value_codesystem
      ,       obse.value#>>'{0,displayName}'                     AS value_displayname
      ,       null::text                                         AS value_text
      ,       null::text                                         AS value_ivl_pq
      ,       (obse.value#>>'{0,value}')::numeric                AS value_numeric
      ,       obse.value#>>'{0,unit}'                            AS value_unit
      ,       null::boolean                                      AS value_bool
      ,       null::text                                         AS value_qset_ts
      ,       btrim("negationInd"::text,'"')::bool               AS negation_ind
      ,       lowvalue(obse."effectiveTime"::"ANY"::"IVL_TS"::ivl_ts)::timestamptz AS time_lowvalue
      ,       highvalue(obse."effectiveTime"::"ANY"::"IVL_TS"::ivl_ts)::timestamptz AS time_highvalue
      ,       null::numeric                                      AS time_to_t0
--      ,       obse._lake_timestamp::timestamptz                  AS time_availability
      ,       null::timestamptz                                  AS time_availability
      FROM    Observations_of_patient_sample obse
      JOIN    pseudonyms p
      ON      obse.row_name->>'patient_id' = p.patient_id

      UNION ALL

      /** person birth time **/
      SELECT  pseudonym                                          AS unit_of_observation
      ,       null::text                                         AS location
      ,       null::text[]                                       AS provider
      ,       null::text                                         AS organisation
      ,       null::text                                         AS datasource_organisation
      ,       null::text                                         AS datasource_standard
      ,       null::text                                         AS datasource_software
      ,       null::text                                         AS feature_id
      ,       peso._id::text                                     AS source_id
      ,       peso."classCode"->>'code'                          AS class_code
      ,       null::text                                         AS mood_code
      ,       null::text                                         AS status_code
      ,       '184099003'::text                                  AS code
      ,       '2.16.840.1.113883.6.96'::text                     AS code_codesystem
      ,       'Date of birth'::text                              AS code_displayname
      ,       null::text                                         AS value_code
      ,       null::text                                         AS value_codesystem
      ,       null::text                                         AS value_displayname
      ,       null::text                                         AS value_text
      ,       null::text                                         AS value_ivl_pq
      ,       null::numeric                                      AS value_numeric
      ,       null::text                                         AS value_unit
      ,       null::boolean                                      AS value_bool
      ,       null::text                                         AS value_qset_ts
      ,       false::bool                                        AS negation_ind
      ,       peso."birthTime"::timestamptz                      AS time_lowvalue
      ,       null::timestamptz                                  AS time_highvalue
      ,       null::numeric                                      AS time_to_t0
      ,       peso._lake_timestamp::timestamptz                  AS time_availability
      FROM    "Patient"                                ptnt
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    pseudonyms
      ON      ptnt.player = patient_player
      JOIN    Patient_sample ps
      ON      ptnt._id = ps._id

      UNION ALL

      /** person gender **/
      SELECT  pseudonym                                          AS unit_of_observation
      ,       null::text                                         AS location
      ,       null::text[]                                       AS provider
      ,       null::text                                         AS organisation
      ,       null::text                                         AS datasource_organisation
      ,       null::text                                         AS datasource_standard
      ,       null::text                                         AS datasource_software
      ,       null::text                                         AS feature_id
      ,       peso._id::text                                     AS source_id
      ,       peso."classCode"->>'code'                          AS class_code
      ,       null::text                                         AS mood_code
      ,       null::text                                         AS status_code
      ,       '263495000'::text                                  AS code
      ,       '2.16.840.1.113883.6.96'::text                     AS code_codesystem
      ,       'Gender'::text                                     AS code_displayname
      ,       peso."administrativeGenderCode"->>'code'           AS value_code
      ,       peso."administrativeGenderCode"->>'codeSystem'     AS value_codesystem
      ,       peso."administrativeGenderCode"->>'displayName'    AS value_displayname
      ,       null::text                                         AS value_text
      ,       null::text                                         AS value_ivl_pq
      ,       null::numeric                                      AS value_numeric
      ,       null::text                                         AS value_unit
      ,       null::boolean                                      AS value_bool
      ,       null::text                                         AS value_qset_ts
      ,       false::bool                                        AS negation_ind
      ,       peso."birthTime"::timestamptz                      AS time_lowvalue
      ,       null::timestamptz                                  AS time_highvalue
      ,       null::numeric                                      AS time_to_t0
      ,       peso._lake_timestamp::timestamptz                  AS time_availability
      FROM    "Patient"                                ptnt
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    pseudonyms
      ON      ptnt.player = patient_player
      JOIN    Patient_sample ps
      ON      ptnt._id = ps._id
;