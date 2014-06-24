/*
 * query      : 2.0.1
 * description: materialization of examinations for other queries
 * user       : care group employees and quality employees
 *
 * Copyright (c) 2014, Portavita B.V.
 */
DROP VIEW IF EXISTS examinations_view;
CREATE OR REPLACE VIEW examinations_view AS
SELECT
            ptnt.player           AS peso_id
,           ptnt._id              AS ptnt_id
,           exam._id              AS act_id
,           exam._code_code       AS code
,           exam._code_codesystem AS codesystem
,           exam."classCode"
,           exam._effective_time_low        AS effective_time_low
,           exam._effective_time_low_year   AS effective_time_low_year
,           exam._effective_time_low_month  AS effective_time_low_month
,           RANK() OVER (PARTITION BY ptnt.player, exam._code_codesystem, exam._code_code
                         ORDER BY exam._effective_time_low DESC, exam._id DESC) AS rocky
FROM        "Act"                   exam
JOIN        "Participation"         rct_ptcp
ON          rct_ptcp.act        =   exam._id
AND         rct_ptcp."typeCode"->>'code' = 'RCT'
JOIN        "Patient"               ptnt
ON          ptnt._id            =   rct_ptcp.role
WHERE       '[{"root": "2.16.840.1.113883.2.4.3.31.4.2.1", "dataType": "II", "extension": "1"}]' @> exam."templateId"
;

DROP TABLE IF EXISTS examinations;
CREATE TABLE examinations AS
  SELECT *
  FROM   examinations_view
;
