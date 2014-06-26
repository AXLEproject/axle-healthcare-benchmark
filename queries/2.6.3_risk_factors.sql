/*
 * query      : 2.6.3
 * description: chronic disease risk factors
 * user       : researchers, de-identification required
 *
 * Copyright (c) 2014, Portavita B.V.
 */

WITH patient_properties_ct AS
(
  SELECT  (record_id->>'orga_enti_id')::bigint                AS orga_enti_id
  ,       (record_id->>'ptnt_id')::bigint                     AS ptnt_id
  ,       (record_id->>'peso_id')::bigint                     AS peso_id
  ,       smoking->>'value'                                   AS smoking
  ,       round((smoking_quantity->>'value')::numeric)        AS smoking_daily_units
  ,       alcohol->>'value'                                   AS alcohol
  ,       round((alcohol_quantity->>'value')::numeric / 7, 1) AS alcohol_daily_units
  ,       CASE WHEN exercise->>'value' = 'A' THEN 0
               WHEN exercise->>'value' = 'B' THEN 2
               WHEN exercise->>'value' = 'C' THEN 4
               WHEN exercise->>'value' = 'D' THEN 5
               ELSE                          NULL
          END                                       AS exercise_days_per_week
  ,       heartattack->>'time'                      AS heartattack
  ,       angina_pectoris->>'time'                  AS angina_pectoris
  ,       stroke->>'time'                           AS stroke
  ,       tia->>'time'                              AS tia
  ,       peripheral_vascular_disease->>'time'      AS peripheral_vascular_disease
  FROM crosstab($ct$
    WITH obse AS
    (
      SELECT  ptnt.scoper                           AS orga_enti_id
      ,       ptnt._id                              AS ptnt_id
      ,       ptnt.player                           AS peso_id
      ,       obse._code_code
      ,       obse._value_code_code
      ,       obse._value_pq_value
      ,       obse._effective_time_low
      ,       RANK() OVER (PARTITION BY ptnt.scoper, ptnt._id, obse._code_code
                           ORDER BY obse._effective_time_low DESC, obse._id DESC)     AS rocky
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      WHERE  NOT (obse."negationInd")
      AND
             (obse._code_codesystem = '2.16.840.1.113883.6.96' AND
              ((obse._code_code IN ('365980008' -- smoking
                                   ,'266918002' -- smoking quantity
                                   ,'219006' -- alcohol
                                   ,'160573003' -- alcohol quantity
                                   ,'228450008' -- exercise
                                   )
               ) OR
               ((obse._code_code IN ('22298006' -- heart attack
                                    ,'367416001' -- angina pectoris
                                    ,'230690007' -- stroke
                                    ,'266257000' -- tia
                                    ,'400047006' -- peripheral vascular disease
                                    )) AND
                (obse._value_code_code = 'Y')
               )
              )
             )
      AND EXISTS (
             SELECT * FROM   ONLY "Act"             exam
             JOIN   "Participation"                 exam_ptcp
             ON     exam_ptcp.act                   = exam._id
             WHERE  exam_ptcp.role                  = ptnt._id
             AND    exam_ptcp."typeCode"->>'code'   = 'RCT'
             AND   '[{"root": "2.16.840.1.113883.2.4.3.31.4.2.1", "dataType": "II", "extension": "1"}]' @> exam."templateId"
             AND    exam._effective_time_low_year BETWEEN 2013 AND 2014
             AND    exam._effective_time_low >= '20130501'
             AND   (
                    (exam._code_codesystem = '2.16.840.1.113883.6.96' AND
                     exam._code_code IN ('170777000' -- annual checkup, snomed
                                        ,'170744004' -- quarterly checkup, snomed
                                        ,'401191002' -- foot checkup, snomed
                                        ,'183056000' -- dietary advice, snomed
                                        ,'170757007' -- fundus photo checkup, snomed
                                        )
                    ) OR
                    (exam._code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1' AND
                     exam._code_code IN ('Portavita140' -- risk inventory
                                        ,'Portavita154' -- interim checkup
                                        ,'Portavita136' -- self checkup
                                        ,'Portavita224' -- ophtalmologic checkup
                                        )
                    )
                   )
           )
    )
    SELECT json_object(('{orga_enti_id, ' || orga_enti_id             ||
                        ', ptnt_id, '     || ptnt_id                  ||
                        ', peso_id, '     || peso_id                  ||
                        '}')::text[])::text                           AS record_id
    ,       obse._code_code                                           AS category
    ,       json_object(('{value, '  || COALESCE(obse._value_code_code, obse._value_pq_value::text)  ||
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
     ,      ('22298006')
     ,      ('367416001')
     ,      ('230690007')
     ,      ('266257000')
     ,      ('400047006')$ct$
  )
  AS ct(record_id jsonb
       ,"smoking"      jsonb
       ,"smoking_quantity"       jsonb
       ,"alcohol" jsonb
       ,"alcohol_quantity"   jsonb
       ,"exercise"     jsonb
       ,"heartattack"     jsonb
       ,"angina_pectoris"     jsonb
       ,"stroke"     jsonb
       ,"tia"     jsonb
       ,"peripheral_vascular_disease"     jsonb
  ) -- select from crosstab
) -- with patient_properties_ct
SELECT *
FROM   patient_properties_ct
;
