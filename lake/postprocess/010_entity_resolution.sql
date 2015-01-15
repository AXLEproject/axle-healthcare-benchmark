/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 *
 * Run entity resolution.
 */
SELECT resolution('rim2011', 'Organization', '{{Role,player},{Role,scoper}}');
SELECT resolution('rim2011', 'Person'      , '{{Role,player},{Role,scoper}}');

SELECT resolution('rim2011', 'Role'          , '{{Participation,role}}');
SELECT resolution('rim2011', 'LicensedEntity', '{{Participation,role}}');
SELECT resolution('rim2011', 'Patient'       , '{{Participation,role}}');
