WITH patientMetaData AS (
  SELECT pcpr._id                        AS pcpr_act_id
  ,      ptnt._id                        AS ptnt_id
  ,      ptnt.scoper                     AS orga_enti_id
  ,      ptnt.player                     AS peso_id
  ,      prf_ptcp.role                   AS prin_prac_role_id
  FROM   ONLY "Act"                         pcpr

  -- Get the principal practitioner
  JOIN   "Participation"                    prf_ptcp
  ON     prf_ptcp.act                     = pcpr._id
  AND    prf_ptcp."typeCode"->>'code'     = 'PRF'
  AND    prf_ptcp.time                    ~ now()::ts

  -- Get the patient
  JOIN    "Participation"                  sbj_ptcp
  ON       sbj_ptcp.act                   = pcpr._id
  AND      sbj_ptcp."typeCode"->>'code'   = 'RCT'
  JOIN    "Patient"                         ptnt
  ON       ptnt._id                       = sbj_ptcp.role

  WHERE  pcpr."classCode"->>'code'        = 'PCPR'
  AND    pcpr."moodCode"->>'code'         = 'EVN' -- there are also 'INT' pcpr moodcodes for treatment plans.
),
patientCountPerPrinPrac AS (
  SELECT   prin_prac_role_id
  ,        count(*)::numeric    AS total
  FROM     patientMetaData
  GROUP BY prin_prac_role_id
),
lastExamLastYear AS (
 SELECT   pmd.prin_prac_role_id   AS prin_prac_role_id
 ,        exam.code
 FROM     examinations                exam
 JOIN     patientMetaData             pmd
 ON       pmd.ptnt_id               = exam.ptnt_id
 WHERE    exam.rocky                = 1                            -- most recent
 AND      exam._effective_time_low >= (now()- '1 year'::interval) -- of last year
),
fundusLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = '170757007'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.6.96'
 GROUP BY prin_prac_role_id
),
footCheckupLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = '401191002'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.6.96'
 GROUP BY prin_prac_role_id
),
intermediaryCheckupLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = 'Portavita154'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
riskInventoryLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = 'Portavita140'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
diabMedicationLastyear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = 'Portavita648'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
stoppingSmokingLastyear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = 'Portavita571'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
dietaryAdviceLastyear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code->>'code'            = '183056000'
 AND      code->>'codeSystem'      = '2.16.840.1.113883.6.96'
 GROUP BY prin_prac_role_id
)
SELECT    pcpo.prin_prac_role_id                                AS prinPractitioner
,         pcpo.total                                            AS nrOfPatients
,         TRUNC((COALESCE(f.c, 0) / total) * 100::numeric, 2)   AS fundusOfTotal
,         TRUNC((COALESCE(fc.c, 0) / total) * 100::numeric, 2)  AS footCheckupOfTotal
,         TRUNC((COALESCE(ic.c, 0) / total) * 100::numeric, 2)  AS intermediaryCheckupOfTotal
,         TRUNC((COALESCE(ri.c, 0) / total) * 100::numeric, 2)  AS riskInventoryOfTotal
,         TRUNC((COALESCE(ic.c, 0) / total) * 100::numeric, 2)  AS intermediaryCheckupOfTotal
,         TRUNC((COALESCE(dm.c, 0) / total) * 100::numeric, 2)  AS diabMedicationOfTotal
,         TRUNC((COALESCE(ss.c, 0) / total) * 100::numeric, 2)  AS stoppingSmokingLastyear
,         TRUNC((COALESCE(da.c, 0) / total) * 100::numeric, 2)  AS dietaryAdviceLastyear
FROM      patientCountPerPrinPrac pcpo
LEFT JOIN fundusLastYear              f  ON   f.prin_prac_role_id           = pcpo.prin_prac_role_id
LEFT JOIN footCheckupLastYear         fc ON   fc.prin_prac_role_id          = pcpo.prin_prac_role_id
LEFT JOIN intermediaryCheckupLastYear ic ON   ic.prin_prac_role_id          = pcpo.prin_prac_role_id
LEFT JOIN riskInventoryLastYear       ri ON   ri.prin_prac_role_id          = pcpo.prin_prac_role_id
LEFT JOIN diabMedicationLastyear      dm ON   dm.prin_prac_role_id          = pcpo.prin_prac_role_id
LEFT JOIN stoppingSmokingLastyear     ss ON   ss.prin_prac_role_id          = pcpo.prin_prac_role_id
LEFT JOIN dietaryAdviceLastyear       da ON   da.prin_prac_role_id          = pcpo.prin_prac_role_id
;
