/*
 * ddl-view-period-to-date.sql
 *
 * This file is part of the MGRID HDW sample datawarehouse release.
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_foot_problems AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM fact_observation_evn_cv fact
JOIN dim_concept dc ON fact.concept_sk = dc.id
JOIN dim_time dt ON fact.from_time_sk = dt.id
WHERE code = '299478007' -- foot problem
AND codesystem = '2.16.840.1.113883.6.96' -- SNOMED CT
AND age(dt.time) < '1 year'
GROUP BY provider_sk
;

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_foot_abnormalities AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM fact_observation_evn_cv fact
JOIN dim_concept dc ON fact.concept_sk = dc.id
JOIN dim_time dt ON fact.from_time_sk = dt.id
WHERE code = '309597007' -- Foot abnormality - diabetes-related
AND codesystem = '2.16.840.1.113883.6.96' -- SNOMED CT
AND age(dt.time) < '1 year'
GROUP BY provider_sk
;

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_foot_amputations AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM fact_observation_evn_cv fact
JOIN dim_concept dc ON fact.concept_sk = dc.id
JOIN dim_time dt ON fact.from_time_sk = dt.id
WHERE code = '299653001' -- Amputated foot
AND codesystem = '2.16.840.1.113883.6.96' -- SNOMED CT
AND age(dt.time) < '1 year'
GROUP BY provider_sk
;

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_ulcers AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM fact_observation_evn_cv fact
JOIN dim_concept dc ON fact.concept_sk = dc.id
JOIN dim_time dt ON fact.from_time_sk = dt.id
WHERE code = '201251005' -- Neuropathic diabetic ulcer - foot
AND codesystem = '2.16.840.1.113883.6.96' -- SNOMED CT
AND age(dt.time) < '1 year'
GROUP BY provider_sk
;


CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_examinations AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM fact_battery_evn fact
JOIN dim_concept dc ON fact.concept_sk = dc.id
JOIN dim_time dt ON fact.from_time_sk = dt.id
WHERE code = '401191002' -- foot examination
AND codesystem = '2.16.840.1.113883.6.96' -- SNOMED CT
AND age(dt.time) < '1 year'
GROUP BY provider_sk
;

