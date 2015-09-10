/*
 * retinopathy_checks
 *
 * Copyright (c) 2015, Portavita B.V.
 */

\echo
\echo 'If the research_user does not exist, run \'create_research_schema.sql\' first.'
\echo
SET session_authorization TO research_user;
SET SEARCH_PATH TO research, public, rim2011, hdl, hl7, r1, "$user";

\echo 'Check that post load document updates have been run.'
SELECT 1/EXISTS(SELECT * FROM pg_class WHERE relname='document_1_patient_id_id')::int;


