/*
 * This file contains the functions that are required to load a datawarehouse from the output files produced
 * by the copy_dwh_tables() function.
 */

/*
 * load_dimension updates a dimension table 3 steps:
 * 1. copying the output file of the copy_dwh_tables() function into a temporary table
 * 2. updating rows in the given dimension table for existing ids (type 1 update)
 * 3. inserting rows in the given dimension table for new ids (type 2 update)
 */
CREATE OR REPLACE FUNCTION load_dimension(in_table_name TEXT)
RETURNS TEXT
AS $$
DECLARE
    sql            TEXT;
    colrec         RECORD;
    first_col      BOOLEAN;
    rows_updated   INTEGER;
    rows_inserted  INTEGER;

BEGIN
    -- drop temp table (if it exist)
    execute 'DROP TABLE IF EXISTS ' || in_table_name || '_temp';

    -- create (new) temp table
    execute 'CREATE TEMPORARY TABLE ' || in_table_name || '_temp AS SELECT * FROM ' || in_table_name  || ' WHERE false';

    -- copy into temp table
    execute 'COPY ' || in_table_name || '_temp FROM '|| '''' || '/tmp/' || in_table_name || '.csv' || '''';

    -- type 1 update from temp table
    sql := 'UPDATE ' || in_table_name ||  ' SET ';
    first_col := TRUE;
    for colrec IN EXECUTE 'SELECT column_name FROM information_schema.columns WHERE table_name = ' || quote_literal(in_table_name) || ' and column_name <> ' || quote_literal('id') LOOP
        IF NOT first_col THEN sql := sql || ',';END IF;
        sql := sql || colrec.column_name || '=' || in_table_name || '_temp.' || colrec.column_name;
        first_col := FALSE;
    end loop;
    sql := sql || ' FROM ' || in_table_name || '_temp WHERE ' || in_table_name || '.id = ' || in_table_name || '_temp.id';
    execute sql;
    get diagnostics rows_updated = ROW_COUNT;

    sql := 'INSERT INTO ' || in_table_name || ' SELECT * FROM ' || in_table_name || '_temp ';
    sql := sql || 'WHERE id NOT IN (SELECT id FROM ' || in_table_name || ')';
    execute sql;
    get diagnostics rows_inserted = ROW_COUNT;
    RETURN in_table_name || ' --> updated: ' || rows_updated || ', rows inserted: ' || rows_inserted;
END; $$ LANGUAGE plpgsql;

/*
 * load_fact loads new facts from an output file produced by copy_dwh_tables()
 * this file should only contain new facts, this is not checked.
 */

CREATE OR REPLACE FUNCTION load_fact(in_table_name TEXT)
RETURNS TEXT
AS $$
DECLARE
    rows_inserted INTEGER;
BEGIN
    execute 'COPY ' || in_table_name || ' FROM ' || '''' || '/tmp/' || in_table_name || '.csv' || '''';
    get diagnostics rows_inserted = ROW_COUNT;
    RETURN in_table_name || ' --> inserted: ' || rows_inserted;
END; $$ LANGUAGE plpgsql;