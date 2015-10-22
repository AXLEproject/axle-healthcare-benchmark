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

\echo 'Check that post load document updates have been run.'
SELECT 1/EXISTS(SELECT * FROM pg_class WHERE relname='document_1_patient_id_idx')::int;
\set ON_ERROR_STOP off

DELETE FROM base_values WHERE feature @@ 'id = "has_retinopathy" OR id="age_in_years"';

/** add new feature class var.
    the class var is defined as the first observation in the group of
    micro-vascular complications **/
INSERT INTO base_values
(unit_of_observation
, feature
, value_bool
, time_lowvalue
, time_highvalue
, time_to_t0
, time_availability)
      SELECT unit_of_observation                                AS unit_of_observation
      ,       json_build_object(
               'id', 'has_retinopathy',
               'comment', 'Feature contains only true positive or true negative values. Unknowns are not recorded. Therefore this feature cannot be used to count retinopathy observations.',
               'display', 'Retinopathy Class Variable')::jsonb
                                                                AS feature
      ,      CASE WHEN feature->>'id' = 'Portavita308|OBS|EVN|completed'
                  THEN value_code->>'code'  IN ('Portavita309',
                                 'Portavita310',
                                 'Portavita309,Portavita310')
                  WHEN feature->>'id' = 'Portavita220|OBS|EVN|completed'
                   AND value_code->>'code' IN ('RETINOPATHIE_LINKER_RECHTEROOG'
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
                  WHEN feature->>'id' = 'Portavita220|OBS|EVN|completed'
                   AND value_code->>'code' IN ('GEEN_RETINOPATHIE'
                                   ,'LEFT_FALSE_RIGHT_FALSE')
                                   THEN false
             END                                                AS value_bool
      ,      time_lowvalue                                      AS time_lowvalue
      ,      time_highvalue                                     AS time_highvalue
      ,      null::numeric                                      AS time_to_t0
      ,      time_availability                                  AS time_availability
FROM (
      SELECT  *
      FROM    base_values
      WHERE   feature @@ 'id = "Portavita308|OBS|EVN|completed" OR id="Portavita220|OBS|EVN|completed"'
     ) a
;

/* Add age in years. */
INSERT INTO base_values
(unit_of_observation
, feature
, value_numeric
, time_lowvalue
, time_highvalue
, time_to_t0
, time_availability)
      SELECT unit_of_observation                                AS unit_of_observation
      ,       json_build_object(
               'id', 'age_in_years',
               'display', 'Age in years')::jsonb
                                                                AS feature
      ,      (extract(year from current_timestamp)
              - extract(year from time_lowvalue))::numeric      AS value_numeric
      ,      time_lowvalue                                      AS time_lowvalue
      ,      time_highvalue                                     AS time_highvalue
      ,      null::numeric                                      AS time_to_t0
      ,      time_availability                                  AS time_availability
      FROM    base_values
      WHERE   feature @@ 'id = "184099003"'
;
