/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Select, summarize and pivot.
 *
 * Result data is in table research.retinopathy_tabular_data.
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


DROP VIEW IF EXISTS retinopathy_base_values CASCADE;
DROP VIEW IF EXISTS retinopathy_base_summaries CASCADE;
DROP TABLE IF EXISTS retinopathy_tabular_data CASCADE;
CREATE VIEW retinopathy_base_values
AS
WITH base_values_with_class AS (
        SELECT    v.*
        ,         COALESCE(c.time_lowvalue, '20140501') AS t0
        ,         c.time_lowvalue IS NOT NULL           AS class
        FROM      base_values v
        LEFT JOIN base_values c
        ON        c.unit_of_observation = v.unit_of_observation
        AND       c.code = 'has_retinopathy'
        AND       c.value_bool
)
SELECT  unit_of_observation
        ,      location
        ,      provider
        ,      organisation
        ,      datasource_organisation
        ,      datasource_standard
        ,      datasource_software
        ,      feature_id
        ,      source_id
        ,      class_code
        ,      mood_code
        ,      status_code
        ,      code
        ,      code_codesystem
        ,      code_displayname
        ,      value_code
        ,      value_codesystem
        ,      value_displayname
        ,      value_text
        ,      value_ivl_pq
        ,      value_numeric
        ,      value_unit
        ,      value_bool
        ,      value_qset_ts
        ,      negation_ind
        ,      time_lowvalue
        ,      time_highvalue
        ,      EXTRACT(days FROM t0 - time_lowvalue) AS time_to_t0
        ,      time_availability
FROM    base_values_with_class
WHERE   1=1 -- NOT negation_ind
AND     time_lowvalue <= t0
AND     code IN ('365980008' -- smoking
              ,'266918002' -- smoking quantity
              ,'219006' -- alcohol
              ,'160573003' -- alcohol quantity
              ,'228450008' -- exercise
              ,'102739008' -- LDL cholesterol
              ,'102737005' -- HDL cholestol
              ,'166842003' -- total/hdl cholesterol
              ,'103232008' -- HBA1c/GlycHb
              ,'271000000' -- albumine in urine
              ,'275795003' -- Albumin in sample
              ,'250745003' -- albumine/kreatinine ratio
              ,'275792000' -- kreatinine
              ,'Portavita189' -- cockroft kreatinine derivate
              ,'Portavita304' -- MDRD kreatinine derivate
              ,'8480-6' -- systolic
              ,'8462-4' -- diastolic
              ,'5600001' -- Triglyceride
              ,'275789004' -- Potassium
              ,'52302001' -- Fasting blood glucose (venous)
              ,'38082009' -- Hemoglobine (Hb)
              ,'302866003' -- Hypoglycemia (y/n) There are other indicators related to this.
              ,'38341003' -- Hypertension (y/n)
              ,'228450008' -- exercise (A,B,C,D)
              ,'365275006' -- well being, aka coenesthesia
              ,'396552003' -- Waist circumference
              ,'60621009' -- BMI
              ,'Portavita1157' -- Nephropathy (y/n) Risk factor
              ,'312975006'   -- Microalbuminuria (y/n) Risk factor
              ,'Portavita1161' -- Retinopathie (y/n) Risk factor
              ,'Portavita1232' -- diabetes diagnosis: the values are Type 1, 2, LADA, MODY, Generic diabetes mellitus
              ,'Portavita1233' -- Date of Diagnosis diabetes
              ,'Portavita70' -- Hypertensie bij 1e graads familieleden (y/n)
              ,'Portavita68' -- Diabetes bij 1e of 2e graads familieleden (y/n)
              ,'Portavita71' -- Cardiovascular disease with 1st degree family member. (y/n)
              ,'Portavita220' -- retinopathy complication
              ,'has_retinopathy' -- has retinopathy feature
              ,'age_in_years'    -- age in years feature
              ,'263495000' -- Gender
)
ORDER BY unit_of_observation, code, t0 desc;

/*
 * Calculate aggregates per person, observation code.
 *
 * To query correlated data in the synthetic dataset, the last value (rank on
 * time) is queried. In the synthetic dataset, there exist only correlations
 * between observation values from the same examination (document). (In
 * addition, numerical values are only correlated to other numerical values,
 * and categorical values only to other categorical values). Since all
 * observations occur only in one kind of examination, getting the last value
 * per observation kind will result in getting e.g. systolic and diastolic bp
 * from the same document, and thus data will be paired.
 *
 * The other aggregates are for illustration purposes only. See
 * http://www.postgresql.org/docs/devel/static/functions-aggregate.html#FUNCTIONS-AGGREGATE-STATISTICS-TABLE
 * for a list.
 *
 */
CREATE VIEW retinopathy_base_summaries
AS
SELECT * FROM (
      SELECT   *
      ,        RANK() OVER (PARTITION BY unit_of_observation, code  ORDER BY time_to_t0 ASC)  AS rocky
      ,        count(1)                  OVER (PARTITION BY unit_of_observation, code)  AS count_value
      ,        max(value_numeric)        OVER (PARTITION BY unit_of_observation, code)  AS max
      ,        max(time_to_t0)           OVER (PARTITION BY unit_of_observation, code)  AS max_time_to_t0
      ,        bool_or(value_bool)       OVER (PARTITION BY unit_of_observation, code)  AS bool_or
      FROM retinopathy_base_values
) a
WHERE rocky = 1;

/* Pivot the summary list into columns. */
CREATE TABLE retinopathy_tabular_data
AS
SELECT row_number() over()                          AS row_number
  ,       (record_id->>'unit_of_observation')       AS unit_of_observation
  ,       (age_in_years->>'value_numeric')::numeric AS age_in_years
  ,       gender->>'value_code'                     AS gender
-- class
  ,       has_retinopathy->>'value_bool'            AS class
-- smoking
  ,       CASE WHEN smoking->>'value_code' = '266919005' THEN 0 -- never
               WHEN smoking->>'value_code' = '8517006'   THEN 1 -- used to
               WHEN smoking->>'value_code' = '77176002'  THEN 2 -- yes
               ELSE                          NULL
          END                                               AS smok_lv       -- last observed value of smoking observation
  ,       round((smoking_quantity->>'value_numeric')::numeric) AS smok_du_lv    -- smoking daily units last value
  ,       (smoking_quantity->>'count')::numeric                AS smok_du_count -- number of smoking observations before t0
-- alcohol
  ,       alcohol->>'value_code'                               AS alcohol_lv
  ,       round((alcohol_quantity->>'value_numeric')::numeric) AS alc_wu_lv
-- exercise days per week
  ,       CASE WHEN exercise->>'value_code' = 'A' THEN 0
               WHEN exercise->>'value_code' = 'B' THEN 2
               WHEN exercise->>'value_code' = 'C' THEN 4
               WHEN exercise->>'value_code' = 'D' THEN 5
               ELSE                          NULL
          END                                                AS exercise_dpw_lv
-- wellbeing
  ,       wellbeing->>'value_code'                     AS wellbeing_lv
-- hdl
  ,       (hdl->>'value_numeric')::numeric                   AS hdl_lv
-- total cholesterol / hdl cholesterol
  ,       (total_hdl->>'value_numeric')::numeric             AS total_hdl_lv
-- systolic blood pressure
  ,       (systolic->>'value_numeric')::numeric              AS systolic_lv
-- diastolic blood pressure
  ,       (diastolic->>'value_numeric')::numeric             AS diastolic_lv
-- hba1c
  ,       (hba1c->>'value_numeric')::numeric                 AS hba1c_lv
-- albumine
  ,       (albumine->>'value_numeric')::numeric              AS albumine_lv
-- kreatinine
  ,       (kreatinine->>'value_numeric')::numeric            AS kreatinine_lv
-- cockroft
  ,       (cockroft->>'value_numeric')::numeric              AS cockroft_lv
-- mdrd
  ,       (mdrd->>'value_numeric')::numeric                  AS mdrd_lv
FROM crosstab($ct$
    SELECT json_object(('{ unit_of_observation, '         || unit_of_observation  ||
                        '}')::text[])::text                           AS record_id
    ,       code                                                      AS category

    ,       json_object(('{value_code, '      || COALESCE(value_code::text, 'NULL')     ||
                         ',value_numeric, '   || COALESCE(value_numeric::text, 'NULL')  ||
                         ',value_bool, '      || COALESCE(value_bool::text, 'NULL')  ||
                         ',count, '           || COALESCE(count_value::text, 'NULL')    ||
                         ',max, '             || COALESCE(max::text, 'NULL')            ||
                         ',max_time_to_t0, '  || COALESCE(max_time_to_t0::text, 'NULL') ||
                         ',time_to_t0, '      || COALESCE(time_to_t0::text, 'NULL')     ||
                         '}')::text[])::text                          AS value
    FROM  retinopathy_base_summaries
    ORDER BY record_id, category
  $ct$,
  $ct$VALUES('365980008'::text) --smoking
     ,      ('266918002') -- smoking quant
     ,      ('219006') -- alcohol
     ,      ('160573003') -- alcohol quantity
     ,      ('228450008') -- exercise
     ,      ('365275006') -- wellbeing
     ,      ('102737005') -- hdl cholesterol
     ,      ('166842003') -- total/hdl cholesterol
     ,      ('103232008') -- HBA1c/GlycHb
     ,      ('250745003') -- albumine/kreatinine ratio
     ,      ('275792000') -- kreatinine
     ,      ('Portavita189') -- cockroft kreatinine derivate
     ,      ('Portavita304') -- MDRD kreatinine derivate
     ,      ('8480-6')
     ,      ('8462-4')
     ,      ('has_retinopathy')
     ,      ('age_in_years')
     ,      ('263495000')  -- gender
     $ct$
  )  -- select from crosstab
  AS ct(record_id            jsonb
       ,"smoking"            jsonb
       ,"smoking_quantity"   jsonb
       ,"alcohol"            jsonb
       ,"alcohol_quantity"   jsonb
       ,"exercise"           jsonb
       ,"wellbeing"          jsonb
       ,"hdl"                jsonb
       ,"total_hdl"          jsonb
       ,"hba1c"              jsonb
       ,"albumine"           jsonb
       ,"kreatinine"         jsonb
       ,"cockroft"           jsonb
       ,"mdrd"               jsonb
       ,"systolic"           jsonb
       ,"diastolic"          jsonb
       ,"has_retinopathy"    jsonb
       ,"age_in_years"       jsonb
       ,"gender"             jsonb
  )
;

