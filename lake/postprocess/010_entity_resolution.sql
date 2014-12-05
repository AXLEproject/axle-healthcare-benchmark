/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 *
 * Use the following oneliner to resolve incoming data

while true ; do PGOPTIONS='--client-min-messages=warning' time psql --set=VERBOSITY=terse -p 15432 lake -f postprocess/010_entity_resolution.sql ; sleep 5 ; done

 */
SELECT resolution('rim2011', 'Organization', '{{Role,player},{Role,scoper}}');
SELECT resolution('rim2011', 'Person'      , '{{Role,player},{Role,scoper}}');

SELECT resolution('rim2011', 'Role'          , '{{Participation,role}}');
SELECT resolution('rim2011', 'LicensedEntity', '{{Participation,role}}');
SELECT resolution('rim2011', 'Patient'       , '{{Participation,role}}');

