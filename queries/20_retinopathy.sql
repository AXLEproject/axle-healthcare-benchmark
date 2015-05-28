/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Add features
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

/** add new feature class var.
    the class var is defined as the first observation in the group of
    micro-vascular complications **/
DELETE FROM base_values WHERE feature_id = 'has_retinopathy';
INSERT INTO base_values
(unit_of_observation
, feature_id
, source_id
, class_code
, mood_code
, status_code
, code
, code_codesystem
, code_displayname
, value_code
, value_codesystem
, value_displayname
, value_text
, value_ivl_pq
, value_numeric
, value_bool
, value_qset_ts
, negation_ind
, time_lowvalue
, time_highvalue
, time_to_t0
, time_availability)
      SELECT unit_of_observation                                AS unit_of_observation
      ,      'has_retinopathy'::text                            AS feature_id
      ,      null::text                                         AS source_id
      ,      null::text                                         AS class_code
      ,      null::text                                         AS mood_code
      ,      null::text                                         AS status_code
      ,      'has_retinopathy'::text                            AS code
      ,      'FXP codesystem TBD'::text                         AS code_codesystem
      ,      'Retinopathy class variable'::text                 AS code_displayname
      ,      null::text                                         AS value_code
      ,      null::text                                         AS value_codesystem
      ,      null::text                                         AS value_displayname
      ,      null::text                                         AS value_text
      ,      null::text                                         AS value_ivl_pq
      ,      null::numeric                                      AS value_numeric
      ,      CASE WHEN (code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
                   AND code = 'Portavita308')
                  THEN value_code IN ('Portavita309',
                                 'Portavita310',
                                 'Portavita309,Portavita310')
                  WHEN (code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
                   AND code = 'Portavita220')
                   AND value_code IN ('RETINOPATHIE_LINKER_RECHTEROOG'
                                   ,'RETINOPATHIE_LINKEROOG'
                                   ,'RETINOPATHIE_RECHTEROOG'
                                   ,'LEFT_UNKNOWN_RIGHT_TRUE'
                                   ,'LEFT_TRUE_RIGHT_UNKNOWN'
                                   ,'LEFT_TRUE_RIGHT_TRUE'
                                   ,'LEFT_TRUE_RIGHT_FALSE'
                                   ,'LEFT_TRUE_RIGHT_UNCLEAR'
                                   ,'LEFT_FALSE_RIGHT_TRUE'
                                   ,'LEFT_UNCLEAR_RIGHT_TRUE')
                                   THEN true
                  WHEN (code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
                   AND code = 'Portavita220')
                   AND value_code IN ('GEEN_RETINOPATHIE'
                                   ,'LEFT_FALSE_RIGHT_FALSE')
                                   THEN false
             END = NOT /*xor*/ (negation_ind::bool)             AS value_bool
      ,      null::text                                         AS value_qset_ts
      ,      false::boolean                                     AS negation_ind
      ,      time_lowvalue                                      AS time_lowvalue
      ,      time_highvalue                                     AS time_highvalue
      ,      null::numeric                                      AS time_to_t0
      ,      time_availability                                  AS time_availability
FROM (
      SELECT  *
      FROM    base_values
      WHERE   code IN ('Portavita308'
                      ,'Portavita220')
      ) a
;

/* Add age in years. */
DELETE FROM base_values WHERE feature_id = 'age_in_years';
INSERT INTO base_values
(unit_of_observation
, feature_id
, source_id
, class_code
, mood_code
, status_code
, code
, code_codesystem
, code_displayname
, value_code
, value_codesystem
, value_displayname
, value_text
, value_ivl_pq
, value_numeric
, value_bool
, value_qset_ts
, negation_ind
, time_lowvalue
, time_highvalue
, time_to_t0
, time_availability)
      SELECT unit_of_observation                                AS unit_of_observation
      ,      'age_in_years'::text                               AS feature_id
      ,      null::text                                         AS source_id
      ,      null::text                                         AS class_code
      ,      null::text                                         AS mood_code
      ,      null::text                                         AS status_code
      ,      'age_in_years'::text                               AS code
      ,      'FXP codesystem TBD'::text                         AS code_codesystem
      ,      'Age in years'::text                               AS code_displayname
      ,      null::text                                         AS value_code
      ,      null::text                                         AS value_codesystem
      ,      null::text                                         AS value_displayname
      ,      null::text                                         AS value_text
      ,      null::text                                         AS value_ivl_pq
      ,      (extract(year from current_timestamp)
              - extract(year from time_lowvalue))::numeric      AS value_numeric
      ,      null::boolean                                      AS value_bool
      ,      null::text                                         AS value_qset_ts
      ,      false::boolean                                     AS negation_ind
      ,      time_lowvalue                                      AS time_lowvalue
      ,      time_highvalue                                     AS time_highvalue
      ,      null::numeric                                      AS time_to_t0
      ,      time_availability                                  AS time_availability
      FROM    base_values
      WHERE   code='184099003'
      AND     code_codesystem = '2.16.840.1.113883.6.96'
      AND     NOT (negation_ind::bool)
;
