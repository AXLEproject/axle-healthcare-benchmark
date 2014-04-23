/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 */

CREATE EXTENSION IF NOT EXISTS intarray;
/*
 * Patient records:
 * id      contents          weight
 * -------------------------------------
 * {1,2,5} player,scoper           3201
 * {1}     name                    1101
 * {5}     only reference          1001
 *
 * {6}     only reference          1001
 *
 * {4,3,7} name, player, scoper    3301
 * {4,3,7} only reference          1001
 * {3}     name                    1101
 * {4}     only reference          1001
 *
 * {8}     player,scoper
 * {8,9}   only reference

 _id | _id_cluster | id1 | id2 | id3 | _record_hash                     | _record_weight
-----+-------------+-----+-----+-----+----------------------------------+----------------
  13 |             | 1   | 2   | 5   | dacc2492c46554f400f1e9b49252087a |           3201
  33 |             | 1   |     |     | b2a86c24da849c0bd009b63c02f31ec7 |           1101
  53 |             | 5   |     |     | dacc2492c46554f400f1e9b49252087a |           1001
  73 |             | 6   |     |     | dacc2492c46554f400f1e9b49252087a |           1001
  78 |             | 4   | 3   | 7   | b2a86c24da849c0bd009b63c02f31ec7 |           3301
  81 |             | 4   | 3   | 7   | dacc2492c46554f400f1e9b49252087a |           1001
 101 |             | 3   |     |     | b2a86c24da849c0bd009b63c02f31ec7 |           1101
 121 |             | 3   |     |     | dacc2492c46554f400f1e9b49252087a |           1001
(8 rows)

- initial clustering: using @> operator.
  \forall Y : Y.@>id = { X._id | \forall X : X.id @> Y.id \and X.id <> Y.id}

 a1 | a2 | a3 | b1 | b2 | b3 | set__id_a | set__id_b
----+----+----+----+----+----+-----------+-----------
 1  | 2  | 5  | 1  |    |    | {13}      | {33}
 1  | 2  | 5  | 5  |    |    | {13}      | {53}
 4  | 3  | 7  | 4  |    |    | {78,81}   | {87}
 4  | 3  | 7  | 3  |    |    | {78,81}   | {84}

- match new patients on set__id_a or set__id_b. Note that 73 is the only record that will not be clustered with other records.

 _id | n1 | n2 | n3 |           _record_hash           | _record_weight | c1a1 | c1a2 | c1a3 | c1b1 | c1b2 | c1b3 | c1_set__id_a | c1_set__id_a | c2a1 | c2a2 | c2a3 | c2b1 | c2b2 | c2b3 | c2_set__id_a | c2_set__id_b 
-----+----+----+----+----------------------------------+----------------+------+------+------+------+------+------+--------------+--------------+------+------+------+------+------+------+--------------+--------------
  13 | 1  | 2  | 5  | dacc2492c46554f400f1e9b49252087a |           3201 |      |      |      |      |      |      |              |              | 1    | 2    | 5    | 1    |      |      | {13}         | {33}
  13 | 1  | 2  | 5  | dacc2492c46554f400f1e9b49252087a |           3201 |      |      |      |      |      |      |              |              | 1    | 2    | 5    | 5    |      |      | {13}         | {53}
  33 | 1  |    |    | b2a86c24da849c0bd009b63c02f31ec7 |           1101 | 1    | 2    | 5    | 1    |      |      | {13}         | {33}         |      |      |      |      |      |      |              | 
  53 | 5  |    |    | dacc2492c46554f400f1e9b49252087a |           1001 | 1    | 2    | 5    | 5    |      |      | {13}         | {53}         |      |      |      |      |      |      |              | 
  73 | 6  |    |    | dacc2492c46554f400f1e9b49252087a |           1001 |      |      |      |      |      |      |              |              |      |      |      |      |      |      |              | 
  78 | 4  | 3  | 7  | b2a86c24da849c0bd009b63c02f31ec7 |           3301 |      |      |      |      |      |      |              |              | 4    | 3    | 7    | 3    |      |      | {78,81}      | {84}
  78 | 4  | 3  | 7  | b2a86c24da849c0bd009b63c02f31ec7 |           3301 |      |      |      |      |      |      |              |              | 4    | 3    | 7    | 4    |      |      | {78,81}      | {87}
  81 | 4  | 3  | 7  | dacc2492c46554f400f1e9b49252087a |           1001 |      |      |      |      |      |      |              |              | 4    | 3    | 7    | 4    |      |      | {78,81}      | {87}
  81 | 4  | 3  | 7  | dacc2492c46554f400f1e9b49252087a |           1001 |      |      |      |      |      |      |              |              | 4    | 3    | 7    | 3    |      |      | {78,81}      | {84}
  84 | 3  |    |    | b2a86c24da849c0bd009b63c02f31ec7 |           1101 | 4    | 3    | 7    | 3    |      |      | {78,81}      | {84}         |      |      |      |      |      |      |              | 
  87 | 4  |    |    | dacc2492c46554f400f1e9b49252087a |           1001 | 4    | 3    | 7    | 4    |      |      | {78,81}      | {87}         |      |      |      |      |      |      |              | 


- choose cluster 'masters' for _id_cluster column:
  - most recent, weight with weight > 1001,
  - or records without @> id get their own id as clusterid






 _id | _id_cluster | id1 | id2 | id3 | _record_hash                     | _record_weight  @>id
-----+-------------+-----+-----+-----+----------------------------------+----------------
  13 |          13 | 1   | 2   | 5   | dacc2492c46554f400f1e9b49252087a |           3201  13
  33 |          13 | 1   |     |     | b2a86c24da849c0bd009b63c02f31ec7 |           1101  33,13
  53 |          13 | 5   |     |     | dacc2492c46554f400f1e9b49252087a |           1001  53,13
  73 |          73 | 6   |     |     | dacc2492c46554f400f1e9b49252087a |           1001  73
  78 |          78 | 4   | 3   | 7   | b2a86c24da849c0bd009b63c02f31ec7 |           3301  78,81
  81 |          78 | 4   | 3   | 7   | dacc2492c46554f400f1e9b49252087a |           1001  78,81
 101 |          78 | 3   |     |     | b2a86c24da849c0bd009b63c02f31ec7 |           1101  78,81
 121 |          78 | 3   |     |     | dacc2492c46554f400f1e9b49252087a |           1001  78,81

- de-duplicate:
  - remove records with weight 1001 and clusterid <> _id. update fk's with clusterid        FK's to
  53 |          13 | 5   |     |     | dacc2492c46554f400f1e9b49252087a |           1001       13
  81 |          78 | 4   | 3   | 7   | dacc2492c46554f400f1e9b49252087a |           1001       78
 121 |          78 | 3   |     |     | dacc2492c46554f400f1e9b49252087a |           1001       78
  - remove within cluster records with same hash as another record in the cluster.
    choose as remaining record the one with the most weight.
 101 |          78 | 3   |     |     | b2a86c24da849c0bd009b63c02f31ec7 |           1101       78

REMAINING Patient Records: 4 with 3 clusters:

 _id | _id_cluster | id1 | id2 | id3 | _record_hash                     | _record_weight
-----+-------------+-----+-----+-----+----------------------------------+----------------
  13 |          13 | 1   | 2   | 5   | dacc2492c46554f400f1e9b49252087a |           3201
  33 |          13 | 1   |     |     | b2a86c24da849c0bd009b63c02f31ec7 |           1101

  73 |          73 | 6   |     |     | dacc2492c46554f400f1e9b49252087a |           1001

  78 |          78 | 4   | 3   | 7   | b2a86c24da849c0bd009b63c02f31ec7 |           3301

 */

\timing

BEGIN;

SELECT pond_setseq(10,1000);

/* Patient {1,2,5} with weight 3201 */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');
person1 := Person_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Person', "addr" := adinval("city" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Qbghexeoe'), "postalCode" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := '6684AW'), "streetAddressLine" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Pdkkxziujjtoy 971'), "useablePeriod" := sxcm_tsinval("operator" := 'I', "value" := '20081117110022')), "administrativeGenderCode" := ceinval("code" := 'M', "codeSystem" := '2.16.840.1.113883.5.1', "codeSystemName" := 'HL7 AdministrativeGender', "displayName" := 'Male'), "birthTime" := tsinval("value" := '19641121110022'), "classCode" := 'PSN', "deceasedInd" := blinval("value" := False), "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '1', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '2', "root" := '2.16.840.1.113883.2.4.3.31.3.2') || iiinval("extension" := '5', "root" := '2.16.840.1.113883.2.4.6.3'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Botpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
organization2 := Organization_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Organization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '1', "root" := '2.16.840.1.113883.2.4.3.31.3.2'));
patient3 := Patient_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '1', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '2', "root" := '2.16.840.1.113883.2.4.3.31.3.2') || iiinval("extension" := '5', "root" := '2.16.840.1.113883.2.4.6.3'), "player" := person1, "scoper" := organization2);
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

/* Patient {1} with name. */

DO
$$DECLARE
document0 bigint;
role1 bigint;
participation2 bigint;
role3 bigint;
participation4 bigint;
organization5 bigint;
role6 bigint;
participation7 bigint;
act8 bigint;
act9 bigint;
observation10 bigint;
role11 bigint;
participation12 bigint;
actrelationship13 bigint;
actrelationship14 bigint;
actrelationship15 bigint;
role16 bigint;
participation17 bigint;
patient18 bigint;
participation19 bigint;
BEGIN
document0 := Document_insert(_mif := 'POCD_MT000040', _clonename := 'ClinicalDocument', "classCode" := 'DOCCLIN', "code" := ceinval("code" := '34133-9', "codeSystem" := '2.16.840.1.113883.6.1', "codeSystemName" := 'LOINC', "displayName" := 'Summary of Episode Note'), "confidentialityCode" := ceinval("code" := 'N', "codeSystem" := '2.16.840.1.113883.5.25', "codeSystemName" := 'Confidentiality', "displayName" := 'Normal'), "effectiveTime" := tsinval("value" := '20140419110023'), "id" := iiinval("extension" := '5e9c3622-f2d3-4f26-8969-762d2333013a', "root" := '2.16.840.1.113883.2.4.3.31.3.1'), "moodCode" := 'EVN', "title" := stinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Examination by Portavita'), "typeId" := iiinval("extension" := 'POCD_HD000040', "root" := '2.16.840.1.113883.1.3'));
role1 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedAuthor', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation2 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Author', "act" := document0, "contextControlCode" := 'OP', "role" := role1, "time" := tsinval("value" := '20150506034148'), "typeCode" := 'AUT');
role3 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'DataEnterer', "act" := document0, "contextControlCode" := 'OP', "role" := role3, "time" := tsinval("value" := '20150506034148'), "typeCode" := 'ENT');
organization5 := Organization_insert(_mif := 'POCD_MT000040', _clonename := 'CustodianOrganization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '0', "root" := '2.16.840.1.113883.2.4.3.31.3.2'), "name" := oninval("content" := 'Portavita B.V.'));
role6 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedCustodian', "classCode" := 'ASSIGNED', "scoper" := organization5);
participation7 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Custodian', "act" := document0, "role" := role6, "typeCode" := 'CST');
act8 := Act_insert(_mif := 'POCD_MT000040', _clonename := 'StructuredBody', "classCode" := 'DOCBODY', "moodCode" := 'EVN');
act9 := Act_insert(_mif := 'POCD_MT000040', _clonename := 'Section', "classCode" := 'DOCSECT', "moodCode" := 'EVN');
observation10 := Observation_insert(_mif := 'POCD_MT000040', _clonename := 'Observation', "classCode" := 'OBS', "code" := cdinval("code" := '396552003', "codeSystem" := '2.16.840.1.113883.6.96', "codeSystemName" := 'SNOMED-CT', "displayName" := 'Waist circumference'), "effectiveTime" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20150506034148'), "operator" := 'I'), "id" := iiinval("extension" := '525', "root" := '2.16.840.1.113883.2.4.3.31.3.1'), "moodCode" := 'EVN', "negationInd" := False, "statusCode" := csinval("code" := 'completed'), "value" := pqinval("unit" := 'cm', "value" := '32.89702707645349'));
role11 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation12 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Performer2', "act" := observation10, "role" := role11, "time" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20150506034148'), "operator" := 'I'), "typeCode" := 'PRF');
actrelationship13 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Entry', "contextConductionInd" := 'true', "source" := act9, "target" := observation10, "typeCode" := 'COMP');
actrelationship14 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Component3', "contextConductionInd" := 'true', "source" := act8, "target" := act9, "typeCode" := 'COMP');
actrelationship15 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Component2', "contextConductionInd" := 'true', "source" := document0, "target" := act8, "typeCode" := 'COMP');
role16 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation17 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'LegalAuthenticator', "act" := document0, "contextControlCode" := 'OP', "role" := role16, "signatureCode" := csinval("code" := 'S'), "time" := tsinval("value" := '20150506034148'), "typeCode" := 'LA');
patient18 := Patient_insert(_mif := 'POCD_MT000040', _clonename := 'PatientRole', "classCode" := 'PAT', "id" := iiinval("extension" := '1', "root" := '2.16.840.1.113883.2.4.3.31.3.3'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Botpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
participation19 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'RecordTarget', "act" := document0, "contextControlCode" := 'OP', "role" := patient18, "typeCode" := 'RCT');
END$$;

/* Patient {5} only reference (weight 0) */

DO
$$DECLARE
document0 bigint;
role1 bigint;
participation2 bigint;
role3 bigint;
participation4 bigint;
organization5 bigint;
role6 bigint;
participation7 bigint;
act8 bigint;
act9 bigint;
observation10 bigint;
role11 bigint;
participation12 bigint;
actrelationship13 bigint;
actrelationship14 bigint;
actrelationship15 bigint;
role16 bigint;
participation17 bigint;
patient18 bigint;
participation19 bigint;
BEGIN
document0 := Document_insert(_mif := 'POCD_MT000040', _clonename := 'ClinicalDocument', "classCode" := 'DOCCLIN', "code" := ceinval("code" := '34133-9', "codeSystem" := '2.16.840.1.113883.6.1', "codeSystemName" := 'LOINC', "displayName" := 'Summary of Episode Note'), "confidentialityCode" := ceinval("code" := 'N', "codeSystem" := '2.16.840.1.113883.5.25', "codeSystemName" := 'Confidentiality', "displayName" := 'Normal'), "effectiveTime" := tsinval("value" := '20140419110023'), "id" := iiinval("extension" := '5e9c3622-f2d3-4f26-8969-762d2333013a', "root" := '2.16.840.1.113883.2.4.3.31.3.1'), "moodCode" := 'EVN', "title" := stinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Examination by Portavita'), "typeId" := iiinval("extension" := 'POCD_HD000040', "root" := '2.16.840.1.113883.1.3'));
role1 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedAuthor', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation2 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Author', "act" := document0, "contextControlCode" := 'OP', "role" := role1, "time" := tsinval("value" := '20150506034148'), "typeCode" := 'AUT');
role3 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'DataEnterer', "act" := document0, "contextControlCode" := 'OP', "role" := role3, "time" := tsinval("value" := '20150506034148'), "typeCode" := 'ENT');
organization5 := Organization_insert(_mif := 'POCD_MT000040', _clonename := 'CustodianOrganization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '0', "root" := '2.16.840.1.113883.2.4.3.31.3.2'), "name" := oninval("content" := 'Portavita B.V.'));
role6 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedCustodian', "classCode" := 'ASSIGNED', "scoper" := organization5);
participation7 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Custodian', "act" := document0, "role" := role6, "typeCode" := 'CST');
act8 := Act_insert(_mif := 'POCD_MT000040', _clonename := 'StructuredBody', "classCode" := 'DOCBODY', "moodCode" := 'EVN');
act9 := Act_insert(_mif := 'POCD_MT000040', _clonename := 'Section', "classCode" := 'DOCSECT', "moodCode" := 'EVN');
observation10 := Observation_insert(_mif := 'POCD_MT000040', _clonename := 'Observation', "classCode" := 'OBS', "code" := cdinval("code" := '396552003', "codeSystem" := '2.16.840.1.113883.6.96', "codeSystemName" := 'SNOMED-CT', "displayName" := 'Waist circumference'), "effectiveTime" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20150506034148'), "operator" := 'I'), "id" := iiinval("extension" := '525', "root" := '2.16.840.1.113883.2.4.3.31.3.1'), "moodCode" := 'EVN', "negationInd" := False, "statusCode" := csinval("code" := 'completed'), "value" := pqinval("unit" := 'cm', "value" := '32.89702707645349'));
role11 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation12 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Performer2', "act" := observation10, "role" := role11, "time" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20150506034148'), "operator" := 'I'), "typeCode" := 'PRF');
actrelationship13 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Entry', "contextConductionInd" := 'true', "source" := act9, "target" := observation10, "typeCode" := 'COMP');
actrelationship14 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Component3', "contextConductionInd" := 'true', "source" := act8, "target" := act9, "typeCode" := 'COMP');
actrelationship15 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Component2', "contextConductionInd" := 'true', "source" := document0, "target" := act8, "typeCode" := 'COMP');
role16 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation17 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'LegalAuthenticator', "act" := document0, "contextControlCode" := 'OP', "role" := role16, "signatureCode" := csinval("code" := 'S'), "time" := tsinval("value" := '20150506034148'), "typeCode" := 'LA');
patient18 := Patient_insert(_mif := 'POCD_MT000040', _clonename := 'PatientRole', "classCode" := 'PAT', "id" := iiinval("extension" := '5', "root" := '2.16.840.1.113883.2.4.6.3'));
participation19 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'RecordTarget', "act" := document0, "contextControlCode" := 'OP', "role" := patient18, "typeCode" := 'RCT');
END$$;


/* Patient {6} only reference */

DO
$$DECLARE
document0 bigint;
role1 bigint;
participation2 bigint;
role3 bigint;
participation4 bigint;
organization5 bigint;
role6 bigint;
participation7 bigint;
act8 bigint;
act9 bigint;
observation10 bigint;
role11 bigint;
participation12 bigint;
actrelationship13 bigint;
actrelationship14 bigint;
actrelationship15 bigint;
role16 bigint;
participation17 bigint;
patient18 bigint;
participation19 bigint;
BEGIN
document0 := Document_insert(_mif := 'POCD_MT000040', _clonename := 'ClinicalDocument', "classCode" := 'DOCCLIN', "code" := ceinval("code" := '34133-9', "codeSystem" := '2.16.840.1.113883.6.1', "codeSystemName" := 'LOINC', "displayName" := 'Summary of Episode Note'), "confidentialityCode" := ceinval("code" := 'N', "codeSystem" := '2.16.840.1.113883.5.25', "codeSystemName" := 'Confidentiality', "displayName" := 'Normal'), "effectiveTime" := tsinval("value" := '20140419110023'), "id" := iiinval("extension" := '5e9c3622-f2d3-4f26-8969-762d2333013a', "root" := '2.16.840.1.113883.2.4.3.31.3.1'), "moodCode" := 'EVN', "title" := stinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Examination by Portavita'), "typeId" := iiinval("extension" := 'POCD_HD000040', "root" := '2.16.840.1.113883.1.3'));
role1 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedAuthor', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation2 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Author', "act" := document0, "contextControlCode" := 'OP', "role" := role1, "time" := tsinval("value" := '20150506034148'), "typeCode" := 'AUT');
role3 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'DataEnterer', "act" := document0, "contextControlCode" := 'OP', "role" := role3, "time" := tsinval("value" := '20150506034148'), "typeCode" := 'ENT');
organization5 := Organization_insert(_mif := 'POCD_MT000040', _clonename := 'CustodianOrganization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '0', "root" := '2.16.840.1.113883.2.4.3.31.3.2'), "name" := oninval("content" := 'Portavita B.V.'));
role6 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedCustodian', "classCode" := 'ASSIGNED', "scoper" := organization5);
participation7 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Custodian', "act" := document0, "role" := role6, "typeCode" := 'CST');
act8 := Act_insert(_mif := 'POCD_MT000040', _clonename := 'StructuredBody', "classCode" := 'DOCBODY', "moodCode" := 'EVN');
act9 := Act_insert(_mif := 'POCD_MT000040', _clonename := 'Section', "classCode" := 'DOCSECT', "moodCode" := 'EVN');
observation10 := Observation_insert(_mif := 'POCD_MT000040', _clonename := 'Observation', "classCode" := 'OBS', "code" := cdinval("code" := '396552003', "codeSystem" := '2.16.840.1.113883.6.96', "codeSystemName" := 'SNOMED-CT', "displayName" := 'Waist circumference'), "effectiveTime" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20150506034148'), "operator" := 'I'), "id" := iiinval("extension" := '525', "root" := '2.16.840.1.113883.2.4.3.31.3.1'), "moodCode" := 'EVN', "negationInd" := False, "statusCode" := csinval("code" := 'completed'), "value" := pqinval("unit" := 'cm', "value" := '32.89702707645349'));
role11 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation12 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'Performer2', "act" := observation10, "role" := role11, "time" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20150506034148'), "operator" := 'I'), "typeCode" := 'PRF');
actrelationship13 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Entry', "contextConductionInd" := 'true', "source" := act9, "target" := observation10, "typeCode" := 'COMP');
actrelationship14 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Component3', "contextConductionInd" := 'true', "source" := act8, "target" := act9, "typeCode" := 'COMP');
actrelationship15 := ActRelationship_insert(_mif := 'POCD_MT000040', _clonename := 'Component2', "contextConductionInd" := 'true', "source" := document0, "target" := act8, "typeCode" := 'COMP');
role16 := Role_insert(_mif := 'POCD_MT000040', _clonename := 'AssignedEntity', "classCode" := 'ASSIGNED', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation17 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'LegalAuthenticator', "act" := document0, "contextControlCode" := 'OP', "role" := role16, "signatureCode" := csinval("code" := 'S'), "time" := tsinval("value" := '20150506034148'), "typeCode" := 'LA');
patient18 := Patient_insert(_mif := 'POCD_MT000040', _clonename := 'PatientRole', "classCode" := 'PAT', "id" := iiinval("extension" := '6', "root" := '2.16.840.1.113883.2.4.6.3'));
participation19 := Participation_insert(_mif := 'POCD_MT000040', _clonename := 'RecordTarget', "act" := document0, "contextControlCode" := 'OP', "role" := patient18, "typeCode" := 'RCT');
END$$;

/* Patient {4,3,7} with name, player, scoper (weight 3301) */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');
person1 := Person_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Person', "addr" := adinval("city" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Qbghexeoe'), "postalCode" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := '6684AW'), "streetAddressLine" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Pdkkxziujjtoy 971'), "useablePeriod" := sxcm_tsinval("operator" := 'I', "value" := '20081117110022')), "administrativeGenderCode" := ceinval("code" := 'M', "codeSystem" := '2.16.840.1.113883.5.1', "codeSystemName" := 'HL7 AdministrativeGender', "displayName" := 'Male'), "birthTime" := tsinval("value" := '19641121110022'), "classCode" := 'PSN', "deceasedInd" := blinval("value" := False), "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '3', "root" := '2.16.840.1.113883.2.4.3.31.3.2') || iiinval("extension" := '7', "root" := '2.16.840.1.113883.2.4.6.3'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Botpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
organization2 := Organization_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Organization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.2'));
patient3 := Patient_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '3', "root" := '2.16.840.1.113883.2.4.3.31.3.2') || iiinval("extension" := '7', "root" := '2.16.840.1.113883.2.4.6.3'), "player" := person1, "scoper" := organization2, "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Botpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

/* Patient {4,3,7} only reference */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');

patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '3', "root" := '2.16.840.1.113883.2.4.3.31.3.2') || iiinval("extension" := '7', "root" := '2.16.840.1.113883.2.4.6.3'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;


/* Patient {3} name */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');
patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '3', "root" := '2.16.840.1.113883.2.4.3.31.3.2'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Botpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

/* Patient {4} only reference */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');

patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '4', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

/* Patient {8} with player and scoper */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');
person1 := Person_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Person', "addr" := adinval("city" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Qbghexeoe'), "postalCode" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := '6684AW'), "streetAddressLine" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Pdkkxziujjtoy 971'), "useablePeriod" := sxcm_tsinval("operator" := 'I', "value" := '20081117110022')), "administrativeGenderCode" := ceinval("code" := 'M', "codeSystem" := '2.16.840.1.113883.5.1', "codeSystemName" := 'HL7 AdministrativeGender', "displayName" := 'Male'), "birthTime" := tsinval("value" := '19641121110022'), "classCode" := 'PSN', "deceasedInd" := blinval("value" := False), "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '8', "root" := '2.16.840.1.113883.2.4.3.31.3.3'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Botpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
organization2 := Organization_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Organization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '1', "root" := '2.16.840.1.113883.2.4.3.31.3.2'));
patient3 := Patient_insert(_mif := 'TZDU_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '8', "root" := '2.16.840.1.113883.2.4.3.31.3.3'), "player" := person1, "scoper" := organization2);
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

/* Patient {8, 9} only reference */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');

patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '8', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '9', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

COMMIT;

BEGIN;

\i /home/m/axle-healthcare-benchmark/pond/preprocess/010_ccontextconduction.sql

COMMIT;
\i /home/m/axle-healthcare-benchmark/pond/preprocess/020_deduplication.sql
\i /home/m/axle-healthcare-benchmark/pond/preprocess/030_denormalize.sql
\i /home/m/axle-healthcare-benchmark/pond/preprocess/040_hash_and_weight.sql
\i /home/m/axle-healthcare-benchmark/pond/preprocess/050_original_id.sql

set hdl.pretty_print to true;
SELECT _id
,       id->0->>'extension'
,       id->1->>'extension'
,       id->2->>'extension'
,       _record_hash
,       _record_weight
FROM "Patient"
ORDER BY _id;

\i /home/m/axle-healthcare-benchmark/lake/postprocess/010_entity_resolution.sql


