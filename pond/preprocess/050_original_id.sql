/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Pre-process RIM data in a pond before uploading to the lake.  This can be
 * all pre-processing that does not require knowledge from other documents.
 */

/*
 * Set original ids.
 */

UPDATE "Role"
SET    player_original = player
,      scoper_original = scoper
;

UPDATE "RoleLink"
SET    source_original = source
,      target_original = target
;

UPDATE "Participation"
SET    act_original = act
,      role_original = role
;

UPDATE "ActRelationship"
SET    source_original = source
,      target_original = target
;
