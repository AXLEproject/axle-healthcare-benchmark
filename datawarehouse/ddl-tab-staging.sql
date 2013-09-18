/*
 * ddl-tab-staging.sql
 *
 * Additional views and indexes needed by the ETL functions.
 *
 * This file is part of the MGRID HDW sample datawarehouse release.
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */


/*** views for streaming ETL ***/

CREATE FOREIGN DATA WRAPPER pg VALIDATOR postgresql_fdw_validator;
CREATE SERVER dwh FOREIGN DATA WRAPPER dblink_fdw
       OPTIONS (hostaddr '_DWHHOST_', dbname '_DWHNAME_', port '_DWHPORT_'); /* user '_DWHUSER_' */
CREATE USER MAPPING FOR CURRENT_USER SERVER dwh;
SELECT dblink_connect('dwh', 'dwh');

/* Join with this table instead of dim_concept to also match mapped concepts. */
CREATE OR REPLACE VIEW dim_concept_plus AS
SELECT id, code, codesystem, codesystemversion
FROM dim_concept dc
UNION
SELECT dc.id, tm.source_code, tm.source_codesystem, NULL /* need codesystemversion map */
FROM dim_concept dc
JOIN terminology_mapping tm
ON dc.code = tm.target_code
AND dc.codesystem = tm.target_codesystem;

CREATE OR REPLACE VIEW new_observation_evn_pq AS
       SELECT *
       FROM   "Observation"
       WHERE "moodCode" = 'EVN'::CV('ActMood')
       AND datatype(value) = '_pq'
       AND _timestamp > (
           SELECT max_timestamp
           FROM dblink( 'dwh'
                      , 'SELECT COALESCE((SELECT max(timestamp) FROM fact_observation_evn_pq), ''1-1-1970''::timestamptz)'
                      ) AS t(max_timestamp timestamptz)
       )
;

COMMENT ON VIEW new_observation_evn_pq is
'To facilitate streaming ETL: contains the Observations with the EVN moodcode and containing a PQ value that have a timestamp greater than the newest record in the fact_observation_evn_pq table';

CREATE OR REPLACE VIEW new_observation_evn_cd AS
       SELECT *
       FROM   "Observation"
       WHERE "moodCode" = 'EVN'::CV('ActMood')
       AND datatype(value) = '_cd'
       AND _timestamp > (
           SELECT max_timestamp
           FROM dblink( 'dwh'
                      , 'SELECT COALESCE((SELECT max(timestamp) FROM fact_observation_evn_cv), ''1-1-1970''::timestamptz)'
                      ) AS t(max_timestamp timestamptz)
       )
;

COMMENT ON VIEW new_observation_evn_cd is
'To facilitate streaming ETL: contains the Observations with the EVN moodcode and containing a CD value that have a timestamp greater than the newest record in the fact_observation_evn_cv table';

CREATE OR REPLACE VIEW new_act_evn AS
       SELECT *
       FROM   "Act"
       WHERE "classCode" = 'BATTERY'::CV('ActClass')
       AND "moodCode" = 'EVN'::CV('ActMood')
       AND _timestamp > (
           SELECT max_timestamp
           FROM dblink( 'dwh'
                      , 'SELECT COALESCE((SELECT max(timestamp) FROM fact_act_evn), ''1-1-1970''::timestamptz)'
                      ) AS t(max_timestamp timestamptz)
       )
;

/* Create indexes for fast selection of newly arrived acts. */
CREATE INDEX ON "Observation"(_timestamp);
CREATE INDEX ON "DiagnosticImage"(_timestamp);
CREATE INDEX ON "PublicHealthCase"(_timestamp);
CREATE INDEX ON fact_observation_evn_pq(timestamp);
CREATE INDEX ON fact_observation_evn_cv(timestamp);

/* Create indexes to speed up ETL queries */
CREATE INDEX ON "Participation"(act);
CREATE INDEX ON "Participation"(role);
CREATE INDEX ON dim_patient(set_nk);
CREATE INDEX ON dim_provider(set_nk);
CREATE INDEX ON dim_organization(set_nk);
CREATE INDEX ON "Role"(scoper);
CREATE INDEX ON "Role"(player);
CREATE INDEX ON "Participation"("sequenceNumber");
CREATE INDEX ON "Participation"("typeCode");
CREATE INDEX ON dim_template(template_id);
CREATE INDEX ON dim_time(time);
CREATE INDEX ON dim_concept(code, codesystem);

