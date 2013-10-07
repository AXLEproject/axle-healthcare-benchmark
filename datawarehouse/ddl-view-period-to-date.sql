/*
 * ddl-view-period-to-date.sql
 *
 * This file is part of the MGRID HDW sample datawarehouse release.
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */

DROP TYPE IF EXISTS ytd_patients_per_code CASCADE;
CREATE TYPE ytd_patients_per_code AS (
  provider_sk   INTEGER
, patient_sk    INTEGER
);

/*
 * ytd_patients_per_code returns a set of (provider_sk, patient_sk) tuples of facts
 * that:
 * - have a code that is subsumed by the generic concept in_code:in_codesystem
 * - have a from_time that is not older than the interval in_age from in_reference_date
 */



CREATE OR REPLACE FUNCTION period_to_date.ytd_patients_per_code(in_code TEXT, in_codesystem TEXT, in_reference_date TIMESTAMPTZ, in_age INTERVAL)
RETURNS SETOF ytd_patients_per_code AS $$
    SELECT provider_sk, patient_sk
    FROM (SELECT provider_sk, patient_sk, concept_sk, from_time_sk FROM fact_observation_evn_cv
          UNION ALL
          SELECT provider_sk, patient_sk, concept_sk, from_time_sk FROM fact_observation_evn_pq
          UNION ALL
          SELECT provider_sk, patient_sk, concept_sk, from_time_sk FROM fact_battery_evn
         ) fact
    JOIN dim_concept fdc ON fact.concept_sk = fdc.id
    JOIN dim_concept ac ON ac.id = ANY(fdc.ancestor)
    JOIN dim_time dt ON fact.from_time_sk = dt.id
    WHERE ac.code = $1
    AND ac.codesystem = $2
    AND dt.time <= $3
    AND age($3, dt.time) <= $4
    ;
$$ LANGUAGE SQL;



CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_foot_problems AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM period_to_date.ytd_patients_per_code(
  '299478007' -- foot problem
, '2.16.840.1.113883.6.96' -- SNOMED CT
, current_timestamp
, '1 year'
)
GROUP BY provider_sk
;

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_foot_abnormalities AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM period_to_date.ytd_patients_per_code(
  '309597007'              -- Foot abnormality - diabetes-related
, '2.16.840.1.113883.6.96' -- SNOMED CT
, current_timestamp
, '1 year'
)
GROUP BY provider_sk
;

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_foot_amputations AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM period_to_date.ytd_patients_per_code(
  '299653001'              -- Amputated foot
, '2.16.840.1.113883.6.96' -- SNOMED CT
, current_timestamp
, '1 year'
)
GROUP BY provider_sk
;

CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_ulcers AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM period_to_date.ytd_patients_per_code(
  '201251005'              -- Neuropathic diabetic ulcer - foot
, '2.16.840.1.113883.6.96' -- SNOMED CT
, current_timestamp
, '1 year'
)
GROUP BY provider_sk
;


CREATE OR REPLACE VIEW period_to_date.ytd_patients_with_examinations AS
SELECT provider_sk, COUNT(distinct patient_sk)
FROM period_to_date.ytd_patients_per_code(
  '401191002' -- foot examination
, '2.16.840.1.113883.6.96' -- SNOMED CT
, current_timestamp
, '1 year'
)
GROUP BY provider_sk
;

