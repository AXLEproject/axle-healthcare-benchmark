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

--SELECT resolution('rim2011', 'Role'          , '{{Participation_in,role}}');
SELECT resolution('rim2011', 'LicensedEntity', '{{Participation_in,role}}');
SELECT resolution('rim2011', 'Patient'       , '{{Participation_in,role}}');
