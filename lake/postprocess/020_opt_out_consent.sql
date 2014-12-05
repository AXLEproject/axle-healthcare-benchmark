/*
 * (c) 2014 Portavita B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 *
 * Rewrite opt out consent into its own table.
 */

WITH consents AS (
SELECT  doc._id 					AS clin_doc_id
,		ptnt.id 					AS ptnt_id
FROM 	ONLY "Document" 		doc
JOIN    stream.append_id                i
ON      i.schema_name    = 'rim2011'
AND     i.table_name     = 'Document'
AND     i.id             = doc._id
JOIN 	"Participation" sbj_ptcp
ON 	sbj_ptcp.act 				= doc._id
and     sbj_ptcp."typeCode"->>'code' =  'RCT'
JOIN    "Patient"       ptnt
ON      ptnt._id                	= sbj_ptcp.role
WHERE 	doc._code_code 				= '57016-8'
),
consent_directives AS (
SELECT 	cons_directive._id 				AS cons_directive_id
, 		doc.ptnt_id  					AS patientId
FROM "ActRelationship"  ar_docbody
JOIN 	consents 		doc
ON 		ar_docbody.source 				= doc.clin_doc_id
JOIN "Act" doc_body
ON 		doc_body._id 					= ar_docbody.target
JOIN "ActRelationship" ar_docsect
ON 		ar_docsect.source 				= doc_body._id
JOIN "Act" doc_sect
on 		doc_sect._id					= ar_docsect.target
JOIN "ActRelationship" ar_cons_dir
ON 		ar_cons_dir.source				= doc_sect._id
JOIN "Act" cons_directive
ON 		cons_directive._id 				= ar_cons_dir.target
WHERE doc_body."classCode"->>'code'		= 'DOCBODY'
AND 	doc_sect._code_code				= '57016-6'
AND 	doc_sect._code_codesystem		= '2.16.840.1.113883.6.1'
AND 	cons_directive._code_code 		= 'HRESCH'
AND 	cons_directive._code_codesystem = '2.16.840.1.113883.3.18.7.1'
),
outputdata AS (
SELECT 	cd.patientId  							AS patientId
, 		principal_diagnosis."value" 			AS careprovision
FROM "ActRelationship" ar_principaldiagnosis
JOIN 	consent_directives 				cd
ON 		ar_principaldiagnosis.source 	= cd.cons_directive_id
JOIN "Observation" principal_diagnosis
ON 		principal_diagnosis._id 		= ar_principaldiagnosis.target
JOIN "ActRelationship" ar_action
ON 		ar_action.source 				= cd.cons_directive_id
JOIN "Observation" action
ON 		action._id						= ar_action.target
WHERE 	action."code"->>'codeSystem'	= '2.16.840.1.113883.5.4'
AND 	action."code"->>'code'			= 'IDISCL'
AND 	action."negationInd"			= 'true'
AND 	principal_diagnosis."code"->>'code'= '8319008'
AND 	principal_diagnosis."code"->>'codeSystem'= '2.16.840.1.113883.6.96'
)
INSERT INTO "OptOutConsent" ("patientId", "careProvision")
SELECT outputdata.patientId, outputdata.careprovision
FROM outputdata;
