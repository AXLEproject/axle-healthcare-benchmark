/*
 * Examinations are defined as the direct childs of DOCSECTS.
 */
CREATE OR REPLACE VIEW examinations AS
SELECT
            ptnt.player           AS peso_id
,           ptnt._id              AS ptnt_id
,           exam._id
,           exam.code
,           exam."classCode"
,           exam._effective_time_low
,           exam._effective_time_low_year
,           exam._effective_time_low_month
,           RANK() OVER (PARTITION BY ptnt.player, exam.code->>'code'
                         ORDER BY exam._effective_time_low DESC, exam._id DESC) AS rocky
FROM        "Act"                   exam
JOIN        "Participation"         rct_ptcp
ON          rct_ptcp.act        =   exam._id
AND         rct_ptcp."typeCode"->>'code' = 'RCT' -- PRF, AUT as well.
JOIN        "Patient"               ptnt
ON          ptnt._id            =   rct_ptcp.role
WHERE       '[{"root": "2.16.840.1.113883.2.4.3.31.4.2.1", "dataType": "II", "extension": "1"}]' @> exam."templateId"
;
