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
 * This script creates
 * - angiopathy_base_values, a materialized view with the base values in a time series list.
 *
 * - angiopathy_base_summaries, for each observation kinds, the following statistical summaries:
 *       count, avg, linear regression slope and y intercept, sample stddev and variance.
 *       for all observations before t0 (the date 20140501 for persons without PVD
 *                                       and the date of PVD for persons with PVD)
 *       and for all observations in the 6 months before t0.
 *       count = count for all observations, count2 is of 6 months before 60.
 *
 * - angiopathy_tabular_data, the base summaries pivoted.
 *       for each observation kind, is shown:
 *          the last observed value
 *          amount of weeks before t0 of this last known values
 *          the statistical aggregates of the two groups (all before t0 and six months before t0)
 *
 * Copyright (c) 2014, Portavita B.V.
 */

-- DROP MATERIALIZED VIEW angiopathy_base_values CASCADE;
CREATE MATERIALIZED VIEW angiopathy_base_values
AS
    WITH pvd AS
    (
      SELECT  ptnt.player                           AS peso_id
      ,       obse._effective_time_low              AS pvd_time
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      WHERE  NOT (obse."negationInd")
      AND    obse._code_codesystem = '2.16.840.1.113883.6.96'
      AND    obse._code_code = '400047006' -- peripheral vascular disease
      AND    obse._value_code_code = 'Y'
    )
   , base_values AS
    (
      SELECT  ptnt.player                           AS peso_id
      ,       obse._code_code                       AS code
      ,       extract(days from (current_timestamp - peso."birthTime"::timestamptz))  AS age_in_days
      ,       peso."administrativeGenderCode"->>'code' AS gender
      ,       obse._value_code_code                 AS value_code
      ,       obse._value_ivl_real                  AS value_ivl
      ,       COALESCE(obse._value_pq_value::float8, obse._value_real, obse._value_int)  AS value_float8
      ,       obse._effective_time_low              AS obs_time
      ,       pvd_time                              AS pvd_time
      ,       COALESCE(pvd_time, '20140501') AS t0
      ,      (COALESCE(pvd_time, '20140501')::ts - '6 mo'::pq_time)::timestamptz AS t6m
      ,      width_bucket(obse._effective_time_low,
                          ARRAY[ (COALESCE(pvd_time, '20140501')::ts - '6 mo'::pq_time)::timestamptz
                                , COALESCE(pvd_time, '20140501')]) as bucket
      ,      (EXTRACT(days FROM COALESCE(pvd_time, '20140501')
                                - obse._effective_time_low)/7)::int AS wk_to_t0
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      LEFT JOIN    pvd
      ON      peso_id = ptnt.player
      WHERE  NOT (obse."negationInd")
      -- we want only observations before t0
      AND    obse._effective_time_low <= COALESCE(pvd_time, '20140501')
      AND
           (
             (obse._code_codesystem = '2.16.840.1.113883.6.96' AND
              (obse._code_code IN ('365980008' -- smoking
                                   ,'266918002' -- smoking quantity
                                   ,'219006' -- alcohol
                                   ,'160573003' -- alcohol quantity
                                   ,'228450008' -- exercise
                                   ,'102737005' -- HDL cholestol
                                   ,'166842003' -- total/hdl cholesterol
                                   )
               )
             )
             OR
             (obse._code_codesystem = '2.16.840.1.113883.6.1' AND
              ((obse._code_code IN ('8480-6' -- systolic
                                   , '8462-4' -- diastolic
                                   )
                                   )))
           )
      ORDER BY peso_id, code
      )
SELECT * FROM base_values;

/*
 * Calculate statistics aggregates per person,observation code.
 *
 * Select the last value, the number of values and other aggregates.
 * See http://www.postgresql.org/docs/devel/static/functions-aggregate.html#FUNCTIONS-AGGREGATE-STATISTICS-TABLE
 * for a list.
 */
DROP VIEW angiopathy_base_summaries;
CREATE VIEW angiopathy_base_summaries
AS
SELECT * FROM (
      SELECT   peso_id, code, age_in_days, gender
      ,        obs_time, pvd_time, wk_to_t0
      ,        value_code
      ,        value_float8
      ,        RANK() OVER (PARTITION BY peso_id, code   ORDER BY obs_time DESC)           AS rocky

      ,        count(1)                                  OVER (PARTITION BY peso_id, code) AS count_value
      ,        avg( value_float8 )                       OVER (PARTITION BY peso_id, code) AS avg
      ,        regr_slope( value_float8,  wk_to_t0)      OVER (PARTITION BY peso_id, code) AS regr_slope
      ,        regr_intercept( value_float8, wk_to_t0)   OVER (PARTITION BY peso_id, code) AS regr_intercept
      ,        stddev_samp( value_float8 )               OVER (PARTITION BY peso_id, code) AS stddev_samp
      ,        var_samp( value_float8 )                  OVER (PARTITION BY peso_id, code) AS var_samp
      ,        string_agg( value_code, '|')              OVER (PARTITION BY peso_id, code) AS codes

      ,        count(1)                                FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS count_value2
      ,        avg( value_float8 )                     FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS avg2
      ,        regr_slope( value_float8,  wk_to_t0)    FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS regr_slope2
      ,        regr_intercept( value_float8, wk_to_t0) FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS regr_intercept2
      ,        stddev_samp( value_float8 )             FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS stddev_samp2
      ,        var_samp( value_float8 )                FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS var_samp2
      ,        string_agg( value_code, '|')            FILTER (WHERE bucket>=1) OVER (PARTITION BY peso_id, code) AS codes2

       FROM angiopathy_base_values
) a
WHERE rocky = 1;

/* Pivot the per person, code summary list into columns per peso_id. */

DROP VIEW angiopathy_tabular_data CASCADE;
CREATE VIEW angiopathy_tabular_data
AS
SELECT row_number() over()                          AS row_number
  ,       (record_id->>'peso_id')::numeric          AS peso_id
  ,       (record_id->>'age_in_days')::numeric      AS age_in_days
  ,       (record_id->>'gender')                    AS gender
-- classifier
  ,       (record_id->>'pvd_time') IS NULL          AS peripheral_vascular_disease
-- smoking
  ,       CASE WHEN smoking->>'value' = '266919005' THEN 0 -- never
               WHEN smoking->>'value' = '8517006'   THEN 1 -- used to
               WHEN smoking->>'value' = '77176002'  THEN 2 -- yes
               ELSE                          NULL
          END                                             AS smok_lv                 -- last observed value of smoking observation
  ,       (smoking_quantity->>'wk_to_t0')::numeric        AS smok_lv_wk_to_t0        -- number of weeks before t0
  ,       round((smoking_quantity->>'value')::numeric)    AS smok_du_lv              -- smoking daily units last value
  ,       (smoking_quantity->>'count')::numeric           AS smok_du_count           -- number of smoking observations before t0
  ,       (smoking_quantity->>'count2')::numeric          AS smok_du_count2          -- number of smoking observations in 6m before t0
  ,       (smoking_quantity->>'avg')::numeric             AS smok_du_avg
  ,       (smoking_quantity->>'avg2')::numeric            AS smok_du_avg2
  ,       (smoking_quantity->>'regr_slope')::numeric      AS smok_du_rgr_slope       -- linear regression slope
  ,       (smoking_quantity->>'regr_slope2')::numeric     AS smok_du_rgr_slope2
  ,       (smoking_quantity->>'regr_intercept')::numeric  AS smok_du_rgr_itcept      -- linear regression y intercept
  ,       (smoking_quantity->>'regr_intercept2')::numeric AS smok_du_rgr_itcept2
  ,       (smoking_quantity->>'stddev_samp')::numeric     AS smok_du_std_samp        -- sample standard deviation
  ,       (smoking_quantity->>'stddev_samp2')::numeric    AS smok_du_std_samp2
  ,       (smoking_quantity->>'var_samp')::numeric        AS smok_du_var_samp        -- sample variance
  ,       (smoking_quantity->>'var_samp2')::numeric       AS smok_du_var_samp2
-- alcohol
  ,       alcohol->>'value'                               AS alcohol_lv
  ,       (alcohol->>'wk_to_t0')::numeric                 AS alcohol_lv_wk_to_t0
  ,       round((alcohol_quantity->>'value')::numeric)    AS alc_wu_lv
  ,       (alcohol_quantity->>'count')::numeric           AS alc_wu_count
  ,       (alcohol_quantity->>'count2')::numeric          AS alc_wu_count2
  ,       (alcohol_quantity->>'avg')::numeric             AS alc_wu_avg
  ,       (alcohol_quantity->>'avg2')::numeric            AS alc_wu_avg2
  ,       (alcohol_quantity->>'regr_slope')::numeric      AS alc_wu_rgr_slope
  ,       (alcohol_quantity->>'regr_slope2')::numeric     AS alc_wu_rgr_slope2
  ,       (alcohol_quantity->>'regr_intercept')::numeric  AS alc_wu_rgr_itcept
  ,       (alcohol_quantity->>'regr_intercept2')::numeric AS alc_wu_rgr_itcept2
  ,       (alcohol_quantity->>'stddev_samp')::numeric     AS alc_wu_std_samp
  ,       (alcohol_quantity->>'stddev_samp2')::numeric    AS alc_wu_std_samp2
  ,       (alcohol_quantity->>'var_samp')::numeric        AS alc_wu_var_samp
  ,       (alcohol_quantity->>'var_samp2')::numeric       AS alc_wu_var_samp2
-- exercise days per week
  ,       CASE WHEN exercise->>'value' = 'A' THEN 0
               WHEN exercise->>'value' = 'B' THEN 2
               WHEN exercise->>'value' = 'C' THEN 4
               WHEN exercise->>'value' = 'D' THEN 5
               ELSE                          NULL
          END                                AS exercise_dpw_lv
  ,       (exercise->>'wk_to_t0')::numeric   AS exercise_dpw_lv_wk_to_t0
-- hdl
  ,       (hdl->>'value')::numeric           AS hdl_lv
  ,       (hdl->>'wk_to_t0')::numeric        AS hdl_lv_wk_to_t0
  ,       (hdl->>'count')::numeric           AS hdl_count
  ,       (hdl->>'count2')::numeric          AS hdl_count2
  ,       (hdl->>'avg')::numeric             AS hdl_avg
  ,       (hdl->>'avg2')::numeric            AS hdl_avg2
  ,       (hdl->>'regr_slope')::numeric      AS hdl_rgr_slope
  ,       (hdl->>'regr_slope2')::numeric     AS hdl_rgr_slope2
  ,       (hdl->>'regr_intercept')::numeric  AS hdl_rgr_itcept
  ,       (hdl->>'regr_intercept2')::numeric AS hdl_rgr_itcept2
  ,       (hdl->>'stddev_samp')::numeric     AS hdl_std_samp
  ,       (hdl->>'stddev_samp2')::numeric    AS hdl_std_samp2
  ,       (hdl->>'var_samp')::numeric        AS hdl_var_samp
  ,       (hdl->>'var_samp2')::numeric       AS hdl_var_samp2
-- total cholesterol / hdl cholesterol
  ,       (total_hdl->>'value')::numeric           AS total_hdl_lv
  ,       (total_hdl->>'wk_to_t0')::numeric        AS total_hdl_lv_wk_to_t0
  ,       (total_hdl->>'count')::numeric           AS total_hdl_count
  ,       (total_hdl->>'count2')::numeric          AS total_hdl_count2
  ,       (total_hdl->>'avg')::numeric             AS total_hdl_avg
  ,       (total_hdl->>'avg2')::numeric            AS total_hdl_avg2
  ,       (total_hdl->>'regr_slope')::numeric      AS total_hdl_rgr_slope
  ,       (total_hdl->>'regr_slope2')::numeric     AS total_hdl_rgr_slope2
  ,       (total_hdl->>'regr_intercept')::numeric  AS total_hdl_rgr_itcept
  ,       (total_hdl->>'regr_intercept2')::numeric AS total_hdl_rgr_itcept2
  ,       (total_hdl->>'stddev_samp')::numeric     AS total_hdl_std_samp
  ,       (total_hdl->>'stddev_samp2')::numeric    AS total_hdl_std_samp2
  ,       (total_hdl->>'var_samp')::numeric        AS total_hdl_var_samp
  ,       (total_hdl->>'var_samp2')::numeric       AS total_hdl_var_samp2
-- systolic blood pressure
  ,       (systolic->>'value')::numeric           AS systolic_lv
  ,       (systolic->>'wk_to_t0')::numeric        AS systolic_lv_wk_to_t0
  ,       (systolic->>'count')::numeric           AS systolic_count
  ,       (systolic->>'count2')::numeric          AS systolic_count2
  ,       (systolic->>'avg')::numeric             AS systolic_avg
  ,       (systolic->>'avg2')::numeric            AS systolic_avg2
  ,       (systolic->>'regr_slope')::numeric      AS systolic_rgr_slope
  ,       (systolic->>'regr_slope2')::numeric     AS systolic_rgr_slope2
  ,       (systolic->>'regr_intercept')::numeric  AS systolic_rgr_itcept
  ,       (systolic->>'regr_intercept2')::numeric AS systolic_rgr_itcept2
  ,       (systolic->>'stddev_samp')::numeric     AS systolic_std_samp
  ,       (systolic->>'stddev_samp2')::numeric    AS systolic_std_samp2
  ,       (systolic->>'var_samp')::numeric        AS systolic_var_samp
  ,       (systolic->>'var_samp2')::numeric       AS systolic_var_samp2
-- diastolic blood pressure
  ,       (diastolic->>'value')::numeric           AS diastolic_lv
  ,       (diastolic->>'wk_to_t0')::numeric        AS diastolic_lv_wk_to_t0
  ,       (diastolic->>'count')::numeric           AS diastolic_count
  ,       (diastolic->>'count2')::numeric          AS diastolic_count2
  ,       (diastolic->>'avg')::numeric             AS diastolic_avg
  ,       (diastolic->>'avg2')::numeric            AS diastolic_avg2
  ,       (diastolic->>'regr_slope')::numeric      AS diastolic_rgr_slope
  ,       (diastolic->>'regr_slope2')::numeric     AS diastolic_rgr_slope2
  ,       (diastolic->>'regr_intercept')::numeric  AS diastolic_rgr_itcept
  ,       (diastolic->>'regr_intercept2')::numeric AS diastolic_rgr_itcept2
  ,       (diastolic->>'stddev_samp')::numeric     AS diastolic_std_samp
  ,       (diastolic->>'stddev_samp2')::numeric    AS diastolic_std_samp2
  ,       (diastolic->>'var_samp')::numeric        AS diastolic_var_samp
  ,       (diastolic->>'var_samp2')::numeric       AS diastolic_var_samp2
FROM crosstab($ct$
    SELECT json_object(('{ peso_id, '          || peso_id        ||
                        ', age_in_days, '      || age_in_days    ||
                        ', gender, '           || gender         ||
                        ', pvd_time, '        || COALESCE(pvd_time::text, 'NULL') ||
                        '}')::text[])::text                           AS record_id
    ,       code                                                      AS category
    ,       json_object(('{value, '           ||  COALESCE(value_code, value_float8::text) ||

                         ',count, '           || COALESCE(count_value::text, 'NULL') ||
                         ',avg, '             || COALESCE(avg::text, 'NULL') ||
                         ',regr_slope, '      || COALESCE(regr_slope::text, 'NULL') ||
                         ',regr_intercept, '  || COALESCE(regr_intercept::text, 'NULL') ||
                         ',stddev_samp, '     || COALESCE(stddev_samp::text, 'NULL') ||
                         ',var_samp, '        || COALESCE(var_samp::text, 'NULL') ||
                         ',codes, '           || COALESCE(codes::text, 'NULL') ||

                         ',count2, '           || COALESCE(count_value2::text, 'NULL') ||
                         ',avg2, '             || COALESCE(avg2::text, 'NULL') ||
                         ',regr_slope2, '      || COALESCE(regr_slope2::text, 'NULL') ||
                         ',regr_intercept2, '  || COALESCE(regr_intercept2::text, 'NULL') ||
                         ',stddev_samp2, '     || COALESCE(stddev_samp2::text, 'NULL') ||
                         ',var_samp2, '        || COALESCE(var_samp2::text, 'NULL') ||
                         ',codes2, '           || COALESCE(codes2::text, 'NULL') ||

                         ',wk_to_t0, '        || COALESCE(wk_to_t0::text, 'NULL') ||
                         '}')::text[])::text                          AS value
    FROM  angiopathy_base_summaries
    ORDER BY record_id, category
  $ct$,
  $ct$VALUES('365980008'::text)
     ,      ('266918002')
     ,      ('219006')
     ,      ('160573003')
     ,      ('228450008')
     ,      ('102737005')
     ,      ('166842003')
     ,      ('400047006')
     ,      ('8480-6')
     ,      ('8462-4') $ct$
  )
  AS ct(record_id jsonb
       ,"smoking"      jsonb
       ,"smoking_quantity"       jsonb
       ,"alcohol" jsonb
       ,"alcohol_quantity"   jsonb
       ,"exercise"     jsonb
       ,"hdl" jsonb
       ,"total_hdl" jsonb
       ,"peripheral_vascular_disease"     jsonb
       ,"systolic" jsonb
       ,"diastolic" jsonb
  ) -- select from crosstab
;
