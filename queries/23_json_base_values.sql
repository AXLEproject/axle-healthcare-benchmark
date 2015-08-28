UPDATE document
SET patient_id = document#>>'{recordTarget,0,patientRole,id,0,extension}';

create index on documents_1(patient_id);
create index on documents_2(patient_id);
create index on documents_3(patient_id);
create index on documents_4(patient_id);

/* The following view gets the extension of id root 31.3.3 from 10% of the Patients */
CREATE OR REPLACE VIEW Patient_sample
AS
SELECT ids.value AS patient_id
FROM   "Patient" TABLESAMPLE BERNOULLI (1),
       jsonb_each_jsquery_text(id::"ANY"::jsonb, '#(root = "2.16.840.1.113883.2.4.3.31.3.3")') as ids
WHERE ids.key = 'extension'
;

CREATE OR REPLACE VIEW Documents_of_patients_sample
AS
 WITH docinfo AS
 (
  -- use WITH QUERY query as optimization fence to prevent parsing the id columns for each object
  -- key value pair from the jsonb_each_jsquery call below
  SELECT document, json_build_object(
   'row_id', id,
   'document_id', document#>>'{id,extension}',
   'patient_id', document#>>'{recordTarget,0,patientRole,id,0,extension}',
   'author_id', document#>>'{author,0,assignedAuthor,id,0,extension}',
   'legalauthenticator_id', document#>>'{legalAuthenticator,assignedEntity,id,0,extension}',
   'serviceevent_id', document#>>'{documentationOf,0,serviceEvent,id,0,extension}')::text
   AS row_name
  FROM documents
  NATURAL JOIN Patient_sample
 )
 SELECT docinfo.row_name,
        observations.key, observations.value
 FROM docinfo,
      jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
 WHERE observations.key IN ('classCode', 'moodCode', 'statusCode', 'code', 'value', 'negationInd', 'effectiveTime')
 ORDER BY row_name, observations.key
;

/** Query to get Observation objects pivoted from JSON blobs **/
CREATE OR REPLACE VIEW Observations_of_patients_sample
AS
SELECT *
FROM crosstab
(
 $ct$
 SELECT * FROM Documents_of_patients_sample
$ct$,
$ct$VALUES('classCode'), ('moodCode'), ('statusCode'), ('code'), ('value'), ('negationInd'), ('effectiveTime')
$ct$
) -- crosstab(
AS ct(row_name jsonb,
   "classCode" jsonb,
   "moodCode" jsonb,
   "statusCode" jsonb,
   "code" jsonb,
   "value" jsonb,
   "negationInd" jsonb,
   "effectiveTime" jsonb
)
;




\quit




SELECT
document->'dataEnterer'->'assignedEntity' AS data_enterer_role
,
document->'recordTarget'->0->'patientRole' AS record_target
--document->'dataEnterer'->>'assignedEntity' AS data_enterer_role
FROM documents
LIMIT 1;


SELECT jsonb_array_elements(document->'recordTarget') AS record_target_participation
FROM documents
limit 1;
select jsonb_pretty(document) from documents limit 1;



SELECT documents.id, observations.key, observations.value
FROM documents,
     jsonb_each(document#>'{component,structuredBody,component,0,section,entry,0, organizer, component,0,observation}') AS observations
limit 5;

time psql -tAd aap -c "SELECT documents.id, observations.key, observations.value FROM documents, jsonb_each(document#>'{component,structuredBody,component,0,section,entry,0, organizer, component,0,observation}') AS observations;">/dev/null | wc -l


-- get all observations
SELECT documents.id, observations.key, observations.value
FROM documents,
     jsonb_each_jsquery(document, '*.classCode="OBS"') AS observations
limit 5;

-- get all observations
SELECT documents.id, observations.key, observations.value
FROM documents,
     jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
limit 5;


time psql -tAd aap -c "SELECT documents.id, observations.key, observations.value FROM documents, jsonb_each_jsquery(document, '*.classCode="OBS"') AS observations;"  | wc -l

limit 4000000;
-- select all documents where any path equals this value
SELECT document @@ '*.code = "365980008"'
FROM documents
LIMIT 5;

-- get all objects that have a legalAuthenticator relation
SELECT documents.id, observations.key, jsonb_pretty(observations.value)
FROM documents,
     jsonb_each_jsquery(document, '*.legalAuthenticator = *') AS observations
limit 400;

-- get all objects with smoking code
 SELECT documents.id, observations.key, jsonb_pretty(observations.value)
FROM documents,
     jsonb_each_jsquery(document, '*.code.code = "365980008"') AS observations
limit 400;



WITH d AS (
SELECT
document->'dataEnterer'->'assignedEntity'->'representedOrganization' AS data_enterer_role
--document->>'dataEnterer' AS data_enterer
--document->'dataEnterer'->>'assignedEntity' AS data_enterer_role
FROM ddocs
)
SELECT * FROM d where data_enterer_role is not null
LIMIT 1;


CREATE VIEW base_values_synthetic_dataset

SELECT id,
document#>>'{id,extension}' AS document_id,
document#>>'{recordTarget,0,patientRole,id,0,extension}' AS patient_id,
document#>>'{author,0,assignedAuthor,id,0,extension}' AS author_id,
document#>>'{legalAuthenticator,0,assignedEntity,id,0,extension}' AS legalauthenticator_id,
document#>>'{documentationOf,0,serviceEvent,id,0,extension}' AS serviceevent_id, -- care provision id
--document#>>'{code,code}' AS document_code,
observations.key,
observations.value
FROM documents,
     jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
WHERE observations.key IN ('classCode', 'moodCode', 'statusCode', 'code', 'value', 'negationInd', 'effectiveTime')
limit 400;


/** Query to get Observation objects from JSON blobs **/
WITH docinfo AS
(
 -- use WITH QUERY query as optimization fence to prevent parsing the id columns for each object
 -- key value pair from the jsonb_each_jsquery call below
 SELECT document, json_build_object(
  'row_id', id,
  'document_id', document#>>'{id,extension}',
  'patient_id', document#>>'{recordTarget,0,patientRole,id,0,extension}',
  'author_id', document#>>'{author,0,assignedAuthor,id,0,extension}',
  'legalauthenticator_id', document#>>'{legalAuthenticator,assignedEntity,id,0,extension}',
  'serviceevent_id', document#>>'{documentationOf,0,serviceEvent,id,0,extension}')
  AS row_name
 FROM documents
)
SELECT docinfo.row_name,
       observations.key, observations.value
FROM docinfo,
     jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
WHERE observations.key IN ('classCode', 'moodCode', 'statusCode', 'code', 'value', 'negationInd', 'effectiveTime')
limit 50
;



/** Query to get Observation objects pivoted from JSON blobs **/
CREATE OR REPLACE VIEW observations_full
AS
SELECT *
FROM crosstab
(
 $ct$
 WITH docinfo AS
 (
  -- use WITH QUERY query as optimization fence to prevent parsing the id columns for each object
  -- key value pair from the jsonb_each_jsquery call below
  SELECT document, json_build_object(
   'row_id', id,
   'document_id', document#>>'{id,extension}',
   'patient_id', document#>>'{recordTarget,0,patientRole,id,0,extension}',
   'author_id', document#>>'{author,0,assignedAuthor,id,0,extension}',
   'legalauthenticator_id', document#>>'{legalAuthenticator,assignedEntity,id,0,extension}',
   'serviceevent_id', document#>>'{documentationOf,0,serviceEvent,id,0,extension}')::text
   AS row_name
  FROM documents
  TABLESAMPLE BERNOULLI (0.1)
 )
 SELECT docinfo.row_name,
        observations.key, observations.value
 FROM docinfo,
      jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
 WHERE observations.key IN ('classCode', 'moodCode', 'statusCode', 'code', 'value', 'negationInd', 'effectiveTime')
 ORDER BY row_name, observations.key
$ct$,
$ct$VALUES('classCode'), ('moodCode'), ('statusCode'), ('code'), ('value'), ('negationInd'), ('effectiveTime')
$ct$
) -- crosstab(
AS ct(row_name jsonb,
   "classCode" jsonb,
   "moodCode" jsonb,
   "statusCode" jsonb,
   "code" jsonb,
   "value" jsonb,
   "negationInd" jsonb,
   "effectiveTime" jsonb
)
;

UPDATE document
SET patient_id = document#>>'{recordTarget,0,patientRole,id,0,extension}';

/* The following view gets the extension of id root 31.3.3 from 10% of the Patients */
CREATE VIEW Patient_10_percent
AS
SELECT ids.value AS patient_id
FROM   "Patient" TABLESAMPLE BERNOULLI (10),
       jsonb_each_jsquery_text(id::"ANY"::jsonb, '#(root = "2.16.840.1.113883.2.4.3.31.3.3")') as ids
WHERE ids.key = 'extension'
;

/** Query to get a sample of Observation objects pivoted from JSON blobs **/
CREATE OR REPLACE FUNCTION observations_sample(float)
RETURNS SETOF observations_full
AS $func$
SELECT *
FROM crosstab
(
 $ct$
 WITH docinfo AS
 (
  -- use WITH QUERY query as optimization fence to prevent parsing the id columns for each object
  -- key value pair from the jsonb_each_jsquery call below
  SELECT document, json_build_object(
   'row_id', id,
   'document_id', document#>>'{id,extension}',
   'patient_id', document#>>'{recordTarget,0,patientRole,id,0,extension}',
   'author_id', document#>>'{author,0,assignedAuthor,id,0,extension}',
   'legalauthenticator_id', document#>>'{legalAuthenticator,assignedEntity,id,0,extension}',
   'serviceevent_id', document#>>'{documentationOf,0,serviceEvent,id,0,extension}')::text
   AS row_name
  FROM documents
  TABLESAMPLE BERNOULLI (0.01)
 )
 SELECT docinfo.row_name,
        observations.key, observations.value
 FROM docinfo,
      jsonb_each_jsquery(document, '*._rimname="Observation"') AS observations
 WHERE observations.key IN ('classCode', 'moodCode', 'statusCode', 'code', 'value', 'negationInd', 'effectiveTime')
 ORDER BY row_name, observations.key
$ct$,
$ct$VALUES('classCode'), ('moodCode'), ('statusCode'), ('code'), ('value'), ('negationInd'), ('effectiveTime')
$ct$
) -- crosstab(
AS ct(row_name jsonb,
   "classCode" jsonb,
   "moodCode" jsonb,
   "statusCode" jsonb,
   "code" jsonb,
   "value" jsonb,
   "negationInd" jsonb,
   "effectiveTime" jsonb
)
;
$func$
LANGUAGE SQL;


SELECT * FROM "Patients" TABLESAMPLE BERNOULLI (0.1);


