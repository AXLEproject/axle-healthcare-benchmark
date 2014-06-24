/*
 * query      : 2.1.2
 * description: process analysis per principal practitioner
 * user       : care group employees and quality employees
 *
 * Copyright (c) 2014, Portavita B.V.
 */
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
  AND    prf_ptcp.time                    ~ '20140501'::ts

  -- Get the patient
  JOIN    "Participation"                   sbj_ptcp
  ON       sbj_ptcp.act                   = pcpr._id
  AND      sbj_ptcp."typeCode"->>'code'   = 'RCT'
  JOIN    "Patient"                         ptnt
  ON       ptnt._id                       = sbj_ptcp.role

  WHERE  pcpr."classCode"->>'code'        = 'PCPR'
  AND    pcpr."moodCode"->>'code'         = 'EVN'
),
patientCountPerPrinPrac AS (
  SELECT   prin_prac_role_id
  ,        count(*)::numeric        AS total
  FROM     patientMetaData
  GROUP BY prin_prac_role_id
),
lastExamLastYear AS (
 SELECT   pmd.prin_prac_role_id     AS prin_prac_role_id
 ,        exam.code
 ,        exam.codesystem
 FROM     examinations              exam
 JOIN     patientMetaData           pmd
 ON       pmd.ptnt_id               = exam.ptnt_id
 WHERE    exam.rocky                = 1                            -- most recent
 AND      exam.effective_time_low  >= '20130501'
),
fundusLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                      = '170757007'
 AND      codesystem                = '2.16.840.1.113883.6.96'
 GROUP BY prin_prac_role_id
),
footCheckupLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                      = '401191002'
 AND      codesystem                = '2.16.840.1.113883.6.96'
 GROUP BY prin_prac_role_id
),
intermediaryCheckupLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                      = 'Portavita154'
 AND      codesystem                = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
riskInventoryLastYear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                      = 'Portavita140'
 AND      codesystem                = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
diabMedicationLastyear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     observation_history      obs
 JOIN     patientMetaData          pmd
 ON       pmd.ptnt_id              = obs.ptnt_id
 WHERE    obs.rocky                = 1
 AND      obs.effective_time_low  >= '20130501'
 AND      code                     = 'Portavita648'
 AND      codesystem               = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
stoppingSmokingLastyear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                      = 'Portavita571'
 AND      codesystem                = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY prin_prac_role_id
),
dietaryAdviceLastyear AS (
 SELECT   prin_prac_role_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                      = '183056000'
 AND      codesystem                = '2.16.840.1.113883.6.96'
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
