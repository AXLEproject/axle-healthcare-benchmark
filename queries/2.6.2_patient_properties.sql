/* Select all patients for which at least one of the following examinatios
 * exists in a specified period of time.
*/
\timing
WITH patient_properties_ct AS
(
  SELECT  (record_id->>'orga_enti_id')::bigint      AS orga_enti_id
  ,       (record_id->>'ptnt_id')::bigint           AS ptnt_id
  ,       (record_id->>'peso_id')::bigint           AS peso_id
  ,       "Etnicity (diabetes)"->>'value_code'      AS "Etnicity (diabetes)"
  ,       "Diabetes in family"->>'value_code'       AS "Diabetes in family"
  ,       "Lipid disorder in family"->>'value_code' AS "Lipid disorder in family"
  ,       "Hypertension in family"->>'value_code'   AS "Hypertension in family"
  ,       "Angiopathy in family"->>'value_code'     AS "Angiopathy in family"
  ,       "Diagnosis (diabetes)"->>'value_code'     AS "Diagnosis (diabetes)"
  ,       "Diagnosis (diabetes)"->>'time'           AS "Diagnosis date"
  FROM crosstab($ct$
    WITH obse AS
    (
      SELECT  ptnt.scoper                           AS orga_enti_id
      ,       ptnt._id                              AS ptnt_id
      ,       ptnt.player                           AS peso_id
      ,       obse._code_code
      ,       obse._value_code_code
      ,       obse._effective_time_low
      ,       RANK() OVER (PARTITION BY ptnt.scoper, ptnt._id, obse._code_code
                           ORDER BY obse._effective_time_low DESC, obse._id DESC)     AS rocky
      FROM    "Patient"                                ptnt
      JOIN    "Participation"                          obse_ptcp
      ON      ptnt._id                                 = obse_ptcp.role
      JOIN    "Observation"                            obse
      ON      obse._id                                 = obse_ptcp.act
      WHERE  (obse._code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1' AND
              obse._code_code IN ('Portavita631' -- ethnicity
                                 ,'Portavita68' -- diabetes in family
                                 ,'Portavita69' -- lipid disorders in family
                                 ,'Portavita70' -- hypertension in family
                                 ,'Portavita71' -- angiopathy in family
                                 ,'Portavita1232' -- diagnosis diabetes
                                 )
             )
           AND
           EXISTS (
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
    ,       json_object(('{value_code, '  || obse._value_code_code    ||
                         ',time, '        || obse._effective_time_low ||
                         '}')::text[])::text                          AS value
    FROM  obse
    WHERE rocky = 1
    ORDER BY 1,2
  $ct$,
  $ct$VALUES('Portavita631'::text)
      ,     ('Portavita68')
      ,     ('Portavita69')
      ,     ('Portavita70')
      ,     ('Portavita71')
      ,     ('Portavita1232')$ct$
  )
  AS ct(record_id jsonb
       ,"Etnicity (diabetes)"      jsonb
       ,"Diabetes in family"       jsonb
       ,"Lipid disorder in family" jsonb
       ,"Hypertension in family"   jsonb
       ,"Angiopathy in family"     jsonb
       ,"Diagnosis (diabetes)"     jsonb
  ) -- select from crosstab
) -- with patient_properties_ct
SELECT *
FROM   patient_properties_ct
;
\quit

,      peso."birthTime"                         AS birthtime
,      peso."administrativeGenderCode"->>'code' AS administrative_gender
FROM   patient_properties_ct
JOIN  "Person"                                  peso
ON     peso._id                                 = patient_properties_ct.peso_id
;
