/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Functions for dealing with parititioned minirims aka data ponds.
 */

/*
 * Set the current start and end value of the pond sequence. This value is
 * retrieved from the grid pool and then used to sequentially mark incoming
 * message fragments. Note that nextval needs to be called at least once for
 * pond_retseq to return a sensible value.
 *
 * Expects a <start>:<end> as text
 * Where start and end are signed int8s
 */
CREATE OR REPLACE FUNCTION pond_setseq(s text) RETURNS void AS
$$
DECLARE
        in_start int8;
        in_end int8;
BEGIN
        in_start := substring(s from '^[-0-9]+')::int8;
        in_end := substring(s from '[-0-9]+$')::int8;

        EXECUTE 'ALTER SEQUENCE '
                || pg_get_serial_sequence('"InfrastructureRoot"', '_id')
                || ' START WITH ' || in_start
                || ' RESTART WITH ' || in_start
                || ' MAXVALUE ' || in_end
                || 'NO CYCLE INCREMENT BY 1';
END
$$ LANGUAGE plpgsql;

/*
 * Retrieve the current start and end value of the pond sequence. This value
 * should be retrieved at the end of a pond-filling action, and should be
 * returned to the grid pool.
 *
 * Returns <start>:<end> as text
 * Where start and end are signed int8s
 *
 * Obstructs the pond sequence for use afterwards to ensure that no inserts
 * happen unsollicited.
 */
CREATE OR REPLACE FUNCTION pond_retseq() RETURNS text AS
$$
DECLARE
        seqname name;
        seqschema name;
        t name;
        result text;
BEGIN
        t := pg_get_serial_sequence('"InfrastructureRoot"', '_id');
        seqname := trim('"' from substring(t from '[^\.]+$'));
        seqschema := substring(t from '^[^\.]+');

        /*
         * Retrieve the current sequence number;
         * - if the sequence is not used at all, call nextval once to retrieve the start value
         * - if the sequence is used, call nextval once to retrieve the last used + 1 value
         * In either case, we need to call nextval once.
         */
        EXECUTE 'SELECT nextval(''' || t || ''')::text || '':'' || maximum_value
          FROM information_schema.sequences
         WHERE sequence_name = ''' || seqname || '''
           AND sequence_schema = ''' || seqschema || ''''
        INTO result;

        /* Ensure no new records can be inserted after we are through */
        PERFORM pond_setseq('0:0');
        EXECUTE 'SELECT nextval(''' || t || ''')';
	RETURN result;
END
$$ LANGUAGE plpgsql;

/*
 * Utility to determine all tables that need to be dumped;
 * - all relations in public
 * - that are true tables
 * - have an _id attribute
 * - are visible
 */
CREATE OR REPLACE FUNCTION pond_tables()
RETURNS TABLE (sname name) AS
$$
BEGIN
        RETURN QUERY
        SELECT c.relname as sname
          FROM pg_catalog.pg_class c
     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
     LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
         WHERE c.relkind = 'r'
           AND n.nspname = 'public'
           AND a.attname = '_id'
           AND pg_catalog.pg_table_is_visible(c.oid)
      ORDER BY 1;
END
$$ LANGUAGE plpgsql;

/*
 * Determine all ids that were inserted into this pond, and store them in
 * dwhupload.<rimtablename>.
 *
 * The dwhupload schema can then be used at the dwh/datalake side to
 * determine the new _ids that are to be acted on.
 */
CREATE OR REPLACE FUNCTION pond_recordids() RETURNS int AS
$$
DECLARE
        tblname name;
        total int;
        current int;
BEGIN
        DROP SCHEMA IF EXISTS pond CASCADE;
        CREATE SCHEMA pond;

        total := 0;

        FOR tblname IN SELECT pond_tables()
        LOOP
                EXECUTE 'CREATE TABLE pond."' || tblname || '" AS SELECT _id FROM ONLY "' || tblname || '"';
                GET DIAGNOSTICS current = ROW_COUNT;
                total := total + current;
        END LOOP;
        RETURN total;
END
$$ LANGUAGE plpgsql;

/*
 * Empty pond. After all the local data has been streamed into the datalake,
 * the local pond is stale and needs to be emptied in preparation for a new set of
 * messages to be loaded.
 */
CREATE OR REPLACE FUNCTION pond_empty() RETURNS int AS
$$
DECLARE
        tblname name;
        total int;
        current int;
BEGIN
        DROP SCHEMA IF EXISTS pond CASCADE;
        total := 0;

        FOR tblname IN SELECT pond_tables()
        LOOP
                EXECUTE 'TRUNCATE TABLE "' || tblname || '" CASCADE';
                GET DIAGNOSTICS current = ROW_COUNT;
                total := total + current;
        END LOOP;
        RETURN total;
END
$$ LANGUAGE plpgsql;

/*
 * The set of ddl statements that need to be issued on a dwh to be able to
 * ingest a pond update
 */
CREATE OR REPLACE FUNCTION pond_ddl() RETURNS text AS
$$
DECLARE
        rt text;
        tblname name;
BEGIN
        rt := 'CREATE SCHEMA IF NOT EXISTS pond;';
        FOR tblname IN SELECT pond_tables()
        LOOP
                rt := rt || 'CREATE TABLE IF NOT EXISTS pond."' || tblname || '" (_id bigint);';
        END LOOP;
        RETURN rt;
END
$$ LANGUAGE plpgsql;

