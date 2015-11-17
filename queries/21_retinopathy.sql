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
        AND       c.feature @@ 'id = "has_retinopathy"'
        AND       c.value_bool
)
SELECT  unit_of_observation
        ,       unit_of_analysis
        ,       source
        ,       feature
        ,       value_text
        ,       value_numeric
        ,       value_unit
        ,       value_pq
        ,       value_ivl_pq
        ,       value_code
        ,       value_cv
        ,       value_bool
        ,       value_ts
        ,       value_ivl_ts
        ,       value_qset_ts
        ,       time_lowvalue
        ,       time_highvalue
        ,       EXTRACT(days FROM t0 - time_lowvalue) AS time_to_t0
        ,       time_availability
FROM    base_values_with_class
WHERE   1=1 -- NOT negation_ind
AND     time_lowvalue <= t0
AND     feature @@ 'id = "365980008|OBS|EVN|completed" OR /* smoking */
        id = "266918002|OBS|EVN|completed" OR /* smoking quantity */
        id = "219006|OBS|EVN|completed" OR /* alcohol */
        id = "160573003|OBS|EVN|completed" OR /* alcohol quantity */
        id = "228450008|OBS|EVN|completed" OR /* exercise */
        id = "102739008|OBS|EVN|completed" OR /* LDL cholesterol */
        id = "102737005|OBS|EVN|completed" OR /* HDL cholestol */
        id = "166842003|OBS|EVN|completed" OR /* total/hdl cholesterol */
        id = "103232008|OBS|EVN|completed" OR /* HBA1c/GlycHb */
        id = "271000000|OBS|EVN|completed" OR /* albumine in urine */
        id = "275795003|OBS|EVN|completed" OR /* Albumin in sample */
        id = "250745003|OBS|EVN|completed" OR /* albumine/kreatinine ratio */
        id = "275792000|OBS|EVN|completed" OR /* kreatinine */
        id = "Portavita189|OBS|EVN|completed" OR /* cockroft kreatinine derivate */
        id = "Portavita304|OBS|EVN|completed" OR /* MDRD kreatinine derivate */
        id = "8480-6|OBS|EVN|completed" OR /* systolic */
        id = "8462-4|OBS|EVN|completed" OR /* diastolic */
        id = "5600001|OBS|EVN|completed" OR /* Triglyceride */
        id = "275789004|OBS|EVN|completed" OR /* Potassium */
        id = "52302001|OBS|EVN|completed" OR /* Fasting blood glucose (venous) */
        id = "38082009|OBS|EVN|completed" OR /* Hemoglobine (Hb) */
        id = "302866003|OBS|EVN|completed" OR /* Hypoglycemia (y/n) There are other indicators related to this. */
        id = "38341003|OBS|EVN|completed" OR /* Hypertension (y/n) */
        id = "228450008|OBS|EVN|completed" OR /* exercise (A,B,C,D) */
        id = "365275006|OBS|EVN|completed" OR /* well being, aka coenesthesia */
        id = "396552003|OBS|EVN|completed" OR /* Waist circumference */
        id = "60621009|OBS|EVN|completed" OR /* BMI */
        id = "Portavita1157|OBS|EVN|completed" OR /* Nephropathy (y/n) Risk factor */
        id = "312975006|OBS|EVN|completed" OR   /* Microalbuminuria (y/n) Risk factor */
        id = "Portavita1161|OBS|EVN|completed" OR /* Retinopathie (y/n) Risk factor */
        id = "Portavita1232|OBS|EVN|completed" OR /* diabetes diagnosis: the values are Type 1, 2, LADA, MODY, Generic diabetes mellitus */
        id = "Portavita1233|OBS|EVN|completed" OR /* Date of Diagnosis diabetes */
        id = "Portavita70|OBS|EVN|completed" OR /* Hypertensie bij 1e graads familieleden (y/n) */
        id = "Portavita68|OBS|EVN|completed" OR /* Diabetes bij 1e of 2e graads familieleden (y/n) */
        id = "Portavita71|OBS|EVN|completed" OR /* Cardiovascular disease with 1st degree family member. (y/n) */
        id = "Portavita220|OBS|EVN|completed" OR /* retinopathy complication */
        id = "has_retinopathy" OR /* has retinopathy feature */
        id = "age_in_years" OR    /* age in years feature */
        id = "263495000" /* Gender */
'
ORDER BY unit_of_observation, feature, t0 desc;


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
 */
CREATE VIEW retinopathy_base_summaries
AS
SELECT * FROM (
      SELECT   *
      ,        RANK() OVER (PARTITION BY unit_of_observation, feature  ORDER BY time_to_t0 ASC)  AS rocky
      ,        count(1)                  OVER (PARTITION BY unit_of_observation, feature)  AS count_value
      ,        max(value_numeric)        OVER (PARTITION BY unit_of_observation, feature)  AS max
      ,        max(time_to_t0)           OVER (PARTITION BY unit_of_observation, feature)  AS max_time_to_t0
      ,        bool_or(value_bool)       OVER (PARTITION BY unit_of_observation, feature)  AS bool_or
      FROM retinopathy_base_values
) a
WHERE rocky = 1;

/* Pivot the summary list into columns. */
CREATE TABLE retinopathy_tabular_data
AS
SELECT row_number() over()                          AS row_number
  ,       pivot_diagonal->>'pseudonym'              AS unit_of_observation
  ,       (age_in_years->>'value_numeric')::numeric AS age_in_years
  ,       gender#>>'{value_code, code}'             AS gender
-- class
  ,       has_retinopathy->>'value_bool'            AS class
-- smoking
  ,       CASE WHEN smoking#>>'{value_code, code}' = '266919005' THEN 0 -- never
               WHEN smoking#>>'{value_code, code}' = '8517006'   THEN 1 -- used to
               WHEN smoking#>>'{value_code, code}' = '77176002'  THEN 2 -- yes
               ELSE                          NULL
          END                                               AS smok_lv       -- last observed value of smoking observation
  ,       round((smoking_quantity->>'value_numeric')::numeric) AS smok_du_lv    -- smoking daily units last value
  ,       (smoking_quantity->>'count')::numeric                AS smok_du_count -- number of smoking observations before t0
-- alcohol
  ,       alcohol#>>'{value_code, code}'                       AS alcohol_lv
  ,       round((alcohol_quantity->>'value_numeric')::numeric) AS alc_wu_lv
-- exercise days per week
  ,       CASE WHEN exercise#>>'{value_code,code}' = 'A' THEN 0
               WHEN exercise#>>'{value_code,code}' = 'B' THEN 2
               WHEN exercise#>>'{value_code,code}' = 'C' THEN 4
               WHEN exercise#>>'{value_code,code}' = 'D' THEN 5
               ELSE                          NULL
          END                                                AS exercise_dpw_lv
-- wellbeing
  ,       wellbeing#>>'{value_code, code}'             AS wellbeing_lv
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
    SELECT  unit_of_observation                                       AS pivot_diagonal
    ,       feature->>'id'                                            AS category
    ,       json_build_object(
              'value_code', value_code,
              'value_numeric', value_numeric,
              'value_bool', value_bool,
              'count', count_value,
              'max', "max",
              'max_time_to_t0', max_time_to_t0,
              'time_to_t0', time_to_t0)                               AS value
    FROM  retinopathy_base_summaries
    ORDER BY pivot_diagonal, category
  $ct$,
  $ct$VALUES('365980008|OBS|EVN|completed'::text) --smoking
     ,      ('266918002|OBS|EVN|completed') -- smoking quant
     ,      ('219006|OBS|EVN|completed') -- alcohol
     ,      ('160573003|OBS|EVN|completed') -- alcohol quantity
     ,      ('228450008|OBS|EVN|completed') -- exercise
     ,      ('365275006|OBS|EVN|completed') -- wellbeing
     ,      ('102737005|OBS|EVN|completed') -- hdl cholesterol
     ,      ('166842003|OBS|EVN|completed') -- total/hdl cholesterol
     ,      ('103232008|OBS|EVN|completed') -- HBA1c/GlycHb
     ,      ('250745003|OBS|EVN|completed') -- albumine/kreatinine ratio
     ,      ('275792000|OBS|EVN|completed') -- kreatinine
     ,      ('Portavita189|OBS|EVN|completed') -- cockroft kreatinine derivate
     ,      ('Portavita304|OBS|EVN|completed') -- MDRD kreatinine derivate
     ,      ('8480-6|OBS|EVN|completed')
     ,      ('8462-4|OBS|EVN|completed')
     ,      ('has_retinopathy')
     ,      ('age_in_years')
     ,      ('263495000')  -- gender
     $ct$
  )  -- select from crosstab
  AS ct(pivot_diagonal       jsonb
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
