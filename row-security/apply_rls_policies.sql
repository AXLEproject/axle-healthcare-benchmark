/*
 * apply_rls_policies.sql
 *
 * Row Level Security policy for preventing unauthorized users to access
 * patient records whereby there is an opt-out consent from the patient. The
 * purpose of use is research.
 *
 * Copyright (c) 2014, Portavita BV Netherlands
 */

SET row_security TO ON;

-- Enable row level security on the following tables

ALTER TABLE "Observation" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Act" ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS p10 ON "Observation";
DROP POLICY IF EXISTS p11 ON "Act";

-- Prevents access to those records that are part of a care provision for which
-- the patient has released an opt-out consent.

CREATE POLICY p10 ON "Observation"
	USING (
         NOT EXISTS  (
            SELECT 1
            FROM   "LinkActPcpr" link
            JOIN  "OptOutConsent" optout
            ON    optout."patientId"                    = link."patientId"
            AND   optout."careProvision"->>'code'       = link."careProvision"->>'code'
            AND   optout."careProvision"->>'codeSystem' = link."careProvision"->>'codeSystem'
            WHERE link."actId" = "Observation"._id
        ));


CREATE POLICY p11 ON "Act"
    USING (
        NOT EXISTS (
            SELECT 1
            FROM   "LinkActPcpr" link
            JOIN  "OptOutConsent" optout
            ON    optout."patientId"                    =link."patientId"
            AND   optout."careProvision"->>'code'       =link."careProvision"->>'code'
            AND   optout."careProvision"->>'codeSystem' =link."careProvision"->>'codeSystem'
            WHERE link."actId" = "Act"._id
        ));
