/*
 * query      : angiopathy.sql
 * description: create angiopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Observation kinds:
 * - smoking y/n and daily units
 * - alcohol y/n and weekly units
 * - exercise days per week
 * - bloodpressure systolic and diastolic
 * - total / HDL cholesterol
 * - gender
 * - age
 *
 * Classifier is '400047006' peripheral vascular disease (PVD)
 * (retinopathy
 *  renal failure
 *  foot complication)
 *
 * This script creates the following views:
 *
 *  classifier          a list of retinopathy and PVD observations
 *  base_values         a list of observations and basic patient data
 *                        birthtime is safe harbor de-identified:
 *                        age in years and all >89 as 95
 *  rtp_base_values     classifier and base_values combined for only
 *                      observations that are risk factor for PVD.
 *                        t0 is time of classifier diagnosis or fixed 20140501
 *                        observation dates replaced with time before t0
 *  rtp_base_summaries  convert base_values list into one record per patient, code
 *
 * Based on the base_summaries, the following table is materialized:
 *
 *  rtp_tabular_data    convert base_summaries into one record per patient.
 *
 * Copyright (c) 2014, Portavita B.V.
 */

\set ON_ERROR_STOP on

\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, pg_hl7, hl7, "$user";

\set ON_ERROR_STOP off

DROP VIEW classifier CASCADE;
CREATE VIEW classifier AS
      SELECT * FROM (
      SELECT  abs(hashtext('4xl3' || ptnt.player::text))  AS pseudonym
      ,       obse._code_code                       AS code
      ,       obse._effective_time_low              AS time
      ,       RANK() OVER (PARTITION BY ptnt.player, obse._code_code
                           ORDER BY obse._effective_time_low DESC, obse._id DESC) AS rocky
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      WHERE  (NOT (obse."negationInd")
              AND    obse._code_codesystem = '2.16.840.1.113883.6.96'
              AND    obse._code_code = '400047006'    -- peripheral vascular disease
              AND    obse._value_code_code = 'Y')
      OR
             (NOT (obse."negationInd")
              AND    obse._code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
              AND    obse._code_code = 'Portavita220' -- diabetic retinopathy
              AND    obse._value_code_code IN ('RETINOPATHIE_RECHTEROOG', 'RETINOPATHIE_LINKER_RECHTEROOG', 'RETINOPATHIE_LINKEROOG'))
      ) a
      WHERE rocky = 1;

DROP VIEW base_values CASCADE;
CREATE VIEW base_values
AS
      SELECT  abs(hashtext('4xl3' || ptnt.player::text))  AS pseudonym
      ,       obse._code_code                       AS code
      ,       CASE WHEN
                   extract(year from current_timestamp) - extract(year from peso."birthTime"::timestamptz) < 90
                   THEN
                   extract(year from current_timestamp) - extract(year from peso."birthTime"::timestamptz)
                   ELSE 95
              END  AS age_in_years
      ,       peso."administrativeGenderCode"->>'code' AS gender
      ,       obse._value_code_code                 AS value_code
      ,       obse._value_ivl_real                  AS value_ivl
      ,       COALESCE(obse._value_pq_value::float8, obse._value_real, obse._value_int)  AS value_float
      ,       obse._effective_time_low              AS obs_time
      ,       obse."negationInd"                    AS negation_ind
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
;

-- observation lists with classifier for retinopathy
-- DROP VIEW rtp_base_values CASCADE;
CREATE VIEW rtp_base_values
AS
WITH base_values_with_classifier AS (
        SELECT    v.*
        ,         COALESCE(c.time, '20140501') AS t0
        ,         c.time IS NOT NULL           AS classifier
        FROM      base_values v
        LEFT JOIN classifier c
        ON        c.pseudonym = v.pseudonym
        AND       c.code = 'Portavita220' -- diabetic retinopathy
)
SELECT  pseudonym
        ,      code
        ,      age_in_years
        ,      gender
        ,      value_code
        ,      value_ivl
        ,      value_float
        ,      EXTRACT(days FROM t0 - obs_time) AS days_to_t0
        ,      classifier
FROM    base_values_with_classifier
WHERE   1=1 -- NOT negation_ind
AND     obs_time <= t0
AND     code IN ('365980008' -- smoking
              ,'266918002' -- smoking quantity
              ,'219006' -- alcohol
              ,'160573003' -- alcohol quantity
              ,'228450008' -- exercise
              ,'102737005' -- HDL cholestol
              ,'166842003' -- total/hdl cholesterol
              ,'103232008' -- HBA1c/GlycHb
              ,'250745003' -- albumine/kreatinine ratio
              ,'275792000' -- kreatinine
              ,'Portavita189' -- cockroft kreatinine derivate
              ,'Portavita304' -- MDRD kreatinine derivate
              ,'8480-6' -- systolic
              ,'8462-4' -- diastolic
)
ORDER BY pseudonym, code, t0 desc;


/*
 * Calculate statistics aggregates per person,observation code.
 *
 * Select the last value, the number of values and other aggregates.
 * See http://www.postgresql.org/docs/devel/static/functions-aggregate.html#FUNCTIONS-AGGREGATE-STATISTICS-TABLE
 * for a list.
 */
-- DROP VIEW rtp_base_summaries CASCADE;
CREATE VIEW rtp_base_summaries
AS
SELECT * FROM (
      SELECT   *
      ,        RANK() OVER (PARTITION BY pseudonym, code  ORDER BY days_to_t0 ASC)  AS rocky
      ,        count(1)                  OVER (PARTITION BY pseudonym, code)  AS count_value
      ,        avg(value_float)          OVER (PARTITION BY pseudonym, code)  AS avg
      ,        min(value_float)          OVER (PARTITION BY pseudonym, code)  AS min
      ,        max(value_float)          OVER (PARTITION BY pseudonym, code)  AS max
      ,        max(days_to_t0)           OVER (PARTITION BY pseudonym, code)  AS max_days_to_t0
      ,        stddev_pop(value_float)   OVER (PARTITION BY pseudonym, code)  AS stddev_pop
--      ,        string_agg( value_code, '|')    OVER (PARTITION BY pseudonym, code)  AS codes
       FROM rtp_base_values
) a
WHERE rocky = 1;

/* Pivot the per pseudonym, code summary list into columns per peso_id. */
DROP TABLE IF EXISTS rtp_tabular_data CASCADE;
CREATE TABLE rtp_tabular_data
AS
SELECT row_number() over()                          AS row_number
  ,       (record_id->>'pseudonym')::numeric        AS pseudonym
  ,       (record_id->>'age_in_years')::numeric     AS age_in_years
  ,       (record_id->>'gender')                    AS gender
-- classifier
  ,       (record_id->>'classifier')::boolean       AS classifier
-- smoking
  ,       CASE WHEN smoking->>'value_code' = '266919005' THEN 0 -- never
               WHEN smoking->>'value_code' = '8517006'   THEN 1 -- used to
               WHEN smoking->>'value_code' = '77176002'  THEN 2 -- yes
               ELSE                          NULL
          END                                             AS smok_lv                 -- last observed value of smoking observation
  ,       (smoking_quantity->>'days_to_t0')::numeric      AS smok_lv_days_to_t0        -- number of weeks before t0
  ,       (smoking_quantity->>'max_days_to_t0')::numeric  AS smok_max_days_to_t0       -- max number of weeks before t0
  ,       round((smoking_quantity->>'value_float')::numeric) AS smok_du_lv              -- smoking daily units last value
  ,       (smoking_quantity->>'count')::numeric           AS smok_du_count           -- number of smoking observations before t0
  ,       (smoking_quantity->>'avg')::numeric             AS smok_du_avg
  ,       (smoking_quantity->>'min')::numeric             AS smok_du_min
  ,       (smoking_quantity->>'max')::numeric             AS smok_du_max
  ,       (smoking_quantity->>'stddev_pop')::numeric      AS smok_du_std_pop        -- sample standard deviation
-- alcohol
  ,       alcohol->>'value_code'                          AS alcohol_lv
  ,       (alcohol->>'days_to_t0')::numeric               AS alcohol_lv_days_to_t0
  ,       (alcohol->>'max_days_to_t0')::numeric           AS alcohol_max_days_to_t0
  ,       round((alcohol_quantity->>'value_float')::numeric)    AS alc_wu_lv
  ,       (alcohol_quantity->>'count')::numeric           AS alc_wu_count
  ,       (alcohol_quantity->>'avg')::numeric             AS alc_wu_avg
  ,       (alcohol_quantity->>'min')::numeric             AS alc_wu_min
  ,       (alcohol_quantity->>'max')::numeric             AS alc_wu_max
  ,       (alcohol_quantity->>'stddev_pop')::numeric      AS alc_wu_std_pop
-- exercise days per week
  ,       CASE WHEN exercise->>'value_code' = 'A' THEN 0
               WHEN exercise->>'value_code' = 'B' THEN 2
               WHEN exercise->>'value_code' = 'C' THEN 4
               WHEN exercise->>'value_code' = 'D' THEN 5
               ELSE                          NULL
          END                                AS exercise_dpw_lv
  ,       (exercise->>'days_to_t0')::numeric AS exercise_dpw_lv_days_to_t0
  ,       (exercise->>'count')::numeric      AS exercise_count
-- hdl
  ,       (hdl->>'value_float')::numeric     AS hdl_lv
  ,       (hdl->>'days_to_t0')::numeric      AS hdl_lv_days_to_t0
  ,       (hdl->>'max_days_to_t0')::numeric  AS hdl_max_days_to_t0
  ,       (hdl->>'count')::numeric           AS hdl_count
  ,       (hdl->>'avg')::numeric             AS hdl_avg
  ,       (hdl->>'min')::numeric             AS hdl_min
  ,       (hdl->>'max')::numeric             AS hdl_max
  ,       (hdl->>'stddev_pop')::numeric      AS hdl_std_pop
-- total cholesterol / hdl cholesterol
  ,       (total_hdl->>'value_float')::numeric     AS total_hdl_lv
  ,       (total_hdl->>'days_to_t0')::numeric      AS total_hdl_lv_days_to_t0
  ,       (total_hdl->>'max_days_to_t0')::numeric  AS total_hdl_max_days_to_t0
  ,       (total_hdl->>'count')::numeric           AS total_hdl_count
  ,       (total_hdl->>'avg')::numeric             AS total_hdl_avg
  ,       (total_hdl->>'min')::numeric             AS total_hdl_min
  ,       (total_hdl->>'max')::numeric             AS total_hdl_max
  ,       (total_hdl->>'stddev_pop')::numeric      AS total_hdl_std_pop
-- systolic blood pressure
  ,       (systolic->>'value_float')::numeric     AS systolic_lv
  ,       (systolic->>'days_to_t0')::numeric      AS systolic_lv_days_to_t0
  ,       (systolic->>'max_days_to_t0')::numeric  AS systolic_max_days_to_t0
  ,       (systolic->>'count')::numeric           AS systolic_count
  ,       (systolic->>'avg')::numeric             AS systolic_avg
  ,       (systolic->>'min')::numeric             AS systolic_min
  ,       (systolic->>'max')::numeric             AS systolic_max
  ,       (systolic->>'stddev_pop')::numeric      AS systolic_std_pop
-- diastolic blood pressure
  ,       (diastolic->>'value_float')::numeric     AS diastolic_lv
  ,       (diastolic->>'days_to_t0')::numeric      AS diastolic_lv_days_to_t0
  ,       (diastolic->>'max_days_to_t0')::numeric  AS diastolic_max_days_to_t0
  ,       (diastolic->>'count')::numeric           AS diastolic_count
  ,       (diastolic->>'avg')::numeric             AS diastolic_avg
  ,       (diastolic->>'min')::numeric             AS diastolic_min
  ,       (diastolic->>'max')::numeric             AS diastolic_max
  ,       (diastolic->>'stddev_pop')::numeric      AS diastolic_std_pop
-- hba1c
  ,       (hba1c->>'value_float')::numeric     AS hba1c_lv
  ,       (hba1c->>'days_to_t0')::numeric      AS hba1c_lv_days_to_t0
  ,       (hba1c->>'max_days_to_t0')::numeric  AS hba1c_max_days_to_t0
  ,       (hba1c->>'count')::numeric           AS hba1c_count
  ,       (hba1c->>'avg')::numeric             AS hba1c_avg
  ,       (hba1c->>'min')::numeric             AS hba1c_min
  ,       (hba1c->>'max')::numeric             AS hba1c_max
  ,       (hba1c->>'stddev_pop')::numeric      AS hba1c_std_pop
-- albumine
  ,       (albumine->>'value_float')::numeric     AS albumine_lv
  ,       (albumine->>'days_to_t0')::numeric      AS albumine_lv_days_to_t0
  ,       (albumine->>'max_days_to_t0')::numeric  AS albumine_max_days_to_t0
  ,       (albumine->>'count')::numeric           AS albumine_count
  ,       (albumine->>'avg')::numeric             AS albumine_avg
  ,       (albumine->>'min')::numeric             AS albumine_min
  ,       (albumine->>'max')::numeric             AS albumine_max
  ,       (albumine->>'stddev_pop')::numeric      AS albumine_std_pop
-- kreatinine
  ,       (kreatinine->>'value_float')::numeric     AS kreatinine_lv
  ,       (kreatinine->>'days_to_t0')::numeric      AS kreatinine_lv_days_to_t0
  ,       (kreatinine->>'max_days_to_t0')::numeric  AS kreatinine_max_days_to_t0
  ,       (kreatinine->>'count')::numeric           AS kreatinine_count
  ,       (kreatinine->>'avg')::numeric             AS kreatinine_avg
  ,       (kreatinine->>'min')::numeric             AS kreatinine_min
  ,       (kreatinine->>'max')::numeric             AS kreatinine_max
  ,       (kreatinine->>'stddev_pop')::numeric      AS kreatinine_std_pop
-- cockroft
  ,       (cockroft->>'value_float')::numeric     AS cockroft_lv
  ,       (cockroft->>'days_to_t0')::numeric      AS cockroft_lv_days_to_t0
  ,       (cockroft->>'max_days_to_t0')::numeric  AS cockroft_max_days_to_t0
  ,       (cockroft->>'count')::numeric           AS cockroft_count
  ,       (cockroft->>'avg')::numeric             AS cockroft_avg
  ,       (cockroft->>'min')::numeric             AS cockroft_min
  ,       (cockroft->>'max')::numeric             AS cockroft_max
  ,       (cockroft->>'stddev_pop')::numeric      AS cockroft_std_pop
-- mdrd
  ,       (mdrd->>'value_float')::numeric     AS mdrd_lv
  ,       (mdrd->>'days_to_t0')::numeric      AS mdrd_lv_days_to_t0
  ,       (mdrd->>'max_days_to_t0')::numeric  AS mdrd_max_days_to_t0
  ,       (mdrd->>'count')::numeric           AS mdrd_count
  ,       (mdrd->>'avg')::numeric             AS mdrd_avg
  ,       (mdrd->>'min')::numeric             AS mdrd_min
  ,       (mdrd->>'max')::numeric             AS mdrd_max
  ,       (mdrd->>'stddev_pop')::numeric      AS mdrd_std_pop
FROM crosstab($ct$
    SELECT json_object(('{ pseudonym, '         || pseudonym       ||
                        ', age_in_years, '      || age_in_years    ||
                        ', gender, '            || gender          ||
                        ', classifier, '        || classifier      ||
                        '}')::text[])::text                           AS record_id
    ,       code                                                      AS category

    ,       json_object(('{value_code, '      || COALESCE(value_code::text, 'NULL')     ||
                         ',value_float, '     || COALESCE(value_float::text, 'NULL')    ||
                         ',count, '           || COALESCE(count_value::text, 'NULL')    ||
                         ',avg, '             || COALESCE(avg::text, 'NULL')            ||
                         ',min, '             || COALESCE(min::text, 'NULL')            ||
                         ',max, '             || COALESCE(max::text, 'NULL')            ||
                         ',stddev_pop, '      || COALESCE(stddev_pop::text, 'NULL')     ||
                         ',max_days_to_t0, '  || COALESCE(max_days_to_t0::text, 'NULL') ||
                         ',days_to_t0, '      || COALESCE(days_to_t0::text, 'NULL')     ||
                         '}')::text[])::text                          AS value
    FROM  rtp_base_summaries
    ORDER BY record_id, category
  $ct$,
  $ct$VALUES('365980008'::text) --smoking
     ,      ('266918002') -- smoking quant
     ,      ('219006') -- alcohol
     ,      ('160573003') -- alcohol quantity
     ,      ('228450008') -- exercise
     ,      ('102737005') -- hdl cholesterol
     ,      ('166842003') -- total/hdl cholesterol
     ,      ('103232008') -- HBA1c/GlycHb
     ,      ('250745003') -- albumine/kreatinine ratio
     ,      ('275792000') -- kreatinine
     ,      ('Portavita189') -- cockroft kreatinine derivate
     ,      ('Portavita304') -- MDRD kreatinine derivate
     ,      ('8480-6')
     ,      ('8462-4')
     $ct$
  )
  AS ct(record_id            jsonb
       ,"smoking"            jsonb
       ,"smoking_quantity"   jsonb
       ,"alcohol"            jsonb
       ,"alcohol_quantity"   jsonb
       ,"exercise"           jsonb
       ,"hdl"                jsonb
       ,"total_hdl"          jsonb
       ,"hba1c"              jsonb
       ,"albumine"           jsonb
       ,"kreatinine"         jsonb
       ,"cockroft"           jsonb
       ,"mdrd"               jsonb
       ,"systolic"           jsonb
       ,"diastolic"          jsonb
  ) -- select from crosstab
;

/*
 * Prosecutor risk
 */

/*
 * List equivalence classes, frequencies and prosecutor risk for the X most risky classes.
 */
WITH equivalence_classes AS
(
select age_in_years
,      gender
,      smok_lv
,      row_number() over (partition by age_in_years, gender, smok_lv) as rocky
,      count(1)     over (partition by age_in_years, gender, smok_lv) as count
from
rtp_tabular_data
)
SELECT age_in_years
,      gender
,      smok_lv
,      count AS "fk" -- frequency
, CASE WHEN count > 0 THEN 1::float/count ELSE NULL END as "1/fk" -- prosecutor risk
FROM equivalence_classes WHERE rocky = 1
order by count asc
limit 10;


/*
 * Calculate percentage of rows in the dataset at risk, given threshold of 0.05
 */
WITH equivalence_classes AS (
 select age_in_years
 , gender
 , smok_lv
 , row_number() over (partition by age_in_years, gender, smok_lv) as rocky
 , count(1)     over (partition by age_in_years, gender, smok_lv) as classsize
 from
 rtp_tabular_data
),
size AS (
 select count(*) AS denom
 from rtp_tabular_data
),
records_at_risk AS (
 select sum(classsize) as num
 from equivalence_classes
 where (CASE WHEN classsize > 0 THEN 1::float/classsize ELSE NULL END) > 0.05
 and rocky = 1
)
SELECT num
,      denom
,      ROUND(num::float / denom * 100) AS perc_records_at_risk_prosecutor
FROM size, records_at_risk;

