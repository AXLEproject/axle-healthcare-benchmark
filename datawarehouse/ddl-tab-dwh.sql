/*
 * ddl-tab-dwh.sql
 *
 * This file is part of the MGRID HDW sample datawarehouse release.
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */

DROP SEQUENCE IF EXISTS dim_concept_seq CASCADE;
CREATE SEQUENCE dim_concept_seq;
DROP SEQUENCE IF EXISTS dim_concept_role_seq CASCADE;
CREATE SEQUENCE dim_concept_role_seq;

DROP TABLE IF EXISTS dim_concept CASCADE;
DROP TABLE IF EXISTS dim_concept_role CASCADE;

/*
 * Concept dimension.
 *
 * We need the dim_concept_role dimension to capture code qualifiers, this
 * dimension does not have an attribute in the fact table but is (implictly)
 * referred to by the dim_concept.qualifier attribute.
 *
 * Given a qualified concept (e.g. left leg), query the dim_concept on the code
 * and codesystem and NULL qualifier to find the parent concept.
 */
CREATE TABLE dim_concept (
  id                          int PRIMARY KEY
, code                        TEXT
, codesystem                  TEXT
, codesystemname              TEXT
, codesystemversion           TEXT
, displayname                 TEXT
, ancestor                    int[] /* references dim_concept(id) */
, translation                 int[] /* references dim_concept(id) */
, qualifier                   int[] /* references dim_concept_role(id) */
);
COMMENT ON TABLE dim_concept IS
'Dimension table for concepts (cd, cv and cs attributes).';
COMMENT ON COLUMN dim_concept.ancestor IS
'The reflexive transitive closure of the implied-by relation for hierarchical codesystems. References dim_concept(id).';
COMMENT ON COLUMN dim_concept.translation IS
'The translations of the concept in another language. References dim_concept(id).';
COMMENT ON COLUMN dim_concept.qualifier IS
'The qualifiers of this concept. References dim_concept_role(id).';

CREATE TABLE dim_concept_role (
  id                          int PRIMARY KEY
, name                        int REFERENCES dim_concept(id) NOT NULL
, value                       int REFERENCES dim_concept(id) NOT NULL
, inverted                    BOOLEAN
);
COMMENT ON TABLE dim_concept_role IS
'Dimension table for concept qualifiers.';

DROP SEQUENCE IF EXISTS dim_time_seq CASCADE;
CREATE SEQUENCE dim_time_seq START WITH 3;

DROP TABLE IF EXISTS dim_time CASCADE;
CREATE TABLE dim_time(
  id                 int PRIMARY KEY
, day                INT
, month              INT
, year               INT
, dow                INT
, quarter            INT
, hour               INT
, minutes            INT
, time               timestamptz
);
COMMENT ON TABLE dim_time IS
'Dimension table for time granularities.';

DROP SEQUENCE IF EXISTS dim_patient_seq CASCADE;
CREATE SEQUENCE dim_patient_seq;

DROP TABLE IF EXISTS dim_patient CASCADE;
CREATE TABLE dim_patient (
  id                            int PRIMARY KEY
, set_nk                        text[]
, gender                        TEXT
, birthtime                     date
, name_family                   text
, name_given                    text
, name_prefix                   text
, name_suffix                   text
, name_delimiter                text
, name_full                     text
, type_2_hash                   int
, valid_from                    timestamptz
, valid_to                      timestamptz
, current_flag                  boolean
);
COMMENT ON TABLE dim_patient IS
'This table is called patient instead of e.g. dim_rct since it can contain both record targets and subjects. Information from both Person and Patient is used to populate it.';
COMMENT ON COLUMN dim_patient.set_nk IS
'Natural key. As the way to uniquely identify a patient differs per source database, this value must be supplied by the user, by implementing the function person2nk.';
COMMENT ON COLUMN dim_patient.name_full IS
'As there is no standard translation from EN to the full name, the method to populate this column must be supplied by the user, by implementing the function bag_en2dimension_name_type.';

DROP SEQUENCE IF EXISTS dim_provider_seq CASCADE;
CREATE SEQUENCE dim_provider_seq;

DROP TABLE IF EXISTS dim_provider CASCADE;
CREATE TABLE dim_provider (
  id                            int PRIMARY KEY
, set_nk                        text[]
, gender                        TEXT
, name_family                   text
, name_given                    text
, name_prefix                   text
, name_suffix                   text
, name_delimiter                text
, name_full                     text
, type_2_hash                   int
, valid_from                    timestamptz
, valid_to                      timestamptz
, current_flag                  boolean
);
COMMENT ON TABLE dim_provider IS
'This table contains the healthcare providers that engaged in the activities.';
COMMENT ON COLUMN dim_provider.set_nk IS
'Natural key. As the way to uniquely identify a provider differs per source database, this value must be supplied by the user, by implementing the function provider2nk.';


DROP SEQUENCE IF EXISTS dim_organization_seq CASCADE;
CREATE SEQUENCE dim_organization_seq;

DROP TABLE IF EXISTS dim_organization CASCADE;
CREATE TABLE dim_organization (
  id                            int PRIMARY KEY
, set_nk                        text[]
, name                          text
, street                        text
, zipcode                       text
, city                          text
, state                         text
, country                       text
, type_2_hash                   int
, valid_from                    timestamptz
, valid_to                      timestamptz
, current_flag                  boolean
);
COMMENT ON TABLE dim_organization IS
'This table contains the healthcare organizations that the healthcare providers belong to.';
COMMENT ON COLUMN dim_organization.set_nk IS
'Natural key. As the way to uniquely identify an organization differs per source database, this value must be supplied by the user, by implementing the function organization2nk.';

DROP TABLE IF EXISTS template CASCADE;
CREATE TABLE template (
  template_id            text PRIMARY KEY
, template_type          text
, template_title         text
, source                 text
)
;
COMMENT ON TABLE template IS
'Lists known template oids and names. Used in conjunction with dim_template.';


DROP SEQUENCE IF EXISTS dim_template_seq CASCADE;
CREATE SEQUENCE dim_template_seq;

DROP TABLE IF EXISTS dim_template CASCADE;
CREATE TABLE dim_template (
  id                            int PRIMARY KEY
, template_id                   text[]
, id_1                          text
, id_2                          text
, id_3                          text
, id_4                          text
, id_5                          text
, id_6                          text
, id_7                          text
, id_8                          text
, id_9                          text
);
COMMENT ON TABLE dim_template IS
'Dimension table for templates.';
COMMENT ON COLUMN dim_template.template_id IS
'The template oid. References template(template_id).';


DROP SEQUENCE IF EXISTS fact_observation_evn_pq_seq CASCADE;
CREATE SEQUENCE fact_observation_evn_pq_seq;

DROP TABLE IF EXISTS fact_observation_evn_pq CASCADE;
CREATE TABLE fact_observation_evn_pq(
  id                              int           PRIMARY KEY
, act_id                          text[]
, patient_sk                      int           REFERENCES dim_patient(id)
, provider_sk                     int           REFERENCES dim_provider(id)
, organization_sk                 int           REFERENCES dim_organization(id)
, from_time_sk                    int           REFERENCES dim_time(id)
, to_time_sk                      int           REFERENCES dim_time(id)
, concept_sk                      int           REFERENCES dim_concept(id)
, concept_originaltext_reference  text
, concept_originaltext_value      text
, template_id_sk                  int           REFERENCES dim_template(id)
, product_sk                      int           REFERENCES dim_concept(id)
, value_pq_unit                   text
, value_pq_value                  numeric
, value_pq_canonical_unit         text
, value_pq_canonical_value        numeric
, timestamp                       timestamptz
);

COMMENT ON TABLE fact_observation_evn_pq IS
'Transactional Observation EVN fact table containing physical quantities';

COMMENT ON COLUMN fact_observation_evn_pq.timestamp IS
'This is the same value as the source act timestamp and can be used to query what is the last etl-ed act.';
COMMENT ON COLUMN fact_observation_evn_pq.act_id IS
'Natural key';
COMMENT ON COLUMN fact_observation_evn_pq.value_pq_unit IS
'The pq values are only filled for values that are Physical Quantities';


DROP SEQUENCE IF EXISTS fact_observation_evn_cv_seq CASCADE;
CREATE SEQUENCE fact_observation_evn_cv_seq;

DROP TABLE IF EXISTS fact_observation_evn_cv CASCADE;
CREATE TABLE fact_observation_evn_cv(
  id                              int           PRIMARY KEY
, act_id                          text[]
, patient_sk                      int           REFERENCES dim_patient(id)
, provider_sk                     int           REFERENCES dim_provider(id)
, organization_sk                 int           REFERENCES dim_organization(id)
, from_time_sk                    int           REFERENCES dim_time(id)
, to_time_sk                      int           REFERENCES dim_time(id)
, concept_sk                      int           REFERENCES dim_concept(id)
, concept_originaltext_reference  text
, concept_originaltext_value      text
, template_id_sk                  int           REFERENCES dim_template(id)
, product_sk                      int           REFERENCES dim_concept(id)
, value_concept_sk                int           REFERENCES dim_concept(id)
, timestamp                       timestamptz
);

COMMENT ON TABLE fact_observation_evn_cv IS
'Transactional Observation EVN fact table containing coded values';

/***
 fact_observation_evn_text:
 to contain all observation events that are not pq nor cd.
 is not (yet) filled by the example code

DROP SEQUENCE IF EXISTS fact_observation_evn_text_seq CASCADE;
CREATE SEQUENCE fact_observation_evn_text_seq;

DROP TABLE IF EXISTS fact_observation_evn_text CASCADE;
CREATE TABLE fact_observation_evn_text(
  id                              int              PRIMARY KEY
, act_id                          text[]
, patient_sk                      int              REFERENCES dim_patient(id)
, provider_sk                     int              REFERENCES dim_provider(id)
, organization_sk                 int              REFERENCES dim_organization(id)
, from_time_sk                    int              REFERENCES dim_time(id)
, to_time_sk                      int              REFERENCES dim_time(id)
, concept_sk                      int              REFERENCES dim_concept(id)
, concept_originaltext_reference  text
, concept_originaltext_value      text
, template_id_sk                  int              REFERENCES dim_template(id)
, product_sk                      int              REFERENCES dim_concept(id)
, value                           text
, timestamp                       timestamptz
);
**/

/*** overall view over fact tables ***/
CREATE OR REPLACE VIEW fact_observation_evn AS
      SELECT id, act_id, patient_sk, provider_sk, organization_sk, from_time_sk, to_time_sk, concept_sk, concept_originaltext_reference, concept_originaltext_value, template_id_sk, value_pq_unit, value_pq_value, value_pq_canonical_unit, value_pq_canonical_value, null as value_concept_sk, null as value, product_sk, timestamp
      FROM fact_observation_evn_pq
      UNION ALL
      SELECT id, act_id, patient_sk, provider_sk, organization_sk, from_time_sk, to_time_sk, concept_sk, concept_originaltext_reference, concept_originaltext_value, template_id_sk, null as value_pq_unit, null as value_pq_value, null as value_pq_canonical_unit, null as value_pq_canonical_value, value_concept_sk, null, product_sk, timestamp
      FROM fact_observation_evn_cv
;
COMMENT ON VIEW fact_observation_evn IS
'A view that combines the individual fact tables. Used for easy querying of e.g. the last timestamp for streaming ETL.';

/*
 * On PostgreSQL > 9.1 databases, loading data in the datawarehouse is done
 * with file_fdw.
 */
CREATE OR REPLACE FUNCTION pg_version_num() RETURNS int
AS $$
   SELECT setting::int FROM pg_settings WHERE NAME='server_version_num';
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION dropme() RETURNS void
AS $$
BEGIN
        IF pg_version_num() >= 90100 THEN
           EXECUTE 'DROP SERVER IF EXISTS changeset CASCADE;';
           EXECUTE 'CREATE EXTENSION file_fdw;';
           EXECUTE 'CREATE SERVER changeset FOREIGN DATA WRAPPER file_fdw;';
        END IF;
END;
$$ LANGUAGE plpgsql;

SELECT dropme();
DROP FUNCTION dropme();

/* Insert dummy values for dimensions */

INSERT INTO dim_concept(id,code,displayname)
VALUES (0,'Unknown','Unknown');

INSERT INTO dim_patient(id,name_family,valid_from, valid_to ,current_flag)
VALUES (0,'Unknown', '00010101 00:00:00', '99991231 23:59:59',True);

INSERT INTO dim_provider(id,name_family,valid_from, valid_to,current_flag)
VALUES (0,'Unknown', '00010101 00:00:00', '99991231 23:59:59',True);

INSERT INTO dim_organization(id,name,valid_from, valid_to,current_flag)
VALUES (0,'Unknown', '00010101 00:00:00', '99991231 23:59:59',True);

/* insert known template ids */
INSERT INTO template(template_title,template_type,template_id,source) VALUES
('US Realm Address (AD.US.FIELDED)','header','2.16.840.1.113883.10.20.22.5.2','Consolidated CDA implementation guide'),
('US Realm Date and Time (DT.US.FIELDED)',NULL,'2.16.840.1.113883.10.20.22.5.3','Consolidated CDA implementation guide'),
('US Realm Date and Time (DTM.US.FIELDED)',NULL,'2.16.840.1.113883.10.20.22.5.4','Consolidated CDA implementation guide'),
('US Realm Patient Name (PTN.US.FIELDED)',NULL,'2.16.840.1.113883.10.20.22.5.1','Consolidated CDA implementation guide'),
('US Realm Person Name  (PN.US.FIELDED)',NULL,'2.16.840.1.113883.10.20.22.5.1.1','Consolidated CDA implementation guide'),
('Consultation Note','document','2.16.840.1.113883.10.20.22.1.4','Consolidated CDA implementation guide'),
('Continuity of Care Document (CCD)','document','2.16.840.1.113883.10.20.22.1.2','Consolidated CDA implementation guide'),
('Diagnostic Imaging Report','document','2.16.840.1.113883.10.20.22.1.5','Consolidated CDA implementation guide'),
('Discharge Summary','document','2.16.840.1.113883.10.20.22.1.8','Consolidated CDA implementation guide'),
('History and Physical','document','2.16.840.1.113883.10.20.22.1.3','Consolidated CDA implementation guide'),
('Operative Note','document','2.16.840.1.113883.10.20.22.1.7','Consolidated CDA implementation guide'),
('Procedure Note','document','2.16.840.1.113883.10.20.22.1.6','Consolidated CDA implementation guide'),
('Progress Note','document','2.16.840.1.113883.10.20.22.1.9','Consolidated CDA implementation guide'),
('Unstructured Document','document','2.16.840.1.113883.10.20.22.1.10','Consolidated CDA implementation guide'),
('US Realm Header','document','2.16.840.1.113883.10.20.22.1.1','Consolidated CDA implementation guide'),
('Advance Directives Section (Entries optional)','section','2.16.840.1.113883.10.20.22.2.21','Consolidated CDA implementation guide'),
('Advance Directives Section (entries required)','section','2.16.840.1.113883.10.20.22.2.21.1','Consolidated CDA implementation guide'),
('Allergies Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.6','Consolidated CDA implementation guide'),
('Allergies Section (entries required)','section','2.16.840.1.113883.10.20.22.2.6.1','Consolidated CDA implementation guide'),
('Anesthesia Section','section','2.16.840.1.113883.10.20.22.2.25','Consolidated CDA implementation guide'),
('Assessment and Plan Section','section','2.16.840.1.113883.10.20.22.2.9','Consolidated CDA implementation guide'),
('Assessment Section','section','2.16.840.1.113883.10.20.22.2.8','Consolidated CDA implementation guide'),
('Chief Complaint and Reason for Visit Section','section','2.16.840.1.113883.10.20.22.2.13','Consolidated CDA implementation guide'),
('Chief Complaint Section','section','1.3.6.1.4.1.19376.1.5.3.1.1.13.2.1','Consolidated CDA implementation guide'),
('Complications Section','section','2.16.840.1.113883.10.20.22.2.37','Consolidated CDA implementation guide'),
('DICOM Object Catalog Section - DCM 121181','section','2.16.840.1.113883.10.20.6.1.1','Consolidated CDA implementation guide'),
('Discharge Diet Section','section','1.3.6.1.4.1.19376.1.5.3.1.3.33','Consolidated CDA implementation guide'),
('Encounters Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.22','Consolidated CDA implementation guide'),
('Encounters Section (entries required)','section','2.16.840.1.113883.10.20.22.2.22.1','Consolidated CDA implementation guide'),
('Family History Section','section','2.16.840.1.113883.10.20.22.2.15','Consolidated CDA implementation guide'),
('Fetus Subject Context','section','2.16.840.1.113883.10.20.6.2.3','Consolidated CDA implementation guide'),
('Findings Section (DIR)','section','2.16.840.1.113883.10.20.6.1.2','Consolidated CDA implementation guide'),
('Functional Status Section','section','2.16.840.1.113883.10.20.22.2.14','Consolidated CDA implementation guide'),
('General Status Section','section','2.16.840.1.113883.10.20.2.5','Consolidated CDA implementation guide'),
('History of Past Illness Section','section','2.16.840.1.113883.10.20.22.2.20','Consolidated CDA implementation guide'),
('History of Present Illness Section','section','1.3.6.1.4.1.19376.1.5.3.1.3.4','Consolidated CDA implementation guide'),
('Hospital Admission Diagnosis Section','section','2.16.840.1.113883.10.20.22.2.43','Consolidated CDA implementation guide'),
('Hospital Admission Medications Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.44','Consolidated CDA implementation guide'),
('Hospital Consultations Section','section','2.16.840.1.113883.10.20.22.2.42','Consolidated CDA implementation guide'),
('Hospital Course Section','section','1.3.6.1.4.1.19376.1.5.3.1.3.5','Consolidated CDA implementation guide'),
('Hospital Discharge Diagnosis Section','section','2.16.840.1.113883.10.20.22.2.24','Consolidated CDA implementation guide'),
('Hospital Discharge Instructions Section','section','2.16.840.1.113883.10.20.22.2.41','Consolidated CDA implementation guide'),
('Hospital Discharge Medications Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.11','Consolidated CDA implementation guide'),
('Hospital Discharge Medications Section (entries required)','section','2.16.840.1.113883.10.20.22.2.11.1','Consolidated CDA implementation guide'),
('Hospital Discharge Physical Section','section','1.3.6.1.4.1.19376.1.5.3.1.3.26','Consolidated CDA implementation guide'),
('Hospital Discharge Studies Summary Section','section','2.16.840.1.113883.10.20.22.2.16','Consolidated CDA implementation guide'),
('Immunizations Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.2','Consolidated CDA implementation guide'),
('Immunizations Section (entries required)','section','2.16.840.1.113883.10.20.22.2.2.1','Consolidated CDA implementation guide'),
('Implants Section','section','2.16.840.1.113883.10.20.22.2.33','Consolidated CDA implementation guide'),
('Instructions Section','section','2.16.840.1.113883.10.20.22.2.45','Consolidated CDA implementation guide'),
('Interventions Section','section','2.16.840.1.113883.10.20.21.2.3','Consolidated CDA implementation guide'),
('Medical (General) History Section','section','2.16.840.1.113883.10.20.22.2.39','Consolidated CDA implementation guide'),
('Medical Equipment Section','section','2.16.840.1.113883.10.20.22.2.23','Consolidated CDA implementation guide'),
('Medications Administered Section','section','2.16.840.1.113883.10.20.22.2.38','Consolidated CDA implementation guide'),
('Medications Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.1','Consolidated CDA implementation guide'),
('Medications Section (entries required)','section','2.16.840.1.113883.10.20.22.2.1.1','Consolidated CDA implementation guide'),
('Objective Section','section','2.16.840.1.113883.10.20.21.2.1','Consolidated CDA implementation guide'),
('Observer Context','section','2.16.840.1.113883.10.20.6.2.4','Consolidated CDA implementation guide'),
('Operative Note Fluids Section','section','2.16.840.1.113883.10.20.7.12','Consolidated CDA implementation guide'),
('Operative Note Surgical Procedure Section','section','2.16.840.1.113883.10.20.7.14','Consolidated CDA implementation guide'),
('Payers Section','section','2.16.840.1.113883.10.20.22.2.18','Consolidated CDA implementation guide'),
('Physical Exam Section','section','2.16.840.1.113883.10.20.2.10','Consolidated CDA implementation guide'),
('Plan of Care Section','section','2.16.840.1.113883.10.20.22.2.10','Consolidated CDA implementation guide'),
('Planned Procedure Section','section','2.16.840.1.113883.10.20.22.2.30','Consolidated CDA implementation guide'),
('Postoperative Diagnosis Section','section','2.16.840.1.113883.10.20.22.2.35','Consolidated CDA implementation guide'),
('Postprocedure Diagnosis Section','section','2.16.840.1.113883.10.20.22.2.36','Consolidated CDA implementation guide'),
('Preoperative Diagnosis Section','section','2.16.840.1.113883.10.20.22.2.34','Consolidated CDA implementation guide'),
('Problem Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.5','Consolidated CDA implementation guide'),
('Problem Section (entries required)','section','2.16.840.1.113883.10.20.22.2.5.1','Consolidated CDA implementation guide'),
('Procedure Description Section','section','2.16.840.1.113883.10.20.22.2.27','Consolidated CDA implementation guide'),
('Procedure Disposition Section','section','2.16.840.1.113883.10.20.18.2.12','Consolidated CDA implementation guide'),
('Procedure Estimated Blood Loss Section','section','2.16.840.1.113883.10.20.18.2.9','Consolidated CDA implementation guide'),
('Procedure Findings Section','section','2.16.840.1.113883.10.20.22.2.28','Consolidated CDA implementation guide'),
('Procedure Implants Section','section','2.16.840.1.113883.10.20.22.2.40','Consolidated CDA implementation guide'),
('Procedure Indications Section','section','2.16.840.1.113883.10.20.22.2.29','Consolidated CDA implementation guide'),
('Procedure Specimens T aken Section','section','2.16.840.1.113883.10.20.22.2.31','Consolidated CDA implementation guide'),
('Procedures Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.7','Consolidated CDA implementation guide'),
('Procedures Section (entries required)','section','2.16.840.1.113883.10.20.22.2.7.1','Consolidated CDA implementation guide'),
('Reason for Referral Section','section','1.3.6.1.4.1.19376.1.5.3.1.3.1','Consolidated CDA implementation guide'),
('Reason for Visit Section','section','2.16.840.1.113883.10.20.22.2.12','Consolidated CDA implementation guide'),
('Results Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.3','Consolidated CDA implementation guide'),
('Results Section (entries required)','section','2.16.840.1.113883.10.20.22.2.3.1','Consolidated CDA implementation guide'),
('Review of Systems Section','section','1.3.6.1.4.1.19376.1.5.3.1.3.18','Consolidated CDA implementation guide'),
('Social History Section','section','2.16.840.1.113883.10.20.22.2.17','Consolidated CDA implementation guide'),
('Subjective Section','section','2.16.840.1.113883.10.20.21.2.2','Consolidated CDA implementation guide'),
('Surgery Description Section','section','2.16.840.1.113883.10.20.22.2.26','Consolidated CDA implementation guide'),
('Surgical Drains Section','section','2.16.840.1.113883.10.20.7.13','Consolidated CDA implementation guide'),
('Vital Signs Section (entries optional)','section','2.16.840.1.113883.10.20.22.2.4','Consolidated CDA implementation guide'),
('Vital Signs Section (entries required)','section','2.16.840.1.113883.10.20.22.2.4.1','Consolidated CDA implementation guide'),
('Admission Medication','entry','2.16.840.1.113883.10.20.22.4.36','Consolidated CDA implementation guide'),
('Advance Directive Observation','entry','2.16.840.1.113883.10.20.22.4.48','Consolidated CDA implementation guide'),
('Age Observation','entry','2.16.840.1.113883.10.20.22.4.31','Consolidated CDA implementation guide'),
('Allergy - Intolerance Observation','entry','2.16.840.1.113883.10.20.22.4.7','Consolidated CDA implementation guide'),
('Allergy Problem Act','entry','2.16.840.1.113883.10.20.22.4.30','Consolidated CDA implementation guide'),
('Allergy Status Observation','entry','2.16.840.1.113883.10.20.22.4.28','Consolidated CDA implementation guide'),
('Assessment Scale Observation','entry','2.16.840.1.113883.10.20.22.4.69','Consolidated CDA implementation guide'),
('Authorization Activity','entry','2.16.840.1.113883.10.20.1.19','Consolidated CDA implementation guide'),
('Boundary Observation','entry','2.16.840.1.113883.10.20.6.2.11','Consolidated CDA implementation guide'),
('Caregiver Characteristics','entry','2.16.840.1.113883.10.20.22.4.72','Consolidated CDA implementation guide'),
('Code Observations','entry','2.16.840.1.113883.10.20.6.2.13','Consolidated CDA implementation guide'),
('Cognitive Status Problem Observation','entry','2.16.840.1.113883.10.20.22.4.73','Consolidated CDA implementation guide'),
('Cognitive Status Result Observation','entry','2.16.840.1.113883.10.20.22.4.74','Consolidated CDA implementation guide'),
('Cognitive Status Result Organizer','entry','2.16.840.1.113883.10.20.22.4.75','Consolidated CDA implementation guide'),
('Comment Activity','entry','2.16.840.1.113883.10.20.22.4.64','Consolidated CDA implementation guide'),
('Coverage Activity','entry','2.16.840.1.113883.10.20.22.4.60','Consolidated CDA implementation guide'),
('Deceased Observation','entry','2.16.840.1.113883.10.20.22.4.79','Consolidated CDA implementation guide'),
('Discharge Medication','entry','2.16.840.1.113883.10.20.22.4.35','Consolidated CDA implementation guide'),
('Drug Vehicle','entry','2.16.840.1.113883.10.20.22.4.24','Consolidated CDA implementation guide'),
('Encounter Activities','entry','2.16.840.1.113883.10.20.22.4.49','Consolidated CDA implementation guide'),
('Encounter Diagnosis','entry','2.16.840.1.113883.10.20.22.4.80','Consolidated CDA implementation guide'),
('Estimated Date of Delivery','entry','2.16.840.1.113883.10.20.15.3.1','Consolidated CDA implementation guide'),
('Family History Death Observation','entry','2.16.840.1.113883.10.20.22.4.47','Consolidated CDA implementation guide'),
('Family History Observation','entry','2.16.840.1.113883.10.20.22.4.46','Consolidated CDA implementation guide'),
('Family History Organizer','entry','2.16.840.1.113883.10.20.22.4.45','Consolidated CDA implementation guide'),
('Functional Status Problem Observation','entry','2.16.840.1.113883.10.20.22.4.68','Consolidated CDA implementation guide'),
('Functional Status Result Observation','entry','2.16.840.1.113883.10.20.22.4.67','Consolidated CDA implementation guide'),
('Functional Status Result Organizer','entry','2.16.840.1.113883.10.20.22.4.66','Consolidated CDA implementation guide'),
('5.19 Observation','entry','2.16.840.1.113883.10.20.22.4.5','Consolidated CDA implementation guide'),
('Highest Pressure Ulcer Stage','entry','2.16.840.1.113883.10.20.22.4.77','Consolidated CDA implementation guide'),
('Hospital Admission Diagnosis','entry','2.16.840.1.113883.10.20.22.4.34','Consolidated CDA implementation guide'),
('Hospital Discharge Diagnosis','entry','2.16.840.1.113883.10.20.22.4.33','Consolidated CDA implementation guide'),
('Immunization Activity','entry','2.16.840.1.113883.10.20.22.4.52','Consolidated CDA implementation guide'),
('Immunization Medication Information','entry','2.16.840.1.113883.10.20.22.4.54','Consolidated CDA implementation guide'),
('Immunization Refusal Reason','entry','2.16.840.1.113883.10.20.22.4.53','Consolidated CDA implementation guide'),
('Indication','entry','2.16.840.1.113883.10.20.22.4.19','Consolidated CDA implementation guide'),
('Instructions','entry','2.16.840.1.113883.10.20.22.4.20','Consolidated CDA implementation guide'),
('Medication Activity','entry','2.16.840.1.113883.10.20.22.4.16','Consolidated CDA implementation guide'),
('Medication Dispense','entry','2.16.840.1.113883.10.20.22.4.18','Consolidated CDA implementation guide'),
('Medication Information','entry','2.16.840.1.113883.10.20.22.4.23','Consolidated CDA implementation guide'),
('Medication Supply Order','entry','2.16.840.1.113883.10.20.22.4.17','Consolidated CDA implementation guide'),
('Medication Use - None Known (deprecated)','entry','2.16.840.1.113883.10.20.22.4.29','Consolidated CDA implementation guide'),
('Non-Medicinal Supply Activity','entry','2.16.840.1.113883.10.20.22.4.50','Consolidated CDA implementation guide'),
('Number of Pressure Ulcers Observation','entry','2.16.840.1.113883.10.20.22.4.76','Consolidated CDA implementation guide'),
('Plan of Care Activity Act','entry','2.16.840.1.113883.10.20.22.4.39','Consolidated CDA implementation guide'),
('Plan of Care Activity Encounter','entry','2.16.840.1.113883.10.20.22.4.40','Consolidated CDA implementation guide'),
('Plan of Care Activity Observation','entry','2.16.840.1.113883.10.20.22.4.44','Consolidated CDA implementation guide'),
('Plan of Care Activity Procedure','entry','2.16.840.1.113883.10.20.22.4.41','Consolidated CDA implementation guide'),
('Plan of Care Activity Substance Administration','entry','2.16.840.1.113883.10.20.22.4.42','Consolidated CDA implementation guide'),
('Plan of Care Activity Supply','entry','2.16.840.1.113883.10.20.22.4.43','Consolidated CDA implementation guide'),
('Policy Activity','entry','2.16.840.1.113883.10.20.22.4.61','Consolidated CDA implementation guide'),
('Postprocedure Diagnosis','entry','2.16.840.1.113883.10.20.22.4.51','Consolidated CDA implementation guide'),
('Precondition for Substance Administration','entry','2.16.840.1.113883.10.20.22.4.25','Consolidated CDA implementation guide'),
('Pregnancy Observation','entry','2.16.840.1.113883.10.20.15.3.8','Consolidated CDA implementation guide'),
('Preoperative Diagnosis','entry','2.16.840.1.113883.10.20.22.4.65','Consolidated CDA implementation guide'),
('Pressure Ulcer Observation','entry','2.16.840.1.113883.10.20.22.4.70','Consolidated CDA implementation guide'),
('Problem Concern Act (Condition)','entry','2.16.840.1.113883.10.20.22.4.3','Consolidated CDA implementation guide'),
('Problem Observation','entry','2.16.840.1.113883.10.20.22.4.4','Consolidated CDA implementation guide'),
('Problem Status','entry','2.16.840.1.113883.10.20.22.4.6','Consolidated CDA implementation guide'),
('Procedure Activity Act','entry','2.16.840.1.113883.10.20.22.4.12','Consolidated CDA implementation guide'),
('Procedure Activity Observation','entry','2.16.840.1.113883.10.20.22.4.13','Consolidated CDA implementation guide'),
('Procedure Activity Procedure','entry','2.16.840.1.113883.10.20.22.4.14','Consolidated CDA implementation guide'),
('Procedure Context','entry','2.16.840.1.113883.10.20.6.2.5','Consolidated CDA implementation guide'),
('Product Instance','entry','2.16.840.1.113883.10.20.22.4.37','Consolidated CDA implementation guide'),
('Purpose of Reference Observation','entry','2.16.840.1.113883.10.20.6.2.9','Consolidated CDA implementation guide'),
('Quantity Measurement Observation','entry','2.16.840.1.113883.10.20.6.2.14','Consolidated CDA implementation guide'),
('Reaction Observation','entry','2.16.840.1.113883.10.20.22.4.9','Consolidated CDA implementation guide'),
('Referenced Frames Observation','entry','2.16.840.1.113883.10.20.6.2.10','Consolidated CDA implementation guide'),
('Result Observation','entry','2.16.840.1.113883.10.20.22.4.2','Consolidated CDA implementation guide'),
('Result Organizer','entry','2.16.840.1.113883.10.20.22.4.1','Consolidated CDA implementation guide'),
('Series Act','entry','2.16.840.1.113883.10.20.22.4.63','Consolidated CDA implementation guide'),
('Service Delivery Location','entry','2.16.840.1.113883.10.20.22.4.32','Consolidated CDA implementation guide'),
('Severity Observation','entry','2.16.840.1.113883.10.20.22.4.8','Consolidated CDA implementation guide'),
('Smoking Status Observation','entry','2.16.840.1.113883.10.22.4.78','Consolidated CDA implementation guide'),
('Social History Observation','entry','2.16.840.1.113883.10.20.22.4.38','Consolidated CDA implementation guide'),
('SOP Instance Observation','entry','2.16.840.1.113883.10.20.6.2.8','Consolidated CDA implementation guide'),
('Study Act','entry','2.16.840.1.113883.10.20.6.2.6','Consolidated CDA implementation guide'),
('Text Observation','entry','2.16.840.1.113883.10.20.6.2.12','Consolidated CDA implementation guide'),
('Tobacco Use','entry','2.16.840.1.113883.10.20.22.4.85','Consolidated CDA implementation guide'),
('Vital Sign Observation','entry','2.16.840.1.113883.10.20.22.4.27','Consolidated CDA implementation guide'),
('Vital Signs Organizer','entry','2.16.840.1.113883.10.20.22.4.26','Consolidated CDA implementation guide'),
('Physician of Record Participant','unspecified','2.16.840.1.113883.10.20.6.2.2','Consolidated CDA implementation guide'),
('Physician Reading Study Performer','unspecified','2.16.840.1.113883.10.20.6.2.1','Consolidated CDA implementation guide')
;

-- INSERT templates from wiki.siframework.org

INSERT INTO template(template_title, template_id, source) VALUES
('Admission Medications History Section','2.16.840.1.113883.3.88.11.83.113','Template Index S&I Framework'),
('Advance Directive','2.16.840.1.113883.3.88.11.83.12','Template Index S&I Framework'),
('Advance directive observation','2.16.840.1.113883.10.20.1.17','Template Index S&I Framework'),
('Advance directive reference','2.16.840.1.113883.10.20.1.36','Template Index S&I Framework'),
('Advance directive status observation','2.16.840.1.113883.10.20.1.37','Template Index S&I Framework'),
('Advance directives section','2.16.840.1.113883.10.20.1.1','Template Index S&I Framework'),
('Advance Directives Section','2.16.840.1.113883.3.88.11.83.116','Template Index S&I Framework'),
('Age observation','2.16.840.1.113883.10.20.1.38','Template Index S&I Framework'),
('Alert Observation','2.16.840.1.113883.10.20.1.18','Template Index S&I Framework'),
('Alert status observation','2.16.840.1.113883.10.20.1.39','Template Index S&I Framework'),
('Alerts section (used here for Allergies),','2.16.840.1.113883.10.20.1.2','Template Index S&I Framework'),
('Allergies and Other Adverse Reactions Section','2.16.840.1.113883.3.88.11.83.102','Template Index S&I Framework'),
('Allergy/Drug Sensitivity','2.16.840.1.113883.3.88.11.83.6','Template Index S&I Framework'),
('Anesthesia Section','2.16.840.1.113883.10.20.7.5','Template Index S&I Framework'),
('Assessment and Plan','2.16.840.1.113883.10.20.2.7','Template Index S&I Framework'),
('Assessment and Plan Section','2.16.840.1.113883.10.20.18.2.14','Template Index S&I Framework'),
('Assessment and Plan Section','2.16.840.1.113883.3.88.11.83.123','Template Index S&I Framework'),
('Assessment Section','2.16.840.1.113883.10.20.18.2.13','Template Index S&I Framework'),
('CCD v1.0 Templates Root','2.16.840.1.113883.10.20.1','Template Index S&I Framework'),
('CDA for common document types, general header constraints','2.16.840.1.113883.10.20.3','Template Index S&I Framework'),
('"CDA R2 Diagnostic Imaging, Report (DIR) Implementation Guide','2.16.840.1.113883.10.20.6','Template Index S&I Framework'),
('Chief Complaint Section','2.16.840.1.113883.10.20.18.2.16','Template Index S&I Framework'),
('Chief Complaint Section','2.16.840.1.113883.3.88.11.83.105','Template Index S&I Framework'),
('Comment','2.16.840.1.113883.10.20.1.40','Template Index S&I Framework'),
('Comment','2.16.840.1.113883.3.88.11.83.11','Template Index S&I Framework'),
('Complications Section','2.16.840.1.113883.10.20.18.2.4','Template Index S&I Framework'),
('Complications Section','2.16.840.1.113883.10.20.7.10','Template Index S&I Framework'),
('Condition','2.16.840.1.113883.3.88.11.83.7','Template Index S&I Framework'),
('Conforms to LevelĀ 1','2.16.840.1.113883.10.20.10','Template Index S&I Framework'),
('Conforms to LevelĀ 2','2.16.840.1.113883.10.20.20','Template Index S&I Framework'),
('Conforms to LevelĀ 3','2.16.840.1.113883.10.20.30','Template Index S&I Framework'),
('Consultation Note v1.0 Templates Root','2.16.840.1.113883.10.20.4 ','Template Index S&I Framework'),
('Coverage activity','2.16.840.1.113883.10.20.1.20','Template Index S&I Framework'),
('Description of Surgery','2.16.840.1.113883.10.20.7.3','Template Index S&I Framework'),
('Diagnostic Results Section','2.16.840.1.113883.3.88.11.83.122','Template Index S&I Framework'),
('DIR Level 3 Content Template IDs','2.16.840.1.113883.10.20.6.2','Template Index S&I Framework'),
('DIR Section Template IDs','2.16.840.1.113883.10.20.6.1','Template Index S&I Framework'),
('Discharge Diagnosis Section','2.16.840.1.113883.3.88.11.83.111','Template Index S&I Framework'),
('Discharge Summary header constraints','2.16.840.1.113883.10.20.16.2','Template Index S&I Framework'),
('Disposition Section','2.16.840.1.113883.10.20.7.11','Template Index S&I Framework'),
('Encounter','2.16.840.1.113883.3.88.11.83.16','Template Index S&I Framework'),
('Encounter activity','2.16.840.1.113883.10.20.1.21','Template Index S&I Framework'),
('Encounters section','2.16.840.1.113883.10.20.1.3','Template Index S&I Framework'),
('Encounters Section','2.16.840.1.113883.3.88.11.83.127','Template Index S&I Framework'),
('Episode observation','2.16.840.1.113883.10.20.1.41','Template Index S&I Framework'),
('Estimated Blood Loss Entry','2.16.840.1.113883.10.20.18.3.1','Template Index S&I Framework'),
('Estimated Blood Loss Section','2.16.840.1.113883.10.20.7.6','Template Index S&I Framework'),
('Family History','2.16.840.1.113883.3.88.11.83.18','Template Index S&I Framework'),
('Family history cause of death observation','2.16.840.1.113883.10.20.1.42','Template Index S&I Framework'),
('Family history observation','2.16.840.1.113883.10.20.1.22','Template Index S&I Framework'),
('Family history organizer','2.16.840.1.113883.10.20.1.23','Template Index S&I Framework'),
('Family History section','2.16.840.1.113883.10.20.1.4','Template Index S&I Framework'),
('Family History Section','2.16.840.1.113883.10.20.18.2.17','Template Index S&I Framework'),
('Family History Section','2.16.840.1.113883.3.88.11.83.125','Template Index S&I Framework'),
('Findings Section','2.16.840.1.113883.10.20.18.2.15','Template Index S&I Framework'),
('Fulfillment instruction','2.16.840.1.113883.10.20.1.43','Template Index S&I Framework'),
('Functional Status','2.16.840.1.113883.3.88.11.83.21','Template Index S&I Framework'),
('Functional Status section','2.16.840.1.113883.10.20.1.5','Template Index S&I Framework'),
('Functional Status Section','2.16.840.1.113883.3.88.11.83.109','Template Index S&I Framework'),
('H&P v1.0 Templates Root','2.16.840.1.113883.10.20.2','Template Index S&I Framework'),
('header constraints specific to a Progress Note','2.16.840.1.113883.10.20.21.1','Template Index S&I Framework'),
('Healthcare Provider','2.16.840.1.113883.3.88.11.83.4','Template Index S&I Framework'),
('History of Past Illness Section','2.16.840.1.113883.3.88.11.83.104','Template Index S&I Framework'),
('History of Present Illness Section','2.16.840.1.113883.3.88.11.83.107','Template Index S&I Framework'),
('HITSP/C32 - Summary Documents Using HL7 Continuity of Care Document (CCD)','2.16.840.1.113883.3.88.11.32.1','Template Index S&I Framework'),
('HL7 History and Physical Root','2.16.840.1.113883.10.20.4','Template Index S&I Framework'),
('HL7 Registered Templates Root','2.16.840.1.113883.10','Template Index S&I Framework'),
('HL7 SDTC Registered Templates Root','2.16.840.1.113883.10.20','Template Index S&I Framework'),
('Hospital Admission Diagnosis Section','2.16.840.1.113883.3.88.11.83.110','Template Index S&I Framework'),
('Hospital Course Section','2.16.840.1.113883.3.88.11.83.121','Template Index S&I Framework'),
('Hospital Discharge Diagnosis section','1.3.6.1.4.1.19376.1.5.3.1.3.7','Template Index S&I Framework'),
('Hospital Discharge Medications section','1.3.6.1.4.1.19376.1.5.3.1.3.22','Template Index S&I Framework'),
('Hospital Discharge Medications Section','2.16.840.1.113883.3.88.11.83.114','Template Index S&I Framework'),
('Hospital Discharge Studies Summary','2.16.840.1.113883.10.20.16.2.3','Template Index S&I Framework'),
('IHE Patient Care Coordination Template Identifier Root','1.3.6.1.4.1.19376.1.5.3.1','Template Index S&I Framework'),
('Imaging Observation','2.16.840.1.113883.10.20.15.3.5','Template Index S&I Framework'),
('Immunization','2.16.840.1.113883.3.88.11.83.13','Template Index S&I Framework'),
('Immunizations section','2.16.840.1.113883.10.20.1.6','Template Index S&I Framework'),
('Immunizations Section','2.16.840.1.113883.3.88.11.83.117','Template Index S&I Framework'),
('Implants Section','2.16.840.1.113883.10.20.7.15','Template Index S&I Framework'),
('Indicates conformance to this Unstructured Documents DSTU','UNSTRUCTURED-DOCUMENTS-OID','Template Index S&I Framework'),
('Indications ','2.16.840.1.113883.3.88.11.83.138','Template Index S&I Framework'),
('Indications Section','2.16.840.1.113883.10.20.7.9','Template Index S&I Framework'),
('Insurance Provider','2.16.840.1.113883.3.88.11.83.5','Template Index S&I Framework'),
('Language Spoken','2.16.840.1.113883.3.88.11.83.2','Template Index S&I Framework'),
('List of Surgeries Section','2.16.840.1.113883.3.88.11.83.108','Template Index S&I Framework'),
('Location participation','2.16.840.1.113883.10.20.1.45','Template Index S&I Framework'),
('Medical Equipment','2.16.840.1.113883.3.88.11.83.20','Template Index S&I Framework'),
('Medical equipment section','2.16.840.1.113883.10.20.1.7','Template Index S&I Framework'),
('Medical Equipment Section','2.16.840.1.113883.3.88.11.83.128','Template Index S&I Framework'),
('Medical History Section','2.16.840.1.113883.10.20.18.2.5','Template Index S&I Framework'),
('Medication','2.16.840.1.113883.3.88.11.83.8','Template Index S&I Framework'),
('Medication Activities ','2.16.840.1.113883.10.20.1.24','Template Index S&I Framework'),
('Medication Entry','1.3.6.1.4.1.19376.1.5.3.1.4.7','Template Index S&I Framework'),
('Medication History Section','2.16.840.1.113883.10.20.1.8','Template Index S&I Framework'),
('Medication Information Constraints','2.16.840.1.113883.3.88.11.83.8.2','Template Index S&I Framework'),
('Medication series number observation','2.16.840.1.113883.10.20.1.46','Template Index S&I Framework'),
('Medication status observation','2.16.840.1.113883.10.20.1.47','Template Index S&I Framework'),
('Medications Administered Section','2.16.840.1.113883.10.20.18.2.8','Template Index S&I Framework'),
('Medications Administered Section','2.16.840.1.113883.3.88.11.83.115','Template Index S&I Framework'),
('Medications Section','2.16.840.1.113883.3.88.11.83.112','Template Index S&I Framework'),
('Operative Note Clinical Document','2.16.840.1.113883.10.20.7','Template Index S&I Framework'),
('Operative Note Findings Section','2.16.840.1.113883.10.20.7.4','Template Index S&I Framework'),
('Order Information Constraints','2.16.840.1.113883.3.88.11.83.8.3','Template Index S&I Framework'),
('Past Medical History','2.16.840.1.113883.10.20.2.9','Template Index S&I Framework'),
('Past Medical History','2.16.840.1.113883.10.20.4.9','Template Index S&I Framework'),
('Patient awareness','2.16.840.1.113883.10.20.1.48','Template Index S&I Framework'),
('Patient instruction','2.16.840.1.113883.10.20.1.49','Template Index S&I Framework'),
('Payers section','2.16.840.1.113883.10.20.1.9','Template Index S&I Framework'),
('Payers Section','2.16.840.1.113883.3.88.11.83.101','Template Index S&I Framework'),
('Personal Information','2.16.840.1.113883.3.88.11.83.1','Template Index S&I Framework'),
('Physical Exam by Organ System','2.16.840.1.113883.10.20.2.6','Template Index S&I Framework'),
('Physical Examination Section','2.16.840.1.113883.3.88.11.83.118','Template Index S&I Framework'),
('Plan Of Care','2.16.840.1.113883.3.88.11.83.22','Template Index S&I Framework'),
('Plan of Care Activities','2.16.840.1.113883.10.20.1.25','Template Index S&I Framework'),
('Plan of Care Section','2.16.840.1.113883.3.88.11.83.124','Template Index S&I Framework'),
('Plan Section','2.16.840.1.113883.10.20.1.10','Template Index S&I Framework'),
('Planned Procedure ','2.16.840.1.113883.3.88.11.83.137','Template Index S&I Framework'),
('Planned Procedure Section','2.16.840.1.113883.10.20.18.2.6','Template Index S&I Framework'),
('Planned Procedure Section','2.16.840.1.113883.10.20.7.8','Template Index S&I Framework'),
('Policy activity','2.16.840.1.113883.10.20.1.26','Template Index S&I Framework'),
('Post Operative Diagnosis Section','2.16.840.1.113883.10.20.7.2','Template Index S&I Framework'),
('Post procedure Diagnosis Section','2.16.840.1.113883.10.20.18.2.3','Template Index S&I Framework'),
('Postoperative Diagnosis ','2.16.840.1.113883.3.88.11.83.130','Template Index S&I Framework'),
('Preoperative Diagnosis ','2.16.840.1.113883.3.88.11.83.129','Template Index S&I Framework'),
('Preoperative Diagnosis Section','2.16.840.1.113883.10.20.7.1','Template Index S&I Framework'),
('Problem Act','2.16.840.1.113883.10.20.1.27','Template Index S&I Framework'),
('Problem Concern Entry','1.3.6.1.4.1.19376.1.5.3.1.4.5.2','Template Index S&I Framework'),
('Problem Healthstatus Observation','2.16.840.1.113883.10.20.1.51','Template Index S&I Framework'),
('Problem List Section','2.16.840.1.113883.3.88.11.83.103','Template Index S&I Framework'),
('Problem Observation','2.16.840.1.113883.10.20.1.28','Template Index S&I Framework'),
('Problem Status Observation','2.16.840.1.113883.10.20.1.50','Template Index S&I Framework'),
('Problems section','2.16.840.1.113883.10.20.1.11','Template Index S&I Framework'),
('Procedure','2.16.840.1.113883.3.88.11.83.17','Template Index S&I Framework'),
('Procedure Activities','2.16.840.1.113883.10.20.1.29','Template Index S&I Framework'),
('Procedure Anesthesia Section','2.16.840.1.113883.10.20.18.2.7','Template Index S&I Framework'),
('Procedure Description Section','2.16.840.1.113883.10.20.18.2.2','Template Index S&I Framework'),
('Procedure History Section','2.16.840.1.113883.10.20.18.2.18','Template Index S&I Framework'),
('Procedure Implants Section','2.16.840.1.113883.10.20.18.2.11','Template Index S&I Framework'),
('Procedure Indications Section','2.16.840.1.113883.10.20.18.2.1','Template Index S&I Framework'),
('Procedure Note Clinical Document','2.16.840.1.113883.10.20.18.1','Template Index S&I Framework'),
('Procedure Specimens Taken Section','2.16.840.1.113883.10.20.18.2.10','Template Index S&I Framework'),
('Procedures section','2.16.840.1.113883.10.20.1.12','Template Index S&I Framework'),
('Product','2.16.840.1.113883.10.20.1.53','Template Index S&I Framework'),
('Product Instance','2.16.840.1.113883.10.20.1.52','Template Index S&I Framework'),
('Purpose activity','2.16.840.1.113883.10.20.1.30','Template Index S&I Framework'),
('Purpose section','2.16.840.1.113883.10.20.1.13','Template Index S&I Framework'),
('Reaction observation','2.16.840.1.113883.10.20.1.54','Template Index S&I Framework'),
('Reason for Referral Section','2.16.840.1.113883.3.88.11.83.106','Template Index S&I Framework'),
('Reason for Referral/Visit','2.16.840.1.113883.10.20.4.8','Template Index S&I Framework'),
('Reason for Visit / Chief Complaint','2.16.840.1.113883.10.20.2.8','Template Index S&I Framework'),
('Reserved for Anesthesia ','2.16.840.1.113883.3.88.11.83.133','Template Index S&I Framework'),
('Reserved for Assessments','2.16.840.1.113883.3.88.11.83.144','Template Index S&I Framework'),
('Reserved for Complications ','2.16.840.1.113883.3.88.11.83.136','Template Index S&I Framework'),
('Reserved for Disposition ','2.16.840.1.113883.3.88.11.83.139','Template Index S&I Framework'),
('Reserved for Estimated Blood Loss ','2.16.840.1.113883.3.88.11.83.134','Template Index S&I Framework'),
('Reserved for HITSP/C105 Patient Level Quality Data ','2.16.840.1.113883.3.88.11.105.1','Template Index S&I Framework'),
('Reserved for HITSP/C148 EMS Transfers of Care','2.16.840.1.113883.3.88.11.148.1','Template Index S&I Framework'),
('Reserved for HITSP/C152 Labor and Delivery Record','2.16.840.1.113883.3.88.11.152.1','Template Index S&I Framework'),
('Reserved for HITSP/C161 Antepartum Record','2.16.840.1.113883.3.88.11.161.1','Template Index S&I Framework'),
('Reserved for HITSP/C161 Antepartum Record','2.16.840.1.113883.3.88.11.161.2','Template Index S&I Framework'),
('Reserved for HITSP/C161 Antepartum Record','2.16.840.1.113883.3.88.11.161.3','Template Index S&I Framework'),
('Reserved for HITSP/C161 Antepartum Record','2.16.840.1.113883.3.88.11.161.4','Template Index S&I Framework'),
('Reserved for HITSP/C161 Antepartum Record','2.16.840.1.113883.3.88.11.161.5','Template Index S&I Framework'),
('Reserved for HITSP/C162 Plan of Care','2.16.840.1.113883.3.88.11.162.1','Template Index S&I Framework'),
('Reserved for HITSP/C166 Operative Note Document','2.16.840.1.113883.3.88.11.166.1','Template Index S&I Framework'),
('Reserved for HITSP/C168 Long Term and Post Acute Care Assessments','2.16.840.1.113883.3.88.11.168.1','Template Index S&I Framework'),
('Reserved for HITSP/C168 Long Term and Post Acute Care Assessments','2.16.840.1.113883.3.88.11.168.2','Template Index S&I Framework'),
('Reserved for HITSP/C28 Emergency Care Summary Document','2.16.840.1.113883.3.88.11.28.1','Template Index S&I Framework'),
('Reserved for HITSP/C28 Emergency Care Summary Document','2.16.840.1.113883.3.88.11.28.2','Template Index S&I Framework'),
('Reserved for HITSP/C28 Emergency Care Summary Document','2.16.840.1.113883.3.88.11.28.3','Template Index S&I Framework'),
('Reserved for HITSP/C28 Emergency Care Summary Document','2.16.840.1.113883.3.88.11.28.4','Template Index S&I Framework'),
('Reserved for HITSP/C37 Lab Report Document','2.16.840.1.113883.3.88.11.37','Template Index S&I Framework'),
('Reserved for HITSP/C48 Encounter Document Using IHE Medical Summary (XDS-MS)','2.16.840.1.113883.3.88.11.48.1','Template Index S&I Framework'),
('Reserved for HITSP/C48 Encounter Document Using IHE Medical Summary (XDS-MS)','2.16.840.1.113883.3.88.11.48.2','Template Index S&I Framework'),
('Reserved for HITSP/C62 Unstructured Document Plan of Care','2.16.840.1.113883.3.88.11.62.1','Template Index S&I Framework'),
('Reserved for HITSP/C78 Immunization Document','2.16.840.1.113883.3.88.11.78','Template Index S&I Framework'),
('Reserved for HITSP/C84 Consult and History & Physical Note','2.16.840.1.113883.3.88.11.84.1','Template Index S&I Framework'),
('Reserved for HITSP/C84 Consult and History & Physical Note','2.16.840.1.113883.3.88.11.84.2','Template Index S&I Framework'),
('Reserved for Implants','2.16.840.1.113883.3.88.11.83.143','Template Index S&I Framework'),
('Reserved for Operative Note Fluids ','2.16.840.1.113883.3.88.11.83.140','Template Index S&I Framework'),
('Reserved for Operative Note Surgical Procedure ','2.16.840.1.113883.3.88.11.83.141','Template Index S&I Framework'),
('Reserved for Procedures and Interventions','2.16.840.1.113883.3.88.11.83.145','Template Index S&I Framework'),
('Reserved for Provider Orders','2.16.840.1.113883.3.88.11.83.146','Template Index S&I Framework'),
('Reserved for Questionnaire Assessment ','2.16.840.1.113883.3.88.11.83.147','Template Index S&I Framework'),
('Reserved for Specimens Removed ','2.16.840.1.113883.3.88.11.83.135','Template Index S&I Framework'),
('Reserved for Surgery Description ','2.16.840.1.113883.3.88.11.83.131','Template Index S&I Framework'),
('Reserved for Surgical Drains','2.16.840.1.113883.3.88.11.83.142','Template Index S&I Framework'),
('Result','2.16.840.1.113883.3.88.11.83.15','Template Index S&I Framework'),
('Result organizer','2.16.840.1.113883.10.20.1.32','Template Index S&I Framework'),
('Results Observation','2.16.840.1.113883.10.20.1.31','Template Index S&I Framework'),
('Results section','2.16.840.1.113883.10.20.1.14','Template Index S&I Framework'),
('Review of Systems','2.16.840.1.113883.10.20.4.10','Template Index S&I Framework'),
('Review of Systems Section','2.16.840.1.113883.3.88.11.83.120','Template Index S&I Framework'),
('Service Event in Header','2.16.840.1.113883.10.20.21.3.1','Template Index S&I Framework'),
('Severity observation','2.16.840.1.113883.10.20.1.55','Template Index S&I Framework'),
('Social History','2.16.840.1.113883.3.88.11.83.19','Template Index S&I Framework'),
('Social History Observation','2.16.840.1.113883.10.20.1.33','Template Index S&I Framework'),
('Social History section','2.16.840.1.113883.10.20.1.15','Template Index S&I Framework'),
('Social History Section','2.16.840.1.113883.3.88.11.83.126','Template Index S&I Framework'),
('Social history status observation','2.16.840.1.113883.10.20.1.56','Template Index S&I Framework'),
('Specimens Removed Section','2.16.840.1.113883.10.20.7.7','Template Index S&I Framework'),
('Status observation','2.16.840.1.113883.10.20.1.57','Template Index S&I Framework'),
('Status of functional status observation','2.16.840.1.113883.10.20.1.44','Template Index S&I Framework'),
('Supply Activities','2.16.840.1.113883.10.20.1.34','Template Index S&I Framework'),
('Support','2.16.840.1.113883.3.88.11.83.3','Template Index S&I Framework'),
('Surgical Operation Note Findings ','2.16.840.1.113883.3.88.11.83.132','Template Index S&I Framework'),
('Type of Medication Constraints','2.16.840.1.113883.3.88.11.83.8.1','Template Index S&I Framework'),
('Verification of an advance directive observation','2.16.840.1.113883.10.20.1.58','Template Index S&I Framework'),
('Vital Sign','2.16.840.1.113883.3.88.11.83.14','Template Index S&I Framework'),
('Vital Signs','2.16.840.1.113883.10.20.2.4','Template Index S&I Framework'),
('Vital signs organizer','2.16.840.1.113883.10.20.1.35','Template Index S&I Framework'),
('Vital Signs Section','2.16.840.1.113883.10.20.1.16','Template Index S&I Framework'),
('Vital Signs Section','2.16.840.1.113883.3.88.11.83.119','Template Index S&I Framework')
;

INSERT INTO template(template_title, template_id, source) VALUES
('Allergy Intolerance','1.3.6.1.4.1.19376.1.5.3.1.4.6','IHE wiki'),
('Allergy Intolerance Concern','1.3.6.1.4.1.19376.1.5.3.1.4.5.3','IHE wiki'),
('Combination Medication','1.3.6.1.4.1.19376.1.5.3.1.4.11','IHE wiki'),
('Comment','1.3.6.1.4.1.19376.1.5.3.1.4.2','IHE wiki'),
('Concern Entry','1.3.6.1.4.1.19376.1.5.3.1.4.5.1','IHE wiki'),
('Conditional Dose','1.3.6.1.4.1.19376.1.5.3.1.4.10','IHE wiki'),
('Coverage Entry','1.3.6.1.4.1.19376.1.5.3.1.4.17','IHE wiki'),
('Encounter Entry','1.3.6.1.4.1.19376.1.5.3.1.4.14','IHE wiki'),
('External Reference','1.3.6.1.4.1.19376.1.5.3.1.4.4','IHE wiki'),
('Family History Observation','1.3.6.1.4.1.19376.1.5.3.1.4.13.3','IHE wiki'),
('Family History Organizer','1.3.6.1.4.1.19376.1.5.3.1.4.15','IHE wiki'),
('Health Status Observation','1.3.6.1.4.1.19376.1.5.3.1.4.1.2','IHE wiki'),
('Immunization','1.3.6.1.4.1.19376.1.5.3.1.4.12','IHE wiki'),
('Internal Reference','1.3.6.1.4.1.19376.1.5.3.1.4.4.1','IHE wiki'),
('Medication Fullfillment Instructions','1.3.6.1.4.1.19376.1.5.3.1.4.3.1','IHE wiki'),
('Normal Dose','1.3.6.1.4.1.19376.1.5.3.1.4.7.1','IHE wiki'),
('Observation Request Entry','1.3.6.1.4.1.19376.1.5.3.1.1.20.3.1','IHE wiki'),
('Patient Medical Instructions','1.3.6.1.4.1.19376.1.5.3.1.4.3','IHE wiki'),
('Payer Entry','1.3.6.1.4.1.19376.1.5.3.1.4.18','IHE wiki'),
('Pregnancy Observation','1.3.6.1.4.1.19376.1.5.3.1.4.13.5','IHE wiki'),
('Problem Entry','1.3.6.1.4.1.19376.1.5.3.1.4.5','IHE wiki'),
('Problem Status Observation','1.3.6.1.4.1.19376.1.5.3.1.4.1.1','IHE wiki'),
('Procedure Entry','1.3.6.1.4.1.19376.1.5.3.1.4.19','IHE wiki'),
('Severity','1.3.6.1.4.1.19376.1.5.3.1.4.1','IHE wiki'),
('Simple Observation','1.3.6.1.4.1.19376.1.5.3.1.4.13','IHE wiki'),
('Social History Observation','1.3.6.1.4.1.19376.1.5.3.1.4.13.4','IHE wiki'),
('Split Dose','1.3.6.1.4.1.19376.1.5.3.1.4.9','IHE wiki'),
('Supply Entry','1.3.6.1.4.1.19376.1.5.3.1.4.7.3','IHE wiki'),
('Tapered Dose','1.3.6.1.4.1.19376.1.5.3.1.4.8','IHE wiki'),
('Vital Sign Observation','1.3.6.1.4.1.19376.1.5.3.1.4.13.2','IHE wiki'),
('Vital Signs Organizer','1.3.6.1.4.1.19376.1.5.3.1.4.13.1','IHE wiki')
;