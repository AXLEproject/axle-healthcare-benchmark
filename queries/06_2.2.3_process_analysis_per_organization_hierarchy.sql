/*
 * query      : 2.2.3
 * description: process analysis per organization hierarchy
 * user       : care group employees and quality employees
 *
 * Copyright (c) 2014, Portavita B.V.
 */
WITH RECURSIVE organizationHierarchy AS (
  SELECT _id                            AS child_orga
  ,      _id                            AS ancestor_orga
  FROM   "Organization"
  UNION
  SELECT player::bigint AS child_orga
  ,      ancestor_orga
  FROM "Role"
  JOIN organizationHierarchy
  ON   scoper = child_orga
  WHERE "classCode"->>'code' = 'PART'
),
care_provisions AS (
  SELECT * FROM ONLY "Act" WHERE "classCode"->>'code' = 'PCPR'
),
patientMetaData AS (
  SELECT   pcpr._id                     AS pcpr_act_id
  ,        ptnt._id                     AS ptnt_id
  ,        ptnt.player                  AS peso_id
  ,        orga_hier.ancestor_orga      AS orga_enti_id
  FROM     care_provisions              pcpr
  JOIN    "Participation"               sbj_ptcp
  ON       sbj_ptcp.act                 = pcpr._id
  AND      sbj_ptcp."typeCode"->>'code' = 'RCT'
  JOIN    "Patient"                     ptnt
  ON       ptnt._id                     = sbj_ptcp.role
  JOIN     organizationHierarchy        orga_hier
  ON       child_orga                   = ptnt.scoper
  WHERE    pcpr."statusCode"->>'code'   = 'active'
  AND      pcpr."moodCode"->>'code'     = 'EVN'  -- there are also 'INT' pcpr moodcodes.
  AND      ptnt.scoper                  IS NOT NULL
),
patientCountPerOrga AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric AS total
 FROM     patientMetaData
 GROUP BY orga_enti_id
),
lastExamLastYear AS (
 SELECT   pmd.orga_enti_id
 ,        exam.code
 ,        exam.codesystem
 FROM     examinations             exam
 JOIN     patientMetaData          pmd
 ON       pmd.ptnt_id              = exam.ptnt_id
 WHERE    exam.rocky               = 1                            -- most recent
 AND      exam.effective_time_low  >= '20130501'
),
fundusLastYear AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                     = '170757007'
 AND      codesystem               = '2.16.840.1.113883.6.96'
 GROUP BY orga_enti_id
),
footCheckupLastYear AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                     = '401191002'
 AND      codesystem               = '2.16.840.1.113883.6.96'
 GROUP BY orga_enti_id
),
intermediaryCheckupLastYear AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                     = 'Portavita154'
 AND      codesystem               = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY orga_enti_id
),
riskInventoryLastYear AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                     = 'Portavita140'
 AND      codesystem               = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY orga_enti_id
),
diabMedicationLastyear AS (
 SELECT   pmd.orga_enti_id
 ,        count(*)::numeric c
 FROM     observation_history      obs
 JOIN     patientMetaData          pmd
 ON       pmd.ptnt_id              = obs.ptnt_id
 WHERE    obs.rocky                = 1
 AND      obs.effective_time_low  >= '20130501'
 AND      code                     = 'Portavita648'
 AND      codesystem               = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY orga_enti_id
),
stoppingSmokingLastyear AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                     = 'Portavita571'
 AND      codesystem               = '2.16.840.1.113883.2.4.3.31.2.1'
 GROUP BY orga_enti_id
),
dietaryAdviceLastyear AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric c
 FROM     lastExamLastYear
 WHERE    code                     = '183056000'
 AND      codesystem               = '2.16.840.1.113883.6.96'
 GROUP BY orga_enti_id
)
SELECT    pcpo.orga_enti_id                            AS orgaEntiId
,         pcpo.total                                   AS nrOfPatients
,         TRUNC((COALESCE(f.c, 0) / total) * 100::numeric, 2)   AS fundusOfTotal
,         TRUNC((COALESCE(fc.c, 0) / total) * 100::numeric, 2)  AS footCheckupOfTotal
,         TRUNC((COALESCE(ic.c, 0) / total) * 100::numeric, 2)  AS intermediaryCheckupOfTotal
,         TRUNC((COALESCE(ri.c, 0) / total) * 100::numeric, 2)  AS riskInventoryOfTotal
,         TRUNC((COALESCE(ic.c, 0) / total) * 100::numeric, 2)  AS intermediaryCheckupOfTotal
,         TRUNC((COALESCE(dm.c, 0) / total) * 100::numeric, 2)  AS diabMedicationOfTotal
,         TRUNC((COALESCE(ss.c, 0) / total) * 100::numeric, 2)  AS stoppingSmokingLastyear
,         TRUNC((COALESCE(da.c, 0) / total) * 100::numeric, 2)  AS dietaryAdviceLastyear
FROM      patientCountPerOrga pcpo
LEFT JOIN fundusLastYear              f  ON   f.orga_enti_id           = pcpo.orga_enti_id
LEFT JOIN footCheckupLastYear         fc ON   fc.orga_enti_id          = pcpo.orga_enti_id
LEFT JOIN intermediaryCheckupLastYear ic ON   ic.orga_enti_id          = pcpo.orga_enti_id
LEFT JOIN riskInventoryLastYear       ri ON   ri.orga_enti_id          = pcpo.orga_enti_id
LEFT JOIN diabMedicationLastyear      dm ON   dm.orga_enti_id          = pcpo.orga_enti_id
LEFT JOIN stoppingSmokingLastyear     ss ON   ss.orga_enti_id          = pcpo.orga_enti_id
LEFT JOIN dietaryAdviceLastyear       da ON   da.orga_enti_id          = pcpo.orga_enti_id
;
