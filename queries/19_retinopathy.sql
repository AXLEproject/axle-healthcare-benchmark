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
\i retinopathy_checks.sql
\set ON_ERROR_STOP off

CREATE INDEX ON base_values (unit_of_observation, code);
