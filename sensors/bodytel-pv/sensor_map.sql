/*
 * sensor_map.sql
 *
 * Functions to map incoming sensor data to CDA.
 *
 * Copyright (c) 2013, Portavita BV Netherlands
 */
CREATE LANGUAGE plpythonu;
CREATE EXTENSION plsh;

CREATE TABLE sensor_data (id SERIAL, message json, v3message text, processed bool default false, timestamp timestamptz DEFAULT now());

CREATE TABLE sensortype_template_map (vendor text, message_type text, template_file text, template text);

INSERT INTO sensortype_template_map (vendor, message_type, template_file)
VALUES
('bodytel', 'heart_rate', 'TEMPLATE.364075005.Heart_rate.xml'),
('bodytel', 'glucose', 'TEMPLATE.Portavita174.Glucose_curve.xml'),
('bodytel', 'blood_pressure', 'TEMPLATE.12133-5.Blood_pressure.xml')
;

CREATE FUNCTION gettext(url TEXT) RETURNS TEXT
AS $$
import urllib2
try:
  f = urllib2.urlopen(url)
  return ''.join(f.readlines())
except Exception:
  return ""
$$ LANGUAGE plpythonu;

UPDATE sensortype_template_map SET template = gettext('file:///_TEMPLATEDIR_/' || template_file);

CREATE TABLE transform (message_type TEXT, placeholder TEXT, replace_expression text);

INSERT INTO transform (message_type, placeholder, replace_expression)
VALUES
 ('heart_rate',     '${documentId}',                '1')
,('heart_rate',     '${date}',                      '$1->>''date''')
,('heart_rate',     '${patientRoleId}',             '1')
,('heart_rate',     '${assignedEntityId}',          '1')
,('heart_rate',     '${value}',                     '$1->>''value''')
,('blood_pressure', '$documentId',                  '1')
,('blood_pressure', '$date',                        '$1->>''date''')
,('blood_pressure', '$patientRoleId',               '1')
,('blood_pressure', '$assignedEntityId',            '1')
,('blood_pressure', '$systolicBloodPressureValue',  '$1->>''systolic''')
,('blood_pressure', '$diastolicBloodPressureValue', '$1->>''diastolic''')
,('glucose',        '$documentId',                  '1')
,('glucose',        '$date',                        '$1->>''date''')
,('glucose',        '$templatePatientRoleId',       '1')
,('glucose',        '$templateAssignedEntityId',    '1')
,('glucose',        '$glucosecode',                 '$1->>''period''')
,('glucose',        '$value',                       '$1->>''value''')
;

CREATE OR REPLACE FUNCTION sensor_to_hl7v3()
RETURNS void
AS $$
DECLARE m RECORD;
        t RECORD;
        expresult TEXT;
        result TEXT;
        transformed BOOL;
BEGIN
        FOR m IN (SELECT msg.id, msg.message, msg.timestamp, map.vendor, map.message_type, map.template
                  FROM sensor_data msg
                  JOIN sensortype_template_map map
                  ON msg.message->>'type' = map.message_type
                  WHERE msg.v3message IS NULL
                  FOR UPDATE OF msg
                  )
        LOOP
                transformed := false;
                result := m.template;
--                RAISE INFO 'new message %', m.message;
                FOR t IN (SELECT * FROM transform tra
                          WHERE tra.message_type = m.message_type)
                LOOP
--                          RAISE INFO 'new transform %', t.replace_expression;
                          EXECUTE 'SELECT ' || t.replace_expression USING m.message INTO expresult;
                          result := replace(result, t.placeholder, expresult);
                          transformed := true;
                END LOOP;
                IF transformed THEN
                   UPDATE sensor_data SET v3message = result WHERE id = m.id;
--                   RAISE INFO 'v3message %', result;
                END IF;
        END LOOP;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sensor_to_hl7v3() IS
        'Transforms all unprocessed sensor messages to corresponding HL7v3 messages';

CREATE FUNCTION writefile (name text, contents text) RETURNS void
AS $$
#!/bin/sh
cat > $1 <<EOF
$2
EOF
$$ LANGUAGE plsh;

CREATE FUNCTION writefiles() RETURNS bigint
AS $writefiles$
  WITH write AS (
    UPDATE sensor_data
    SET processed = true
    WHERE processed = false
    AND v3message IS NOT NULL
    RETURNING writefile('_OUTPUTDIR_/sensor-msg-'|| id, v3message)
  )
  SELECT count(*) FROM write;
$writefiles$ LANGUAGE sql;
