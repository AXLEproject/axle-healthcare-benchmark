/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 */
/**
                                                         QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------
 Append  (cost=0.00..141.86 rows=1190 width=816) (actual time=0.007..0.468 rows=856 loops=1)
   ->  Seq Scan on "Entity"  (cost=0.00..0.00 rows=1 width=636) (actual time=0.001..0.001 rows=0 loops=1)
   ->  Seq Scan on "LivingSubject"  (cost=0.00..0.00 rows=1 width=636) (actual time=0.000..0.000 rows=0 loops=1)
   ->  Seq Scan on "Material"  (cost=0.00..0.00 rows=1 width=636) (actual time=0.000..0.000 rows=0 loops=1)
 ->  Seq Scan on "Organization"  (cost=0.00..35.82 rows=582 width=758) (actual time=0.005..0.231 rows=582 loops=1)
   ->  Seq Scan on "Place"  (cost=0.00..10.90 rows=90 width=636) (actual time=0.000..0.000 rows=0 loops=1)
   ->  Seq Scan on "NonPersonLivingSubject"  (cost=0.00..10.80 rows=80 width=636) (actual time=0.000..0.000 rows=0 loops=1)
 ->  Seq Scan on "Person"  (cost=0.00..62.74 rows=274 width=1158) (actual time=0.002..0.161 rows=274 loops=1)
   ->  Seq Scan on "ManufacturedMaterial"  (cost=0.00..0.00 rows=1 width=636) (actual time=0.000..0.000 rows=0 loops=1)
   ->  Seq Scan on "Container"  (cost=0.00..10.80 rows=80 width=636) (actual time=0.001..0.001 rows=0 loops=1)
   ->  Seq Scan on "Device"  (cost=0.00..10.80 rows=80 width=636) (actual time=0.000..0.000 rows=0 loops=1)
**/
SELECT resolution('rim2011', 'Organization', '{{Role,player},{Role,scoper}}');
SELECT resolution('rim2011', 'Person'      , '{{Role,player},{Role,scoper}}');

/***
---------------------------------------------------------------------------
 Append  (cost=0.00..115.40 rows=2040 width=775) (actual time=0.005..0.603 rows=1780 loops=1)
 ->  Seq Scan on "Role"  (cost=0.00..57.64 rows=1264 width=773) (actual time=0.004..0.296 rows=1264 loops=1)
   ->  Seq Scan on "Access"  (cost=0.00..10.90 rows=90 width=744) (actual time=0.000..0.000 rows=0 loops=1)
   ->  Seq Scan on "Employee"  (cost=0.00..10.70 rows=70 width=744) (actual time=0.000..0.000 rows=0 loops=1)
 ->  Seq Scan on "LicensedEntity"  (cost=0.00..12.62 rows=262 width=815) (actual time=0.002..0.085 rows=262 loops=1)
 ->  Seq Scan on "Patient"  (cost=0.00..12.54 rows=254 width=774) (actual time=0.003..0.093 rows=254 loops=1)
   ->  Seq Scan on "QualifiedEntity"  (cost=0.00..11.00 rows=100 width=744) (actual time=0.009..0.009 rows=0 loops=1)
***/

SELECT resolution('rim2011', 'Role'          , '{{Participation,role}}');
SELECT resolution('rim2011', 'LicensedEntity', '{{Participation,role}}');
SELECT resolution('rim2011', 'Patient'       , '{{Participation,role}}');

DELETE FROM stream.append_id
WHERE schema_name = 'rim2011'
AND   table_name IN ('ActRelationship','Act','Observation','ControlAct','Participation','Document');

VACUUM stream.append_id;