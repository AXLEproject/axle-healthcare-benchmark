/*
 * examples.sql
 *
 * This file is part of the MGRID HDW sample datawarehouse release.
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */

-- select from the Allergy - Intolerance template
select prov.name_full as provider_name, pat.name_full as patient_name, displayname(value_cv) as intolerance, prod.displayname as agent
from view_templates."2_16_840_1_113883_10_20_22_4_7" as allergy
join dim_patient pat on allergy.patient_sk = pat.id
join dim_concept prod on allergy.product_sk = prod.id
join dim_provider prov on allergy.provider_sk = prov.id
;

-- select from the "Reaction Observation" template
select prov.name_full as provider_name, pat.name_full as patient_name, displayname(value_cv) as intolerance, prod.displayname as agent
from view_templates."2_16_840_1_113883_10_20_22_4_9" as allergy
join dim_patient pat on allergy.patient_sk = pat.id
join dim_concept prod on allergy.product_sk = prod.id
join dim_provider prov on allergy.provider_sk = prov.id
;
