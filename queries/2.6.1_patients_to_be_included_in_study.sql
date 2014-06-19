/* Select all patients for which at least one of the following examinatios
 * exists in a specified period of time.
*/
SELECT  DISTINCT exam_ptcp.role          AS ptnt_id
  FROM   ONLY "Act"                       exam
  JOIN   "Participation"                  exam_ptcp
  ON     exam_ptcp.act                   = exam._id
  AND    exam_ptcp."typeCode"->>'code'   = 'RCT'
  WHERE  '[{"root": "2.16.840.1.113883.2.4.3.31.4.2.1", "dataType": "II", "extension": "1"}]' @> exam."templateId"
  AND    exam._effective_time_low_year BETWEEN 2013 AND 2014
  AND    exam._effective_time_low >= '20130501'
  AND   ((_code_code = '170777000' AND _code_codesystem = '2.16.840.1.113883.6.96') -- annual checkup, snomed
         OR
         (_code_code = '170744004' AND _code_codesystem = '2.16.840.1.113883.6.96') -- quarterly checkup, snomed
         OR
         (_code_code = '401191002' AND _code_codesystem = '2.16.840.1.113883.6.96') -- foot checkup, snomed
         OR
         (_code_code = '183056000' AND _code_codesystem = '2.16.840.1.113883.6.96') -- dietary advice, snomed
         OR
         (_code_code = '170757007' AND _code_codesystem = '2.16.840.1.113883.6.96') -- fundus photo checkup, snomed
         OR
         (_code_code = 'Portavita140' AND _code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1') -- risk inventory
         OR
         (_code_code = 'Portavita154' AND _code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1') -- interim checkup
         OR
         (_code_code = 'Portavita136' AND _code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1') -- self checkup
         OR
         (_code_code = 'Portavita224' AND _code_codesystem = '2.16.840.1.113883.2.4.3.31.2.1') -- ophtalmologic checkup
        )
  ;
