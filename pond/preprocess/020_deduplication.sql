/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Pre-process RIM data in a pond before uploading to the lake.  This can be
 * all pre-processing that does not require knowledge from other documents.
 */
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
WITH
 /* Group organizations on equality of the SET_II id field per message type.
    This will not de-duplicate Organizations that have a different yet
    overlapping id. Those cases will be taken care of by lake de-duplication.
    The pond de-duplication is for low hanging fruit only. */
 unio AS (SELECT DISTINCT ON (_mif, id) * FROM "Organization"),
 dupo AS (SELECT m._id AS oldid, u._id AS newid
              FROM "Organization" m
              JOIN UNIO u
              ON m.id = u.id
              WHERE m._id NOT IN (SELECT _id FROM UNIO)),
 updr AS (UPDATE "Role"
              SET scoper = dupo.newid
              FROM dupo
              WHERE scoper = dupo.oldid
              RETURNING _id),
 delo AS (DELETE
              FROM "Organization"
              WHERE _id IN (SELECT oldid FROM dupo)
              RETURNING _id)
SELECT (select count(*) from updr) AS roles_updated,
       (select count(*) from delo) AS organizations_merged;
END;
