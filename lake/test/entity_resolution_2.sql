/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 */
/*
 * Patient records:
 * id      contents          desc
 * -------------------------------------
 * {5}     another name      match against existing cluster, new version
 * {4}     only reference    match against existing cluster, not a new version
 * {11}    only reference    should be a new cluster
 * -- {9,10}  only reference    match against existing cluster, not a new version, additional id 10.
 */

BEGIN;

SELECT pond_setseq(2000,3000);

/* Patient {5} name */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');
patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '5', "root" := '2.16.840.1.113883.2.4.6.3'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Fsdgcywc'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'NewBotpbrc'), "use" := 'L', "content" := 'Botpbrc Fsdgcywc'));
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

/* Patient {11} only reference */
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');

patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '11', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;

/* Patient {9,10} only reference */
/**
DO
$$DECLARE
controlact0 bigint;
person1 bigint;
organization2 bigint;
patient3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000003UV', _clonename := 'PatientUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN');

patient3 := Patient_insert(_mif := 'AAAA_MT000003UV', _clonename := 'Patient', "classCode" := 'PAT', "id" := iiinval("extension" := '10', "root" := '2.16.840.1.113883.2.4.3.31.3.3') || iiinval("extension" := '9', "root" := '2.16.840.1.113883.2.4.3.31.3.3'));
participation4 := Participation_insert(_mif := 'TZDU_MT000003UV', _clonename := 'RecordTarget', "act" := controlact0, "role" := patient3, "typeCode" := 'RCT');
END$$;
**/

COMMIT;


/* Test: should be empty
select a._id,  a._id_cluster, a._id_extension, b._id, b._id_cluster, b._id_extension from "Patient" a join "Patient" b on a._id_extension && b._id_extension and a.id && b.id and a._id <> b._id;
*/