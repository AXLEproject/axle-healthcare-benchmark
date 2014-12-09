/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 *
 */

BEGIN ISOLATION LEVEL SERIALIZABLE;

\i 010_entity_resolution.sql
\i 020_opt_out_consent.sql
/*** \i 030_map_acts_to_pcpr.sql **/
\i 999_clean_append_id.sql

END;
