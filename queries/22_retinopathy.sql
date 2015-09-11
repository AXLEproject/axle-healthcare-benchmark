/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Calculate re-identification risk.
 *
 * Copyright (c) 2014, Portavita B.V.
 */

\set ON_ERROR_STOP on
\i retinopathy_checks.sql
\set ON_ERROR_STOP off

/*
 * Prosecutor risk
 */

/*
 * List equivalence classes, frequencies and prosecutor risk for the X most risky classes.
 */
WITH equivalence_classes AS
(
select age_in_years
,      gender
,      smok_lv
,      row_number() over (partition by age_in_years, gender, smok_lv) as rocky
,      count(1)     over (partition by age_in_years, gender, smok_lv) as count
from
retinopathy_tabular_data
)
SELECT age_in_years
,      gender
,      smok_lv
,      count AS "fk" -- frequency
, CASE WHEN count > 0 THEN 1::float/count ELSE NULL END as "1/fk" -- prosecutor risk
FROM equivalence_classes WHERE rocky = 1
order by count asc
limit 10;


/*
 * Calculate percentage of rows in the dataset at risk, given threshold of 0.05
 */
WITH equivalence_classes AS (
 select age_in_years
 , gender
 , smok_lv
 , row_number() over (partition by age_in_years, gender, smok_lv) as rocky
 , count(1)     over (partition by age_in_years, gender, smok_lv) as classsize
 from
 retinopathy_tabular_data
),
size AS (
 select count(*) AS denom
 from retinopathy_tabular_data
),
records_at_risk AS (
 select sum(classsize) as num
 from equivalence_classes
 where (CASE WHEN classsize > 0 THEN 1::float/classsize ELSE NULL END) > 0.05
 and rocky = 1
)
SELECT num
,      denom
,      ROUND(num::float / denom * 100) AS perc_records_at_risk_prosecutor
FROM size, records_at_risk;

