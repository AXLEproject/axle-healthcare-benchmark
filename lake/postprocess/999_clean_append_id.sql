/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Clean append_id.
 * Delete records not deleted by entity resolution.
 *
 */

DELETE FROM stream.append_id
WHERE schema_name = 'rim2011'
AND   table_name IN ('ActRelationship','Act','Observation','ControlAct','Participation','Document');
