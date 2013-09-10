-- DATABASE dwh

SET search_path=atomic, public, "$user";

-- Allergy list
-- this query returns all coded observations that have
-- a code that is subsumed by the generic concept
select distinct p.set_nk, time, fdc.displayname from fact_observation_evn_cv f
join dim_concept fdc
on f.concept_sk = fdc.id
join  dim_concept ac
on ac.id = ANY (fdc.ancestor)
join dim_patient p
ON f.patient_sk = p.id
join dim_time t
ON f.from_time_sk = t.id
where ac.codesystem='2.16.840.1.113883.6.96'
and ac.code='420134006' -- Propensity to adverse reactions
;