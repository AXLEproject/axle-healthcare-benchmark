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
 WITH facets_221 AS
(
  SELECT ptnt._id                         AS ptnt_id
  ,      ptnt.scoper                      AS orga_enti_id
  ,      ptnt.player                      AS peso_id
  ,      ex._id                           AS ex_id
  ,      ex._code_code
  ,      ex.code->>'displayName'          AS displayname
  ,      ex._effective_time_low
  ,      _value_pq
  ,      RANK() OVER (PARTITION BY ptnt.scoper, ptnt._id, ex._code_code
         ORDER BY ex._effective_time_low DESC, ex._id DESC) AS rocky
  ,      AVG(_value_pq) OVER (PARTITION BY ptnt.scoper, ptnt._id, ex._code_code) AS avg_value_pq
  FROM  "Observation"                    ex
  JOIN  "Participation"                  ex_ptcp
  ON     ex_ptcp.act                     = ex._id
  AND    ex_ptcp."typeCode"->>'code'     = 'RCT'
  JOIN   "Patient"                       ptnt
  ON     ptnt._id                        = ex_ptcp.role
  WHERE  ex._effective_time_low_year BETWEEN 2013 AND 2014
  AND    ex._effective_time_low >= '20130501'
  AND   ((_code_code = '103232008' AND _code_codesystem = '2.16.840.1.113883.6.96') -- hba1c, snomed
         OR
         (_code_code = '85600001' AND _code_codesystem = '2.16.840.1.113883.6.96')  -- triglyceride, snomed
         OR
         (_code_code = '8480-6' AND _code_codesystem = '2.16.840.1.113883.6.1')     -- systolic bp, loinc
         )
),
selectExtremes AS (
  SELECT 'Extreme ' || displayname       AS what
  ,      orga_enti_id
  ,      ptnt_id
  ,      peso_id
  ,      _code_code
  ,      _value_pq
  ,      avg_value_pq
  FROM facets_221
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
                    ', ptnt_id, '|| ptnt_id ||
                    ', peso_id, '|| peso_id || '}')::text[])::text
                   , what
                   , CASE WHEN _code_code = '8480-6' THEN convert(avg_value_pq, 'mm[Hg]') ELSE _value_pq END
FROM selectExtremes
ORDER BY 1,2
$ct$,
$ct$VALUES('Extreme HBA1c/GlycHb'::text)
    ,     ('Extreme Triglyceride')
    ,     ('Extreme Systolic blood pressure')$ct$
)
AS ct(rowid jsonb, "Extreme HBA1c/GlycHb" pq, "Extreme Triglyceride" pq, "Extreme Systolic blood pressure" pq)
)
SELECT extreme_ct.*
,      peso."birthTime"::timestamptz            AS birthtime
,      peso."administrativeGenderCode"->>'code' AS administrative_gender
FROM   extreme_ct
JOIN  "Person" peso
ON     peso._id  = extreme_ct.peso_id
;
