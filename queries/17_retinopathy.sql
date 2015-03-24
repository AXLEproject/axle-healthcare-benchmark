/*
 * query      : retinopathy.sql
 * description: create retinopathy tabular data for Orange
 * user       : researchers, de-identification required
 *
 * Setup.
 *
 * Copyright (c) 2014, Portavita B.V.
 */

\set ON_ERROR_STOP on

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS tablefunc;

\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, hdl, hl7, r1, "$user";

\set ON_ERROR_STOP off

/** create a one-time pseudonym **/
DROP TABLE IF EXISTS pseudonyms;
CREATE TABLE pseudonyms
AS
      SELECT  ptnt.player AS ptnt_player
      ,       crypt(ptnt.player::text, gen_salt('md5'))   AS pseudonym
      FROM    "Patient"                                ptnt
      JOIN    "Person"                                 peso
      ON      peso._id                                 = ptnt.player
;
