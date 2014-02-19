DO
$$DECLARE

controlact0 bigint;
person1 bigint;
organization2 bigint;
licensedentity3 bigint;
participation4 bigint;
BEGIN
controlact0 := ControlAct_insert(_mif := 'TZDU_MT000002UV', _clonename := 'PractitionerUpdate', "classCode" := 'ACTN', "moodCode" := 'EVN', "templateId" := iiinval("root" := 'TBD'));

person1 := Person_insert(_mif := 'TZDU_MT000002UV', _clonename := 'Practitioner', "addr" := adinval("city" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Ravzqktdi'), "postalCode" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := '4840OE'), "streetAddressLine" := adxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Htysgznusbkmbgbnp 961'), "useablePeriod" := sxcm_tsinval("operator" := 'I', "value" := '20070302170041')), "administrativeGenderCode" := ceinval("code" := 'M', "codeSystem" := '2.16.840.1.113883.5.1', "codeSystemName" := 'HL7 AdministrativeGender', "displayName" := 'Male'), "birthTime" := tsinval("value" := '19670509170041'), "classCode" := 'PSN', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '265', "root" := '2.16.840.1.113883.2.4.3.31.3') || iiinval("extension" := '273', "root" := '2.16.840.1.113883.2.4.3.31.2'), "name" := eninval("family" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Vbylseacnkx'), "given" := enxpinval("mediaType" := 'text/plain', "representation" := 'TXT', "content" := 'Lswgm'), "use" := 'L', "content" := 'Lswgm den Vbylseacnkx'));

organization2 := Organization_insert(_mif := 'TZDU_MT000002UV', _clonename := 'Organization', "classCode" := 'ORG', "determinerCode" := 'INSTANCE', "id" := iiinval("extension" := '241', "root" := '2.16.840.1.113883.2.4.3.31.3.2'));

licensedentity3 := LicensedEntity_insert(_mif := 'TZDU_MT000002UV', _clonename := 'HealthCareProvider', "classCode" := 'PROV', "effectiveTime" := ivl_tsinval("low" := ivxb_tsinval("inclusive" := 'true', "value" := '20090519170041'), "operator" := 'I'), "player" := person1, "scoper" := organization2);

participation4 := Participation_insert(_mif := 'TZDU_MT000002UV', _clonename := 'Subject', "act" := controlact0, "role" := licensedentity3, "typeCode" := 'SBJ');

END$$;
