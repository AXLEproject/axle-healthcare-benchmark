/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 */

BEGIN;
SELECT resolution_start  ('rim2011', 'Patient'  );
SELECT resolution_execute('rim2011', 'Patient'  , '{{Participation,role}}');
SELECT resolution_end    ('rim2011', 'Patient'  );
COMMIT;

BEGIN;
SELECT resolution_start  ('rim2011', 'Organization');
SELECT resolution_execute('rim2011', 'Organization', '{{Role,player},{Role,scoper}}');
SELECT resolution_end    ('rim2011', 'Organization');
COMMIT;

BEGIN;
SELECT resolution_start  ('rim2011', 'Person');
SELECT resolution_execute('rim2011', 'Person', '{{Role,player},{Role,scoper}}');
SELECT resolution_end    ('rim2011', 'Person');
COMMIT;

BEGIN;
SELECT resolution_start  ('rim2011', 'LicensedEntity');
SELECT resolution_execute('rim2011', 'LicensedEntity', '{{Participation,role}}');
SELECT resolution_end    ('rim2011', 'LicensedEntity');
COMMIT;
