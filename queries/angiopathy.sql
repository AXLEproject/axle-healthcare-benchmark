/*
 * query      :
 * description: create angiopathy tabular data for Orange
 * user       : researchers, de-identification required

 * smoking y/n
 * bloodpressure
 * totaal / HDL cholesterol
 * gender
 * age
 *
 * '400047006' peripheral vascular disease -> classifier
 * (retinopathy
 *  renal failure
 *  foot complication)
 *
 * Copyright (c) 2014, Portavita B.V.
 */

DROP TABLE IF EXISTS public.angiopathy;

CREATE TABLE public.angiopathy as
WITH patient_properties_ct AS
(
  SELECT  row_number() over()                       AS row_number
  ,       CASE WHEN smoking->>'value' = '266919005' THEN 0 -- never
               WHEN smoking->>'value' = '8517006'   THEN 1 -- used to
               WHEN smoking->>'value' = '77176002'  THEN 2 -- yes
               ELSE                          NULL
          END                                       AS smoking
  ,       round((smoking_quantity->>'value')::numeric)        AS smoking_daily_units
  ,       alcohol->>'value'                                   AS alcohol
  ,       round((alcohol_quantity->>'value')::numeric / 7, 1) AS alcohol_daily_units
  ,       CASE WHEN exercise->>'value' = 'A' THEN 0
               WHEN exercise->>'value' = 'B' THEN 2
               WHEN exercise->>'value' = 'C' THEN 4
               WHEN exercise->>'value' = 'D' THEN 5
               ELSE                          NULL
          END                                       AS exercise_days_per_week
  ,       (hdl->>'value')::numeric                  AS hdl
  ,       (total_hdl->>'value')::numeric            AS total_hdl
  ,       (systolic->>'value')::numeric             AS systolic
  ,       (diastolic->>'value')::numeric            AS diastolic
  ,       peripheral_vascular_disease->>'time'      AS peripheral_vascular_disease
  FROM crosstab($ct$
    WITH obse AS
    (
      SELECT  ptnt.player                           AS peso_id
      ,       obse._code_code
      ,       extract(days from (current_timestamp - "birthTime"::timestamptz))  AS age_in_days
      ,       obse._value_code_code
      ,       obse._value_pq_value
      ,       obse._value_real
      ,       obse._value_int
      ,       obse._value_ivl_real
      ,       obse._effective_time_low
      ,       RANK() OVER (PARTITION BY ptnt.scoper, ptnt._id, obse._code_code
                           ORDER BY obse._effective_time_low DESC, obse._id DESC)     AS rocky
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      WHERE  NOT (obse."negationInd")
      AND
           (
             (obse._code_codesystem = '2.16.840.1.113883.6.96' AND
              ((obse._code_code IN ('365980008' -- smoking
                                   ,'266918002' -- smoking quantity
                                   ,'219006' -- alcohol
                                   ,'160573003' -- alcohol quantity
                                   ,'228450008' -- exercise
                                   ,'102737005' -- HDL cholestol
                                   ,'166842003' -- total/hdl cholesterol
                                   )
               ) OR
               ((obse._code_code IN (
                                    '400047006' -- peripheral vascular disease
                                    )) AND
                (obse._value_code_code = 'Y')
               )
              )
             )
             OR
             (obse._code_codesystem = '2.16.840.1.113883.6.1' AND
              ((obse._code_code IN ('8480-6' -- systolic
                                   , '8462-4' -- diastolic
                                   )
                                   )))
      ) /* End of WITH query */
)
    SELECT json_object(('{ peso_id, '     || peso_id                  ||
                        ', age_in_days, '     || age_in_days                ||
                        '}')::text[])::text                           AS record_id
    ,       obse._code_code                                           AS category
    ,       json_object(('{value, '  || COALESCE(obse._value_code_code, obse._value_pq_value::text, obse._value_real::text, obse._value_int::text, obse._value_ivl_real::text)  ||
                         ',time, '        || obse._effective_time_low ||
                         '}')::text[])::text                          AS value
    FROM  obse
    WHERE rocky = 1
    ORDER BY 1,2
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
) -- with patient_properties_ct
SELECT *
FROM   patient_properties_ct
;
