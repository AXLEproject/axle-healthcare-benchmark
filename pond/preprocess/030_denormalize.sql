/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Pre-process RIM data in a pond before uploading to the lake.  This can be
 * all pre-processing that does not require knowledge from other documents.
 */
UPDATE "Observation"
SET _value_pq_value   = value(value::"PQ"::pq)
,   _value_pq_unit    = unit(value::"PQ"::pq)
WHERE datatype(value) = 'PQ';

UPDATE "Observation"
SET _value_code_code  = value ->> 'code'
,   _value_code_codesystem = value ->> 'codeSystem';

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
