WITH care_provisions AS (
  SELECT * FROM ONLY "Act" WHERE "classCode" = 'PCPR:2.16.840.1.113883.5.6'
),
patientMetaData AS (
  SELECT pcpr._id              AS pcpr_act_id
  ,      ptnt._id              AS ptnt_id
  ,      ptnt.scoper           AS orga_enti_id
  ,      ptnt.player           AS peso_id
  FROM   care_provisions        pcpr
  JOIN  "Participation"         sbj_ptcp
  ON     sbj_ptcp.act           = pcpr._id
  AND    sbj_ptcp."typeCode"    = 'RCT:2.16.840.1.113883.5.90' -- PRF, AUT as well.
  JOIN  "Patient" ptnt
  ON     ptnt._id =             sbj_ptcp.role
  WHERE  pcpr."statusCode"      = 'active:2.16.840.1.113883.5.14'
  AND    pcpr."moodCode"        = 'EVN:2.16.840.1.113883.5.1001'  -- note there are also 'INT' pcpr moodcodes.
),
patientCountPerOrga AS (
 SELECT orga_enti_id, count(*) AS total
 FROM   patientMetaData
 GROUP BY orga_enti_id
)
SELECT * FROM patientCountPerOrga
;
