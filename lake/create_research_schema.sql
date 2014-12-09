/*
 * query      : create_research_schema.sql
 * description: create schema and user to access research tables
 * user       : researchers, de-identification required
 *
 * Copyright (c) 2014, Portavita B.V.
 */

/**
 DROP SCHEMA IF EXISTS research CASCADE;
 DROP OWNED BY research_user;
 DROP USER IF EXISTS research_user;
**/

CREATE SCHEMA research;
DROP USER IF EXISTS research_user;
CREATE USER research_user LOGIN;
GRANT CONNECT ON DATABASE lake TO research_user;
ALTER USER research_user SET SEARCH_PATH TO research, public, "$user";
GRANT USAGE ON SCHEMA research, rim2011, pg_hl7, hl7 TO research_user;

GRANT ALL PRIVILEGES ON SCHEMA research TO research_user;
GRANT SELECT ON ALL TABLES IN SCHEMA rim2011 TO research_user;

/***
CREATE USER unrestricted_user LOGIN;
GRANT CONNECT ON DATABASE lake TO unrestricted_user;
ALTER USER unrestricted_user SET SEARCH_PATH TO public, pg_hl7, hl7, "$user";
GRANT USAGE ON SCHEMA public, rim2011, pg_hl7, hl7 TO unrestricted_user;

GRANT ALL PRIVILEGES ON SCHEMA public TO unrestricted_user;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO unrestricted_user;
***/

