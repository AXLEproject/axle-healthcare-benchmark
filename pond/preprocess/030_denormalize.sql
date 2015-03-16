/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Pre-process RIM data in a pond before uploading to the lake.  This can be
 * all pre-processing that does not require knowledge from other documents.
 */
UPDATE "Act"
SET _code_code       = code->>'code'
,   _code_codesystem = code->>'codeSystem'
,   _id_extension    =
  (SELECT array_agg(elements->>'extension') FROM
  (SELECT jsonb_array_elements(id::text::jsonb) AS elements) e);

UPDATE "Role"
SET    _id_extension    =
  (SELECT array_agg(elements->>'extension') FROM
  (SELECT jsonb_array_elements(id::text::jsonb) AS elements) e);

UPDATE "Entity"
SET _code_code       = code->>'code'
,   _code_codesystem = code->>'codeSystem'
,   _id_extension    =
  (SELECT array_agg(elements->>'extension') FROM
  (SELECT jsonb_array_elements(id::text::jsonb) AS elements) e);

UPDATE "Observation"
SET _value_pq              = value::"PQ"::pq
,   _value_pq_value        = value(value::"PQ"::pq)
,   _value_pq_unit         = unit(value::"PQ"::pq)
WHERE datatype(value)      = 'PQ';

UPDATE "Observation"
SET _value_code_code       = value ->> 'code'
,   _value_code_codesystem = value ->> 'codeSystem'
WHERE datatype(value)      IN ('CD', 'CS', 'CE', 'CO', 'CV');

UPDATE "Observation"
SET _value_int             = (value ->> 'value')::int
WHERE datatype(value)      = 'INT';

UPDATE "Observation"
SET _value_real            = (value ->> 'value')::numeric
WHERE datatype(value)      = 'REAL';

UPDATE "Observation"
SET _value_ivl_real        = value::"IVL_REAL"::ivl_real
WHERE datatype(value)      = 'IVL_REAL';

/* Effective times */

/* Replace this with a single update as soon as we have "GTS"::qset_ts support. */
UPDATE "Act"
SET _effective_time_low = lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz
,   _effective_time_low_year = EXTRACT(year FROM lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_low_month = EXTRACT(month FROM lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_low_day = EXTRACT(day FROM lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_high = highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz
,   _effective_time_high_year = EXTRACT(year FROM highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_high_month = EXTRACT(month FROM highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_high_day = EXTRACT(day FROM highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
WHERE datatype("effectiveTime") = 'IVL_TS';
UPDATE "Act"
SET _effective_time_low = lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz
,   _effective_time_low_year = EXTRACT(year FROM lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_low_month = EXTRACT(month FROM lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_low_day = EXTRACT(day FROM lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_high = highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz
,   _effective_time_high_year = EXTRACT(year FROM highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_high_month = EXTRACT(month FROM highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_high_day = EXTRACT(day FROM highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
WHERE datatype("effectiveTime") = 'TS';

/* Replace this with a single update as soon as we have "GTS"::qset_ts support. */
UPDATE "Role"
SET _effective_time_low = lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz
,   _effective_time_low_year = EXTRACT(year FROM lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_low_month = EXTRACT(month FROM lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_low_day = EXTRACT(day FROM lowvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_high = highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz
,   _effective_time_high_year = EXTRACT(year FROM highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_high_month = EXTRACT(month FROM highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
,   _effective_time_high_day = EXTRACT(day FROM highvalue("effectiveTime"::"IVL_TS"::ivl_ts)::timestamptz)
WHERE datatype("effectiveTime") = 'IVL_TS';
UPDATE "Role"
SET _effective_time_low = lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz
,   _effective_time_low_year = EXTRACT(year FROM lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_low_month = EXTRACT(month FROM lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_low_day = EXTRACT(day FROM lowvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_high = highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz
,   _effective_time_high_year = EXTRACT(year FROM highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_high_month = EXTRACT(month FROM highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
,   _effective_time_high_day = EXTRACT(day FROM highvalue("effectiveTime"::"TS"::ts::ivl_ts)::timestamptz)
WHERE datatype("effectiveTime") = 'TS';

UPDATE "RoleLink"
SET _effective_time_low = lowvalue("effectiveTime")::timestamptz
,   _effective_time_low_year = EXTRACT(year FROM lowvalue("effectiveTime")::timestamptz)
,   _effective_time_low_month = EXTRACT(month FROM lowvalue("effectiveTime")::timestamptz)
,   _effective_time_low_day = EXTRACT(day FROM lowvalue("effectiveTime")::timestamptz)
,   _effective_time_high = highvalue("effectiveTime")::timestamptz
,   _effective_time_high_year = EXTRACT(year FROM highvalue("effectiveTime")::timestamptz)
,   _effective_time_high_month = EXTRACT(month FROM highvalue("effectiveTime")::timestamptz)
,   _effective_time_high_day = EXTRACT(day FROM highvalue("effectiveTime")::timestamptz);
