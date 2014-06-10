/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Entity resolution source procedures
 */


CREATE INDEX "Participation_role_idx" ON "Participation" (role);

CREATE OR REPLACE FUNCTION resolution(
       rimschema   text
,      rimtable    text
,      rimfkeys    text[][]
)
RETURNS void AS
$resolution$
BEGIN
  /* Force error when trying to run resolution on the same table concurrently. */
  PERFORM 1/pg_try_advisory_lock(('"'||rimschema||'"."'||rimtable||'"')::regclass::int)::int;

  IF resolution_start(rimschema, rimtable)
  THEN
    PERFORM resolution_execute(rimschema, rimtable, rimfkeys);
    PERFORM resolution_end(rimschema, rimtable);
  END IF;
END;
$resolution$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION resolution_start(
       rimschema text
,      rimtable text
)
RETURNS bool AS
$resolution_start$
DECLARE
  number int;
  result bool := false;
BEGIN
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
    FROM   ONLY "$sql$||rimschema||'"."'||rimtable||$sql$" t
    JOIN   stream.append_id i
    ON     i.schema_name    = '$sql$||rimschema||$sql$'
    AND    i.table_name     = '$sql$||rimtable||$sql$'
    AND    t._id            = i.id
    LIMIT 1500
   $sql$;

  /* check block against existing clusters */
  EXECUTE $sql$
  CREATE TEMP TABLE _E ON COMMIT DROP AS
    SELECT DISTINCT
      a._id AS _id
    , a._record_hash
    , t._id_cluster
    FROM _A a
    JOIN ONLY "$sql$||rimschema||'"."'||rimtable||$sql$" t
    ON   t.id @> a.id
    AND  t._id_cluster IS NOT NULL
  $sql$;
  GET DIAGNOSTICS number = ROW_COUNT;
  RAISE INFO '% records matched against existing clusters', number;

  IF number > 0
  THEN
     result := true;
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
     result := true;
     PERFORM instructions_for_new_clusters(rimschema, rimtable);
  END IF;

  RETURN result;
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
    LEFT JOIN ONLY "$sql$||rimschema||'"."'||rimtable||$sql$" t
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

  CREATE INDEX _Gci ON _Gc USING GIST(id);

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
      JOIN _C2
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
  i       INT;
  fk      TEXT;
  fk_orig TEXT;
  sta     TEXT[];
  r       RECORD;
BEGIN
  /*
   * Lock exclusively all tables we will update in alphabetic order, to prevent
   * deadlocks with incoming copy streams.
   */
  RAISE INFO 'Executing resolution for %', rimtable;

  SELECT array_agg(schema_table ORDER BY schema_table)
  INTO sta
  FROM alfa_lock_tables(('"'||rimfkeys[1][1]||'"')::regclass,
     '"'||rimschema||'"',
     '"'||rimtable||'"'
    );

  FOR r IN SELECT * FROM unnest(sta)
  LOOP
    BEGIN
      EXECUTE $sql$ LOCK TABLE ONLY $sql$||r.unnest||$sql$ IN ROW EXCLUSIVE MODE $sql$;
      RAISE DEBUG 'Locking table PG %', r.unnest;
    EXCEPTION WHEN OTHERS THEN
      EXECUTE $sql$ LOCK TABLE $sql$||r.unnest||$sql$ IN ROW EXCLUSIVE MODE $sql$;
      RAISE DEBUG 'Locking table GP %', r.unnest;
    END;
  END LOOP;

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
    DELETE FROM ONLY "$sql$||rimschema||'"."'||rimtable||$sql$" t
    USING  _I i
    WHERE  t._id          = i._id
    AND    i.dedup_new_id IS NOT NULL
  $sql$;

  EXECUTE $sql$
    ANALYZE _I; SET random_page_cost to 0.2;
  $sql$;

  /* Set new clusters */
  EXECUTE $sql$
    UPDATE ONLY "$sql$||rimschema||'"."'||rimtable||$sql$" t
    SET    _id_cluster = i._id_cluster
    FROM   _I i
    WHERE  t._id       = i._id
    AND    t._id_cluster IS DISTINCT FROM i._id_cluster
  $sql$;

  EXECUTE $sql$
    SET random_page_cost to default;
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
  /* Mark the records processed */
  EXECUTE $sql$
    DELETE FROM stream.append_id i
    USING  _A a
    WHERE  a._id = i.id;
  $sql$;
END;
$resolution_end$
LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION reflx_trans_inh_childs(oid)
RETURNS SETOF oid AS $$
  SELECT $1
  UNION
  SELECT i.inhrelid
  FROM   pg_catalog.pg_inherits i
  WHERE  i.inhparent            = $1
  UNION
  SELECT reflx_trans_inh_childs(i.inhrelid)
  FROM   pg_catalog.pg_inherits i
  WHERE  i.inhparent            = $1;
$$ LANGUAGE 'sql' STABLE;

CREATE OR REPLACE FUNCTION alfa_lock_tables(
       parentoid  IN  regclass
,      rimschema  IN  text
,      rimtable   IN  text
,      schema_table OUT text
)
RETURNS SETOF text AS $$
  SELECT rimschema || '.' || rimtable FROM (
    SELECT  $2 AS rimschema
    ,       $3 AS rimtable
    UNION
    SELECT  pg_namespace.nspname::text
    ,       regclassout(('"'||pg_class.relname::text||'"')::regclass)::text
    FROM    reflx_trans_inh_childs($1) inh(inhrelid)
    JOIN    pg_catalog.pg_class ON (inh.inhrelid = pg_class.oid)
    JOIN    pg_catalog.pg_namespace ON (pg_class.relnamespace = pg_namespace.oid)
  ) t
  ;
$$ LANGUAGE 'sql' STABLE;

