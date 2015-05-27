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

\set ON_ERROR_STOP off

/** step one create base values **/
DROP TABLE IF EXISTS base_values CASCADE;
CREATE TABLE base_values
AS
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
      ,       null::numeric                                      AS value_real
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
      ON      ptnt.player = ptnt_player

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
      ,       null::numeric                                      AS value_real
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
      ON      ptnt.player = ptnt_player

      UNION ALL

      /** observation **/
      SELECT  pseudonym                                          AS unit_of_observation
      ,       null::text                                         AS location
      ,       null::text[]                                       AS provider
      ,       null::text                                         AS organisation
      ,       null::text                                         AS datasource_organisation
      ,       null::text                                         AS datasource_standard
      ,       null::text                                         AS datasource_software
      ,       null::text                                         AS feature_id
      ,       obse._id::text                                     AS source_id
      ,       obse."classCode"->>'code'                          AS class_code
      ,       obse."moodCode"->>'code'                           AS mood_code
      ,       obse."statusCode"->>'code'                         AS status_code
      ,       obse._code_code                                    AS code
      ,       obse._code_codesystem                              AS code_codesystem
      ,       obse.code->>'displayName'                          AS code_displayname
      ,       obse._value_code_code                              AS value_code
      ,       obse.value->>'codeSystem'                          AS value_codesystem
      ,       obse.value->>'displayName'                         AS value_displayname
      ,       null::text                                         AS value_text
      ,       obse._value_ivl_real::text                         AS value_ivl_pq
      ,       COALESCE(obse._value_pq_value::float8, obse._value_real, obse._value_int)  AS value_real
      ,       null::boolean                                      AS value_bool
      ,       null::text                                         AS value_qset_ts
      ,       obse."negationInd"::bool                           AS negation_ind
      ,       obse._effective_time_low                           AS time_lowvalue
      ,       obse._effective_time_high                          AS time_highvalue
      ,       null::numeric                                      AS time_to_t0
      ,       obse._lake_timestamp::timestamptz                  AS time_availability
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      JOIN    pseudonyms
      ON      ptnt.player = ptnt_player
;
