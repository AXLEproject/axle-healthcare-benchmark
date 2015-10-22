/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Step 1: create base values.
 *
 * Copyright (c) 2015, Portavita B.V.
 */

\set ON_ERROR_STOP on
\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, hdl, hl7, r1, "$user";

\echo 'Check that post load document updates have been run.'
SELECT 1/EXISTS(SELECT * FROM pg_class WHERE relname='document_1_patient_id_idx')::int;
--\set ON_ERROR_STOP off

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
   'author', concat_ws(':',
                       document#>>'{author,0,assignedAuthor,id,0,root}',
                       document#>>'{author,0,assignedAuthor,id,0,extension}'),
   'legalAuthenticator', concat_ws(':',
                                   document#>>'{legalAuthenticator,assignedEntity,id,0,root}',
                                   document#>>'{legalAuthenticator,assignedEntity,id,0,extension}'),
   'custodian', json_build_object(
       'id', concat_ws(':',
                document#>>'{custodian, assignedCustodian, representedCustodianOrganization, id, 0, root}',
                document#>>'{custodian, assignedCustodian, representedCustodianOrganization, id, 0, extension}'),
       'name', document#>>'{custodian, assignedCustodian, representedCustodianOrganization, name, content}'),
   'serviceEvent', document#>>'{documentationOf,0,serviceEvent,id,0,extension}')::jsonb
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
      SELECT  json_build_object(
                'pseudonym', pseudonym,
                'display', pseudonym)::jsonb                     AS unit_of_observation
      ,       json_build_object(
                'author', json_build_object(
                    'display', 'Author ' || (obse.row_name->>'author')),
                'organization', json_build_object(
                    'display', 'Organization ' || (obse.row_name->>'legalAuthenticator')),
                'carePlan', json_build_object(
                    'display', 'CarePlan ' || (obse.row_name->>'serviceEvent'))
                    )::jsonb                                     AS unit_of_analysis
      ,       json_build_object(
                'organization', json_build_object(
                    'reference', 'Organization/' || (obse.row_name#>>'{custodian,id}'),
                    'display', obse.row_name#>>'{custodian,name}'),
                'standard', 'CDA R2',
                'software', 'Portavita Benchmark',
                'display', 'CDA R2 (Portavita Benchmark)',
                'id', obse.id#>>'{0,extension}')::jsonb          AS source
      ,       json_build_object(
                'id', concat_ws('|',
                             obse.code->>'code',
                             trim(obse."classCode"::text, '"'),
                             trim(obse."moodCode"::text, '"'),
                             obse."statusCode"->>'code'),
                'display', concat_ws(' ',
                             obse.code->>'displayName',
                             '(' || displayname(trim(obse."classCode"::text,'"')::cv('ActClass')),
                             displayname(trim(obse."moodCode"::text,'"')::cv('ActMood')),
                             obse."statusCode"->>'code' || ')'),
                'classCode', obse."classCode",
                'moodCode', obse."moodCode",
                'statusCode', obse."statusCode",
                'code', obse.code,
                'negationInd', btrim("negationInd"::text,'"')
               )::jsonb                                          AS feature
      ,       null::text                                         AS value_text
      ,       (obse.value#>>'{0,value}')::numeric                AS value_numeric
      ,       obse.value#>>'{0,unit}'                            AS value_unit
      ,       CASE WHEN obse.value#>>'{0,unit}' IS NOT NULL THEN
               concat_ws(' ', obse.value#>>'{0,value}', obse.value#>>'{0,unit}')::pq
              ELSE NULL::pq END                                  AS value_pq
      ,       null::ivl_pq                                       AS value_ivl_pq
      ,       CASE WHEN obse.value#>>'{0, code}' IS NOT NULL THEN
               json_build_object(
                'system', obse.value#>>'{0,codeSystem}',
                'code', obse.value#>>'{0,code}',
                'display', obse.value#>>'{0,displayName}')::jsonb
              ELSE NULL::jsonb END                               AS value_code
      ,       null::cv                                           AS value_cv
      ,       null::boolean                                      AS value_bool
      ,       null::ts                                           AS value_ts
      ,       null::ivl_ts                                       AS value_ivl_ts
      ,       null::qset_ts                                      AS value_qset_ts
      ,       lowvalue(obse."effectiveTime"::"ANY"::"IVL_TS"::ivl_ts)::timestamptz AS time_lowvalue
      ,       highvalue(obse."effectiveTime"::"ANY"::"IVL_TS"::ivl_ts)::timestamptz AS time_highvalue
      ,       null::numeric                                      AS time_to_t0
      ,       null::timestamptz                                  AS time_availability
      FROM    Observations_of_patient_sample obse
      JOIN    pseudonyms p
      ON      obse.row_name->>'patient_id' = p.patient_id

      UNION ALL

      /** person birth time **/
      SELECT  json_build_object(
                'pseudonym', pseudonym,
                'display', pseudonym)::jsonb                     AS unit_of_observation
      ,       null::jsonb                                        AS unit_of_analysis
      ,       json_build_object(
                'standard', 'HL7v3 RIM',
                'software', 'Portavita Benchmark',
                'display', 'Person Entity Table',
                'comment', 'query on Person table'
                )::jsonb                                         AS source
      ,       json_build_object(
               'id', '184099003',
               'code', json_build_object(
                'system', '2.16.840.1.113883.6.96',
                'code', '184099003'),
               'display', 'Date of birth')::jsonb
                                                                 AS feature
      ,       null::text                                         AS value_text
      ,       null::numeric                                      AS value_numeric
      ,       null::text                                         AS value_unit
      ,       null::pq                                           AS value_pq
      ,       null::ivl_pq                                       AS value_ivl_pq
      ,       null::jsonb                                        AS value_code
      ,       null::cv                                           AS value_cv
      ,       null::boolean                                      AS value_bool
      ,       peso."birthTime"::ts                               AS value_ts
      ,       null::ivl_ts                                       AS value_ivl_ts
      ,       null::qset_ts                                      AS value_qset_ts
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
      SELECT  json_build_object(
                'pseudonym', pseudonym,
                'display', pseudonym)::jsonb                     AS unit_of_observation
      ,       null::jsonb                                        AS unit_of_analysis
      ,       json_build_object(
                'standard', 'HL7v3 RIM',
                'software', 'Portavita Benchmark',
                'display', 'Person Entity Table',
                'comment', 'query on Person table'
                )::jsonb                                         AS source
      ,       json_build_object(
               'id', '263495000',
               'code', json_build_object(
                'system', '2.16.840.1.113883.6.96',
                'code', '184099003'),
               'display', 'Gender')::jsonb
                                                                 AS feature
      ,       null::text                                         AS value_text
      ,       null::numeric                                      AS value_numeric
      ,       null::text                                         AS value_unit
      ,       null::pq                                           AS value_pq
      ,       null::ivl_pq                                       AS value_ivl_pq
      ,       json_build_object(
                'system', peso."administrativeGenderCode"->>'codeSystem',
                'code', peso."administrativeGenderCode"->>'code',
                'display', peso."administrativeGenderCode"->>'displayName')::jsonb
                                                                 AS value_code
      ,       null::cv                                           AS value_cv
      ,       null::boolean                                      AS value_bool
      ,       null::ts                                           AS value_ts
      ,       null::ivl_ts                                       AS value_ivl_ts
      ,       null::qset_ts                                      AS value_qset_ts
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


ALTER TABLE base_values ADD CONSTRAINT feature_id CHECK (feature ? 'id');
ALTER TABLE base_values ADD CONSTRAINT feature_display CHECK (feature ? 'display');
ALTER TABLE base_values ADD CONSTRAINT unit_of_observation_display CHECK (unit_of_observation ? 'display');
