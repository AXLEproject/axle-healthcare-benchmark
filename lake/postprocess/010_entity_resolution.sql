/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Post processing on the lake.
 */

/* Patient entity resolution */

/* Prevent running this script more than once concurrently. */
\timing
SELECT 1/pg_try_advisory_lock('"Patient"'::regclass::int)::int;

BEGIN;

/* select block of added objects */

CREATE TEMP TABLE _A AS
  SELECT _id
  ,      _id_cluster
  ,      _record_hash
  ,      _record_weight
  ,      id
  ,      "ANYout"(id::"ANY")::text AS idtext -- workaround for no hash on udt on gp
  FROM "Patient" p
/**  JOIN stream.append_id i
  ON i.schema_name='rim2011'
  AND i.table_name='Patient'
  AND p._id = i.id
LIMIT 5;
**/
 WHERE _id > 0;
/* check block against existing clusters */

/* the remaining are new clusters */

CREATE TEMP TABLE _N AS
  SELECT * FROM _A;

/* group the new records for clustering and deduplication  */

CREATE TEMP TABLE _Gc AS
  SELECT id, array_agg(_id) AS set__id
  FROM _N
  GROUP BY id;

/* cluster records */
CREATE TEMP TABLE _C1 AS
  SELECT a.id AS id_a
  ,      b.id AS id_b
  ,      a.set__id AS set__id_a
  ,      b.set__id AS set__id_b
  ,      a.set__id || b.set__id AS unid
  FROM _Gc a
  JOIN _Gc b
  ON   a.id @> b.id -- change to && when implemented
  AND  a.id <> b.id
  UNION ALL
  SELECT a.id AS id_a
  ,      NULL
  ,      a.set__id AS set__id_a
  ,      NULL
  ,      a.set__id  AS unid
  FROM _Gc a
  LEFT JOIN _Gc b
  ON   a.id @> b.id -- change to && when implemented
  AND  a.id <> b.id
  WHERE b.id IS NULL
;

SELECT unid FROM _C1;

/* merge clusters */
CREATE TEMP TABLE _C2 AS
SELECT cluster, md5(textin(array_out(cluster))) AS cluster_hash FROM
(
 SELECT DISTINCT uniq(sort((a.unid || b.unid)::int[]))::bigint[] AS cluster
 FROM _C1 a
 JOIN _C1 b
 ON a.unid && b.unid
 AND a.unid <> b.unid
 UNION ALL
 SELECT a.unid FROM _C1 a
 LEFT JOIN _C1 b
 ON a.unid && b.unid
 AND a.unid <> b.unid
 WHERE b.unid IS NULL
) distinct_cluster
;

SELECT * FROM _C2;

/* select cluster master */

CREATE TEMP TABLE _Cm AS
SELECT * FROM
(
SELECT _id AS cluster_master
,       _record_hash
,       _record_weight
,       cluster
,       cluster_hash
,      rank() OVER (mywindow) AS rank
FROM _N
JOIN (SELECT * FROM _C2 LIMIT 8) _C2
ON ARRAY[_N._id] <@ _C2.cluster
WINDOW mywindow AS (PARTITION BY cluster_hash
                    ORDER BY _record_weight DESC)
) master
WHERE rank = 1
;

SELECT * FROM _Cm;

/* Update new records with cluster masters */

UPDATE _N
SET _id_cluster = cluster_master
FROM _Cm
WHERE ARRAY[_id] <@ cluster;

UPDATE _N
SET _id_cluster = _id
WHERE _id_cluster IS NULL;

/* Create instruction table for de-duplication */

CREATE TEMP TABLE _I AS
SELECT _id
,      _id_cluster
,      CASE WHEN rank() OVER (mywindow) = 1
       THEN NULL
       ELSE
       first_value(_id) OVER (mywindow)
       END  AS dedup_new_id
FROM _N
WINDOW mywindow AS (PARTITION BY _id_cluster, _record_hash
                    ORDER BY _record_weight DESC, _id ASC)
;

SELECT * FROM _I;

SELECT role, role_original
from "Participation" p
join _I i
ON   i._id = p.role;

/* Update foreign keys */
UPDATE "Participation" p
SET    role            = i._id_cluster
,      role_original   = COALESCE(i.dedup_new_id, role_original)
FROM   _I i
WHERE  i._id           = p.role
AND   (p.role          <> i._id_cluster
OR     p.role_original <> COALESCE(i.dedup_new_id, p.role_original))
;

SELECT role, role_original
from "Participation" p
join _I i
ON   i._id = p.role;

/* De-dup patient */
DELETE FROM "Patient" p
USING  _I i
WHERE  p._id          = i._id
AND    i.dedup_new_id IS NOT NULL;

/* Set patient clusters */
UPDATE "Patient"   p
SET    _id_cluster = i._id_cluster
FROM   _I i
WHERE  p._id       = i._id
AND    p._id_cluster <> i._id_cluster;

COMMIT;
