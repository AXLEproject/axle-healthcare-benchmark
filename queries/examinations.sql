/*
 * Examinations are defined as the direct childs of DOCSECTS.
 */
CREATE OR REPLACE VIEW examinations AS
WITH ActOrObs AS (
  SELECT    _id, "classCode", code, _effective_time_low
  FROM ONLY "Act"
  WHERE     "classCode"    =   'CLUSTER:2.16.840.1.113883.5.6'
  UNION ALL
  SELECT    _id, "classCode", code, _effective_time_low
  FROM      "Observation"
)
SELECT
            ptnt.player           AS peso_id
,           ptnt._id              AS ptnt_id
,           exam._id
,           exam.code
,           exam."classCode"
,           exam._effective_time_low
,           RANK() OVER (PARTITION BY ptnt.player, exam.code->>'code'
                         ORDER BY exam._effective_time_low DESC, exam._id DESC) AS rocky
FROM        ActOrObs                exam
JOIN        "Participation"         rct_ptcp
ON          rct_ptcp.act        =   exam._id
AND         rct_ptcp."typeCode" =   'RCT:2.16.840.1.113883.5.90' -- PRF, AUT as well.
JOIN        "Patient"               ptnt
ON          ptnt._id            =   rct_ptcp.role
JOIN        "ActRelationship"       parent
ON          exam._id            =   parent.target
JOIN ONLY   "Act"                   section
ON          section._id         =   parent.source
AND         section."classCode" =   'DOCSECT:2.16.840.1.113883.5.6'
;
