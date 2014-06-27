/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Entity resolution source procedures
 */


CREATE OR REPLACE FUNCTION resolution_start(
       rimschema text
,      rimtable text
)
RETURNS void AS
$resolution_start$
DECLARE
  number int;
BEGIN

  /* Prevent running the procedure for this table more than once concurrently. */
  PERFORM 1/pg_try_advisory_lock(('"'||rimschema||'"."'||rimtable||'"')::regclass::int)::int;

  CREATE TEMP TABLE _I (
    _id          bigint
  , _id_cluster  bigint
  , dedup_new_id bigint
  )
  ON COMMIT DROP;

  /* select block of added objects */
  EXECUTE $sql$
  CREATE TEMP TABLE _A ON COMMIT DROP AS
    SELECT _id
    ,      _id_cluster
    ,      _record_hash
    ,      _record_weight
    ,      t.id
    ,      "ANYout"(t.id::"ANY")::text AS idtext -- workaround for no hash on udt on gp
    FROM   "$sql$||rimschema||'"."'||rimtable||$sql$" t
    JOIN   stream.append_id i
    ON     i.schema_name    = '$sql$||rimschema||$sql$'
    AND    i.table_name     = '$sql$||rimtable||$sql$'
    AND    t._id            = i.id
   $sql$;

  /* check block against existing clusters */
  EXECUTE $sql$
  CREATE TEMP TABLE _E ON COMMIT DROP AS
    SELECT DISTINCT
      a._id AS _id
    , a._record_hash
    , t._id_cluster
    FROM _A a
    JOIN "$sql$||rimschema||'"."'||rimtable||$sql$" t
    ON   t.id @> a.id
    AND  t._id_cluster IS NOT NULL
  $sql$;
  GET DIAGNOSTICS number = ROW_COUNT;
  RAISE INFO '% records matched against existing clusters', number;

  IF number > 0
  THEN
     PERFORM instructions_for_existing_clusters(rimschema, rimtable);
  END IF;

  /* the remaining are new clusters */
  CREATE TEMP TABLE _N ON COMMIT DROP AS
    SELECT * FROM _A a
    WHERE NOT EXISTS (
      SELECT 1 FROM _E e
      WHERE a._id = e._id
    );

  GET DIAGNOSTICS number = ROW_COUNT;
  RAISE INFO '% new records', number;

  IF number > 0
  THEN
     PERFORM instructions_for_new_clusters(rimschema, rimtable);
  END IF;
END;
$resolution_start$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION instructions_for_existing_clusters(
       rimschema text
,      rimtable text
)
RETURNS void AS
$instructions_for_existing_clusters$
DECLARE
  number int;
BEGIN
  /* _E holds new records with existing cluster id's. */

  /* Add instructions */
  EXECUTE $sql$
  INSERT INTO _I
    SELECT e._id
    ,      e._id_cluster
    ,      t._id AS dedup_new_id
    FROM _E e
    LEFT JOIN "$sql$||rimschema||'"."'||rimtable||$sql$" t
    ON   e._id_cluster = t._id_cluster
    AND  e._record_hash = t._record_hash
  $sql$;

END;
$instructions_for_existing_clusters$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION instructions_for_new_clusters(
       rimschema text
,      rimtable text
)
RETURNS void AS
$instructions_for_new_clusters$
DECLARE
  number int;
BEGIN
  /* _N holds records with new id's */

  /* group the new records for clustering and deduplication  */
  CREATE TEMP TABLE _Gc ON COMMIT DROP AS
    SELECT id, array_agg(_id) AS set__id
    FROM _N
    GROUP BY id;

  /* cluster records */
  CREATE TEMP TABLE _C1 ON COMMIT DROP AS
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

  /* merge clusters */
  CREATE TEMP TABLE _C2 ON COMMIT DROP AS
    SELECT cluster, md5(textin(array_out(cluster))) AS cluster_hash FROM
    (
      SELECT DISTINCT uniq(sort(a.unid || b.unid)) AS cluster
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

  /* select cluster master */
  CREATE TEMP TABLE _Cm ON COMMIT DROP AS
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

  /* Update new records with cluster masters */
  UPDATE _N
  SET _id_cluster = cluster_master
  FROM _Cm
  WHERE ARRAY[_id] <@ cluster;

  UPDATE _N
  SET _id_cluster = _id
  WHERE _id_cluster IS NULL;

  /* Add instructions */
  INSERT INTO _I
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

END;
$instructions_for_new_clusters$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION resolution_execute(
       rimschema   text
,      rimtable    text
,      rimfkeys    text[][]

)
RETURNS void AS
$resolution_execute$
DECLARE
  i   int;
  fk  text;
  fk_orig text;

BEGIN

  /* Update foreign keys */
  FOR i IN array_lower(rimfkeys, 1) .. array_upper(rimfkeys, 1)
  LOOP

    fk := rimfkeys[i][2];
    fk_orig := rimfkeys[i][2] || '_original';

    EXECUTE $sql$
      UPDATE "$sql$||rimschema||'"."'||rimfkeys[i][1]||$sql$" t
      SET    "$sql$||fk||$sql$"         =  i._id_cluster
      ,      "$sql$||fk_orig||$sql$"    =  COALESCE(i.dedup_new_id, "$sql$||fk_orig||$sql$")
      FROM   _I i
      WHERE  i._id                      =  t."$sql$||fk||$sql$"
      AND   (t."$sql$||fk||$sql$"       <> i._id_cluster
      OR     t."$sql$||fk_orig||$sql$"  <> COALESCE(i.dedup_new_id, t."$sql$||fk_orig||$sql$"))
    $sql$;

  END LOOP;

  /* De-dup */
  EXECUTE $sql$
    DELETE FROM "$sql$||rimschema||'"."'||rimtable||$sql$" t
    USING  _I i
    WHERE  t._id          = i._id
    AND    i.dedup_new_id IS NOT NULL
  $sql$;

  /* Set new clusters */
  EXECUTE $sql$
    UPDATE "$sql$||rimschema||'"."'||rimtable||$sql$" t
    SET    _id_cluster = i._id_cluster
    FROM   _I i
    WHERE  t._id       = i._id
    AND    t._id_cluster IS DISTINCT FROM i._id_cluster
  $sql$;

END;
$resolution_execute$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION resolution_end(
       rimschema text
,      rimtable text
)
RETURNS void AS
$resolution_end$
BEGIN
  EXECUTE $sql$
    DELETE FROM stream.append_id i
    WHERE  i.schema_name    = '$sql$||rimschema||$sql$'
    AND    i.table_name     = '$sql$||rimtable||$sql$'
  $sql$;
END;
$resolution_end$
LANGUAGE plpgsql;
