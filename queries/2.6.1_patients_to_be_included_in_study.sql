/* Select all patients for which at least one of the following examinatios
 * exists in a specified period of time.
*/
 SELECT DISTINCT obse_ptcp.role          AS ptnt_id
  FROM  "Observation"                    obse
  JOIN  "Participation"                  obse_ptcp
  ON     obse_ptcp.act                   = obse._id
  AND    obse_ptcp."typeCode"->>'code'   = 'RCT'
  WHERE  obse._effective_time_low_year BETWEEN 2013 AND 2014
  AND    obse._effective_time_low >= '20130501'
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
