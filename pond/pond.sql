/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Functions for dealing with parititioned minirims aka data ponds.
 */


/*
 * Initialize the pond. Takes a sequence and hostname.
 *
 * The sequence is retrieved from the grid pool and then used to sequentially mark incoming
 * message fragments.
  *
 * seq expects a <start>:<end> as text where start and end are signed int8s
 * hostname is the FQDN of the pond node.
 */
CREATE OR REPLACE FUNCTION pond_init(seq text, hostname text) RETURNS void AS
$$
DECLARE
        in_start int8;
        in_end int8;
BEGIN
        IF EXISTS (SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'pond') THEN
          RAISE 'Pond already initialized';
        END IF;

        CREATE SCHEMA pond;

        in_start := substring(seq from '^[-0-9]+')::int8;
        in_end := substring(seq from '[-0-9]+$')::int8;

        PERFORM pond_setseq(in_start, in_end);
        PERFORM pond_setinfo(in_start, in_end, hostname);
END
$$ LANGUAGE plpgsql;

/*
 * Check whether the pond is ready for loading. True if pond schema exists, created by pond_init().
 */
CREATE OR REPLACE FUNCTION pond_ready() RETURNS boolean AS
$$
BEGIN
        RETURN EXISTS (SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'pond');
END
$$ LANGUAGE plpgsql;

/*
 * Set pond information. Creates pond table with administrative info.
 */
CREATE OR REPLACE FUNCTION pond_setinfo(seqstart bigint, seqend bigint, hostname text) RETURNS void AS
$$
BEGIN
        EXECUTE 'CREATE TABLE IF NOT EXISTS pond."_Info" (ts timestamp, hostname text, seqstart bigint, seqend bigint)';

        EXECUTE 'INSERT INTO pond."_Info" VALUES (now(), ''' || hostname || ''', ' || seqstart || ', ' || seqend || ')';
END
$$ LANGUAGE plpgsql;

/*
 * Set the current start and end value of the pond sequence. Note that 
 * nextval needs to be called at least once for
 * pond_retseq to return a sensible value.
 *
 */
CREATE OR REPLACE FUNCTION pond_setseq(in_start bigint, in_end bigint) RETURNS void AS
$$
BEGIN
        EXECUTE 'ALTER SEQUENCE '
                || pg_get_serial_sequence('"InfrastructureRoot"', '_id')
                || ' START WITH ' || in_start
                || ' RESTART WITH ' || in_start
                || ' MINVALUE ' || in_start
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
 *
 * Drops pond schema to invalidate pond (pond_init has to be called again).
 */
CREATE OR REPLACE FUNCTION pond_retseq() RETURNS text AS
$$
DECLARE
        seqname name;
        seqschema name;
        t name;
        result text;
BEGIN
        IF NOT EXISTS (SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'pond') THEN
          RAISE 'Pond not yet initialized';
        END IF;

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

        /*
         * Ensure no new records can be inserted after we are through by
         * exhausting all values from the sequence.
         */
        PERFORM pond_setseq(1, 2);
        EXECUTE 'SELECT nextval(''' || t || ''')';
        EXECUTE 'SELECT nextval(''' || t || ''')';

        /* Remove stored pond info as retseq() renders it invalid */
        DROP SCHEMA IF EXISTS pond CASCADE;

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
CREATE OR REPLACE VIEW pond_tables
AS
        SELECT c.relname as sname
          FROM pg_catalog.pg_class c
          JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
         WHERE c.relkind = 'r'
           AND n.nspname = 'public'
           AND a.attname = '_id'
           AND pg_catalog.pg_table_is_visible(c.oid)
      ORDER BY 1;

/*
 * Determine all ids that were inserted into this pond, and store them in
 * pond.<rimtablename>.
 *
 * The pond schema can then be used at the lake side to
 * determine the new _ids that are to be acted on.
 */
CREATE OR REPLACE FUNCTION pond_recordids() RETURNS int AS
$$
DECLARE
        tblname name;
        total int;
        current int;
BEGIN
        total := 0;

        FOR tblname IN SELECT * FROM pond_tables
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
        total := 0;

        FOR tblname IN SELECT * FROM pond_tables
        LOOP
                EXECUTE 'DROP TABLE IF EXISTS pond."' || tblname || '"';
                EXECUTE 'TRUNCATE TABLE "' || tblname || '" CASCADE';
                GET DIAGNOSTICS current = ROW_COUNT;
                total := total + current;
        END LOOP;
        RETURN total;
END
$$ LANGUAGE plpgsql;

/*
 * The set of ddl statements that need to be issued on a lake to be able to
 * ingest a pond update. Should be pre-loaded on lake.
 */
CREATE OR REPLACE FUNCTION pond_ddl() RETURNS text AS
$$
DECLARE
        rt text;
        tblname name;
        seq_start int8;
        seq_end int8;
BEGIN
        seq_start := -9223372036854775808;
        seq_end := 9223372036854775807;

        rt := 'CREATE SCHEMA IF NOT EXISTS pond;';

        rt := rt || 'ALTER SEQUENCE "InfrastructureRoot__id_seq"'
                 || ' START WITH ' || seq_start
                 || ' RESTART WITH ' || seq_start
                 || ' MINVALUE ' || seq_start
                 || ' MAXVALUE ' || seq_end
                 || ' NO CYCLE INCREMENT BY 1;';

        rt := rt || 'CREATE TABLE IF NOT EXISTS pond."_Info" (ts timestamp, hostname text, seqstart bigint, seqend bigint);';

        FOR tblname IN SELECT * FROM pond_tables
        LOOP
                rt := rt || 'CREATE TABLE IF NOT EXISTS pond."' || tblname || '" (_id bigint);';
        END LOOP;
        RETURN rt;
END
$$ LANGUAGE plpgsql;

