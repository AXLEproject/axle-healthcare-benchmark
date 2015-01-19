/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
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
 * and others
 *
 * Classifier is '400047006' peripheral vascular disease (PVD)
 * (retinopathy
 *  renal failure
 *  foot complication)
 *
 * This script creates the following views:
 *
 *  base_values                 a list of observations and basic patient data
 *
 *  retinopathy_class           class variables for retinopathy and related complications
 *  retinopathy_base_values     base_values specific for retinopathy:
 *                              - added class variable
 *                              - times related to t0, class date or fixed 20140501
 *                              - restricted features to retinopathy risks
 *                              - no observations after t0
 *  retinopathy_base_summaries  summarize time into last value, avg, min, max, count etc.
 *                              one record per patient and code
 *  retinopathy_tabular_data    select interesting summaries, pivot
 *                              one record per patient
 *
 * Copyright (c) 2014, Portavita B.V.
 */

\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS tablefunc;

\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, hdl, hl7, r1, "$user";

\set ON_ERROR_STOP off

/** create a one-time pseudonym **/
CREATE TEMP TABLE pseudonyms
AS
      SELECT  ptnt.player AS ptnt_player
      ,       crypt(ptnt.player::text, gen_salt('md5'))   AS pseudonym
      FROM    "Patient"                                ptnt
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
;

/** step one create base values **/
DROP TABLE base_values CASCADE;
CREATE TABLE base_values
AS
      /** person birth time **/
      SELECT  pseudonym                                          AS pseudonym
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
      SELECT  pseudonym                                          AS pseudonym
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
      SELECT  pseudonym                                          AS pseudonym
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

CREATE INDEX ON base_values (pseudonym, code);

/** add new feature class var.
    the class var is defined as the first observation in the group of
    micro-vascular complications **/

DELETE FROM base_values WHERE feature_id = 'has_retinopathy';
INSERT INTO base_values
      SELECT pseudonym                                          AS pseudonym
      ,      'has_retinopathy'::text                            AS feature_id
      ,      null::text                                         AS source_id
      ,      null::text                                         AS class_code
      ,      null::text                                         AS mood_code
      ,      null::text                                         AS status_code
      ,      'has_retinopathy'::text                            AS code
      ,      'FXP codesystem TBD'::text                         AS code_codesystem
      ,      'Retinopathy class variable'::text                 AS code_displayname
      ,      'Y'::text                                          AS value_code
      ,      'some codesystem with y/n'::text                   AS value_codesystem
      ,      'yes'::text                                        AS value_displayname
      ,      null::text                                         AS value_text
      ,      null::text                                         AS value_ivl_pq
      ,      null::numeric                                      AS value_real
      ,      null::boolean                                      AS value_bool
      ,      null::text                                         AS value_qset_ts
      ,      false::boolean                                     AS negation_ind
      ,      time_lowvalue                                      AS time_lowvalue
      ,      time_highvalue                                     AS time_highvalue
      ,      null::numeric                                      AS time_to_t0
      ,      time_availability                                  AS time_availability
FROM (
      SELECT  *
      ,       RANK() OVER (PARTITION BY pseudonym, code
                           ORDER BY time_lowvalue DESC) AS rocky
      FROM    base_values
      WHERE  (NOT negation_ind
              AND code_codesystem = '2.16.840.1.113883.6.96'
              AND code = '400047006'    -- peripheral vascular disease
              AND value_code = 'Y')
      OR
             (NOT negation_ind
              AND code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
              AND code = 'Portavita220' -- diabetic retinopathy
              AND value_code IN ('RETINOPATHIE_RECHTEROOG', 'RETINOPATHIE_LINKER_RECHTEROOG', 'RETINOPATHIE_LINKEROOG'))
      ) a
      WHERE rocky = 1;


DELETE FROM base_values WHERE feature_id = 'age_in_years';
INSERT INTO base_values
      SELECT pseudonym                                          AS pseudonym
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
              - extract(year from time_lowvalue))::numeric      AS value_real
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
      AND     NOT negation_ind
;

-- observation lists with class for retinopathy
DROP VIEW retinopathy_base_values CASCADE;
CREATE VIEW retinopathy_base_values
AS
WITH base_values_with_class AS (
        SELECT    v.*
        ,         COALESCE(c.time_lowvalue, '20140501') AS t0
        ,         c.time_lowvalue IS NOT NULL           AS class
        FROM      base_values v
        LEFT JOIN base_values c
        ON        c.pseudonym = v.pseudonym
        AND       c.code = 'has_retinopathy'
        AND       c.value_code = 'Y'
)
SELECT  pseudonym
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
        ,      value_real
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
ORDER BY pseudonym, code, t0 desc;

/*
 * Calculate statistics aggregates per person,observation code.
 *
 * Select the last value, the number of values and other aggregates.
 * See http://www.postgresql.org/docs/devel/static/functions-aggregate.html#FUNCTIONS-AGGREGATE-STATISTICS-TABLE
 * for a list.
 *
 */
DROP VIEW retinopathy_base_summaries CASCADE;
CREATE VIEW retinopathy_base_summaries
AS
SELECT * FROM (
      SELECT   *
      ,        RANK() OVER (PARTITION BY pseudonym, code  ORDER BY time_to_t0 ASC)  AS rocky
      ,        count(1)                  OVER (PARTITION BY pseudonym, code)  AS count_value
      ,        avg(value_real)           OVER (PARTITION BY pseudonym, code)  AS avg
      ,        min(value_real)           OVER (PARTITION BY pseudonym, code)  AS min
      ,        max(value_real)           OVER (PARTITION BY pseudonym, code)  AS max
      ,        max(time_to_t0)           OVER (PARTITION BY pseudonym, code)  AS max_time_to_t0
      ,        stddev_pop(value_real)    OVER (PARTITION BY pseudonym, code)  AS stddev_pop
      ,        string_agg( value_code, '|')    OVER (PARTITION BY pseudonym, code)  AS codes
       FROM retinopathy_base_values
) a
WHERE rocky = 1;

/* Pivot the per pseudonym, code summary list into columns per peso_id. */
DROP TABLE IF EXISTS retinopathy_tabular_data CASCADE;
CREATE TABLE retinopathy_tabular_data
AS
SELECT row_number() over()                          AS row_number
  ,       (record_id->>'pseudonym')                 AS pseudonym
  ,       (age_in_years->>'value_real')::numeric    AS age_in_years
  ,       gender->>'value_code'                     AS gender
-- class
  ,       has_retinopathy->>'value_code'            AS class
-- smoking
  ,       CASE WHEN smoking->>'value_code' = '266919005' THEN 0 -- never
               WHEN smoking->>'value_code' = '8517006'   THEN 1 -- used to
               WHEN smoking->>'value_code' = '77176002'  THEN 2 -- yes
               ELSE                          NULL
          END                                               AS smok_lv       -- last observed value of smoking observation
  ,       round((smoking_quantity->>'value_real')::numeric) AS smok_du_lv    -- smoking daily units last value
  ,       (smoking_quantity->>'count')::numeric             AS smok_du_count -- number of smoking observations before t0
-- alcohol
  ,       alcohol->>'value_code'                            AS alcohol_lv
  ,       round((alcohol_quantity->>'value_real')::numeric) AS alc_wu_lv
-- exercise days per week
  ,       CASE WHEN exercise->>'value_code' = 'A' THEN 0
               WHEN exercise->>'value_code' = 'B' THEN 2
               WHEN exercise->>'value_code' = 'C' THEN 4
               WHEN exercise->>'value_code' = 'D' THEN 5
               ELSE                          NULL
          END                                             AS exercise_dpw_lv
-- hdl
  ,       (hdl->>'value_real')::numeric                   AS hdl_lv
-- total cholesterol / hdl cholesterol
  ,       (total_hdl->>'value_real')::numeric             AS total_hdl_lv
-- systolic blood pressure
  ,       (systolic->>'value_real')::numeric              AS systolic_lv
-- diastolic blood pressure
  ,       (diastolic->>'value_real')::numeric             AS diastolic_lv
-- hba1c
  ,       (hba1c->>'value_real')::numeric                 AS hba1c_lv
-- albumine
  ,       (albumine->>'value_real')::numeric              AS albumine_lv
-- kreatinine
  ,       (kreatinine->>'value_real')::numeric            AS kreatinine_lv
-- cockroft
  ,       (cockroft->>'value_real')::numeric              AS cockroft_lv
-- mdrd
  ,       (mdrd->>'value_real')::numeric                  AS mdrd_lv
FROM crosstab($ct$
    SELECT json_object(('{ pseudonym, '         || pseudonym  ||
                        '}')::text[])::text                           AS record_id
    ,       code                                                      AS category

    ,       json_object(('{value_code, '      || COALESCE(value_code::text, 'NULL')     ||
                         ',value_real, '      || COALESCE(value_real::text, 'NULL')    ||
                         ',count, '           || COALESCE(count_value::text, 'NULL')    ||
                         ',avg, '             || COALESCE(avg::text, 'NULL')            ||
                         ',min, '             || COALESCE(min::text, 'NULL')            ||
                         ',max, '             || COALESCE(max::text, 'NULL')            ||
                         ',stddev_pop, '      || COALESCE(stddev_pop::text, 'NULL')     ||
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
       ,"has_retinopathy"    jsonb
       ,"age_in_years"       jsonb
       ,"gender"             jsonb
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
retinopathy_tabular_data
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
 retinopathy_tabular_data
),
size AS (
 select count(*) AS denom
 from retinopathy_tabular_data
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

