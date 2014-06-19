/* Requires crosstab, jsonb */

WITH
extreme_ct AS
(
 SELECT  (rowid->>'orga_enti_id')::bigint AS orga_enti_id
 ,       (rowid->>'ptnt_id')::bigint      AS ptnt_id
 ,       (rowid->>'peso_id')::bigint      AS peso_id
 ,       "Extreme HBA1c/GlycHb"
 ,       "Extreme Triglyceride"
 ,       "Extreme Systolic blood pressure"
 FROM crosstab($ct$
 WITH facets AS
(
  SELECT ptnt._id                         AS ptnt_id
  ,      ptnt.scoper                      AS orga_enti_id
  ,      ptnt.player                      AS peso_id
  ,      facets._code_code
  ,      facets.code->>'displayName'      AS displayname
  ,      facets._effective_time_low
  ,      _value_pq
  ,      RANK() OVER (PARTITION BY ptnt.scoper, ptnt._id, facets._code_code
                      ORDER BY facets._effective_time_low DESC, facets._id DESC)     AS rocky
  ,      AVG(_value_pq) OVER (PARTITION BY ptnt.scoper, ptnt._id, facets._code_code) AS avg_value_pq
  FROM  "Observation"                    facets
  JOIN  "Participation"                  facets_ptcp
  ON     facets_ptcp.act                     = facets._id
  AND    facets_ptcp."typeCode"->>'code'     = 'RCT'
  JOIN   "Patient"                       ptnt
  ON     ptnt._id                        = facets_ptcp.role
  WHERE  facets._effective_time_low_year BETWEEN 2013 AND 2014
  AND    facets._effective_time_low >= '20130501'
  AND   ((_code_code = '103232008' AND _code_codesystem = '2.16.840.1.113883.6.96') -- hba1c, snomed
         OR
         (_code_code = '85600001'  AND _code_codesystem = '2.16.840.1.113883.6.96') -- triglyceride, snomed
         OR
         (_code_code = '8480-6'    AND _code_codesystem = '2.16.840.1.113883.6.1')  -- systolic bp, loinc
         )
),
selectExtremes AS (
  SELECT orga_enti_id
  ,      ptnt_id
  ,      peso_id
  ,      _code_code
  ,      _value_pq
  ,      avg_value_pq
  FROM facets
  WHERE CASE WHEN _code_code = '103232008'
           THEN rocky = 1 AND _value_pq NOT BETWEEN '53 mmol/mol' AND '69 mmol/mol'
      WHEN _code_code = '85600001'
           THEN rocky = 1 AND _value_pq > '2.0 mmol/l'
      WHEN _code_code = '8480-6'
           THEN rocky = 1 AND avg_value_pq NOT BETWEEN '140 mm[Hg]' AND '160 mm[Hg]'
      ELSE
           false
      END
)
SELECT json_object(('{orga_enti_id, ' || orga_enti_id ||
                    ', ptnt_id, '     || ptnt_id      ||
                    ', peso_id, '     || peso_id      || '}')::text[])::text
                   , _code_code
                   , CASE WHEN _code_code = '8480-6' THEN convert(avg_value_pq, 'mm[Hg]') ELSE _value_pq END
FROM selectExtremes
ORDER BY 1,2
$ct$,
$ct$VALUES('103232008'::text)
    ,     ('85600001')
    ,     ('8480-6')$ct$
)
AS ct(rowid jsonb, "Extreme HBA1c/GlycHb" pq, "Extreme Triglyceride" pq, "Extreme Systolic blood pressure" pq)
)
SELECT extreme_ct.*
,      peso."birthTime"                         AS birthtime
,      peso."administrativeGenderCode"->>'code' AS administrative_gender
FROM   extreme_ct
JOIN  "Person" peso
ON     peso._id  = extreme_ct.peso_id
;
