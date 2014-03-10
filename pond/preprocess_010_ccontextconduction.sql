/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Pre-process RIM data in a pond before uploading to the lake.  This can be
 * all pre-processing that does not require knowledge from other documents.
 */

/* Pre-RIM230 style C / conduction indicator based context conduction */
DO $$
BEGIN
    ALTER TABLE "Participation"
        ADD COLUMN origin bigint; /* REFERENCES "Participation" ON DELETE CASCADE */
EXCEPTION
    WHEN duplicate_column THEN NULL;
END;
$$ LANGUAGE plpgsql;

WITH cp AS
(
    SELECT
        op._id AS id_of_origin
    ,   op.act AS act_of_origin
    ,   '_ContextControlPropagating:2.16.840.1.113883.5.1057' >> p."contextControlCode" AS propagating
    ,   '_ContextControlOverriding:2.16.840.1.113883.5.1057' >> p."contextControlCode" AS overriding
    ,   p.*
    FROM
    (
        SELECT p.*
        FROM "Participation" p
        WHERE p."contextControlCode" IS NOT NULL
        -- The construct to prevent propagation of > 1 level for not-propagating Participations
        -- in the queries below is only valid when this function is run from the original Participation.
        -- In the case that we're called from a ActRelationship trigger with a conducted (origin != NULL)
        -- Participation, we may not further propagate non-propagating Participations.
        AND (p.origin IS NULL OR '_ContextControlPropagating:2.16.840.1.113883.5.1057' >> p."contextControlCode")
    ) p
    JOIN "Participation" op
    ON op._id = COALESCE(p.origin,p._id)
),
insert_new AS
(
    INSERT INTO "Participation"
         (act, role, _mif, _clonename, "typeCode", "functionCode", "contextControlCode", "sequenceNumber",
         "negationInd", "noteText", time, "modeCode", "awarenessCode", "signatureCode",
         "signatureText", "performInd", "substitutionConditionCode", "subsetCode",
          origin)
    WITH RECURSIVE act(cpid, propagating, act_of_origin, id, level, path) AS (
         SELECT cp._id, propagating, act_of_origin, cp.act, 1, ARRAY[cp.act] FROM cp
         UNION ALL
         SELECT cpid, propagating, act_of_origin, target, level+1, path || target
         FROM "ActRelationship" r
         INNER JOIN act ON (r.source = act.id)
         WHERE r."contextConductionInd"
         AND (NOT (level > 1) OR propagating)
         AND NOT (target = ANY(path)) -- prevent cycles in this query
         AND target != act_of_origin  -- prevent conducting to act of original Participation
    )
    SELECT id, cp.role,
           cp._mif, cp._clonename,
           cp."typeCode", cp."functionCode", cp."contextControlCode", cp."sequenceNumber",
           cp."negationInd", cp."noteText", cp.time, cp."modeCode", cp."awarenessCode", cp."signatureCode",
           cp."signatureText", cp."performInd", cp."substitutionConditionCode", cp."subsetCode",
           cp.id_of_origin
    FROM act
    JOIN cp
    ON   cp._id = act.cpid
    WHERE id != cp.act
    AND NOT EXISTS (SELECT 1 FROM "Participation" e
        WHERE e.act = id
        AND e.role = cp.role
        AND e."typeCode" IS NOT DISTINCT FROM cp."typeCode"
        AND e."functionCode" IS NOT DISTINCT FROM cp."functionCode"
        AND e."contextControlCode" IS NOT DISTINCT FROM cp."contextControlCode"
        AND e."sequenceNumber" IS NOT DISTINCT FROM cp."sequenceNumber"
        AND e."negationInd" IS NOT DISTINCT FROM cp."negationInd"
        AND e."noteText" IS NOT DISTINCT FROM cp."noteText"
        AND e."modeCode" IS NOT DISTINCT FROM cp."modeCode"
        AND e."awarenessCode" IS NOT DISTINCT FROM cp."awarenessCode"
        AND e."signatureCode" IS NOT DISTINCT FROM cp."signatureCode"
        AND e."signatureText" IS NOT DISTINCT FROM cp."signatureText"
        AND e."performInd" IS NOT DISTINCT FROM cp."performInd"
        AND e."substitutionConditionCode" IS NOT DISTINCT FROM cp."substitutionConditionCode"
-- not in all RIMs       AND e."subsetCode" IS NOT DISTINCT FROM cp."subsetCode"
        AND e.time IS NOT DISTINCT FROM cp.time
        ) /* even though this query is supposed to run once, protect against duplicates */
    RETURNING "Participation"._id
)
SELECT 'Conduction indicator based context conduction: ' || count(*) FROM insert_new
;

