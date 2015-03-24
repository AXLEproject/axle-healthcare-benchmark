/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Step 2: index on base values.
 *
 * Copyright (c) 2014, Portavita B.V.
 */

\set ON_ERROR_STOP on

\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, hdl, hl7, r1, "$user";

\set ON_ERROR_STOP off

CREATE INDEX ON base_values (pseudonym, code);
