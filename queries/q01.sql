-- DATABASE dwh

/** The function latest_measurement takes a code (+ code system) and time interval
    as input and returns the latest measurement for the given code within the given
    time interval for each patient. The output is ordered by patient_id and effective_from
*/

SET search_path=atomic, public, "$user";

DROP TYPE IF EXISTS measurement CASCADE;
CREATE TYPE measurement AS (
  patient_id     INT
, code           TEXT
, displayname    TEXT
, from_time      TIMESTAMPTZ
, value_pq_value NUMERIC
, value_pq_unit  TEXT
);

DROP FUNCTION IF EXISTS latest_measurements(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ);

CREATE OR REPLACE FUNCTION latest_measurements(code TEXT, codesystem TEXT, from_time TIMESTAMPTZ, to_time TIMESTAMPTZ)
RETURNS SETOF measurement
AS $$
SELECT patient_id
    , code
    , displayname
    , from_time
    , value_pq_value
    , value_pq_unit
FROM (
    SELECT dim_patient.id patient_id
    , dim_concept.code
    , dim_concept.displayname
    , dtf.time as from_time
    , value_pq_value
    , value_pq_unit
    , max(dtf.time) OVER (PARTITION BY dim_patient.id, dim_concept.code) AS max_from_time
    FROM fact_observation_evn fact
    JOIN dim_concept       ON fact.concept_sk = dim_concept.id
    JOIN dim_patient       ON fact.patient_sk = dim_patient.id
    JOIN dim_time dtf      ON fact.from_time_sk = dtf.id
    WHERE dim_concept.code         = $1
    AND   dim_concept.codesystem   = $2
    AND   dtf.time BETWEEN $3 AND $4
) all_obs
WHERE from_time = max_from_time
ORDER BY patient_id, from_time
;
$$ LANGUAGE SQL;

/* example calls for some codes for 2011 */

SELECT * FROM latest_measurements('50373000', '2.16.840.1.113883.6.96','20110101','20111231'); -- body height (SNOMED CT)
SELECT * FROM latest_measurements('27113001', '2.16.840.1.113883.6.96','20110101','20111231'); -- body weight (SNOMED CT)
SELECT * FROM latest_measurements('60621009', '2.16.840.1.113883.6.96','20110101','20111231'); -- body mass index (SNOMED CT)
SELECT * FROM latest_measurements('364075005', '2.16.840.1.113883.6.96','20110101','20111231'); -- heart rate (SNOMED CT)
SELECT * FROM latest_measurements('86290005', '2.16.840.1.113883.6.96','20110101','20111231'); -- respiratory rate (SNOMED CT)
SELECT * FROM latest_measurements('8462-4', '2.16.840.1.113883.6.1','20110101','20111231'); -- intravascular diastolic (LOINC)
SELECT * FROM latest_measurements('8480-6', '2.16.840.1.113883.6.1','20110101','20111231'); -- intravascular systolic (LOINC)
