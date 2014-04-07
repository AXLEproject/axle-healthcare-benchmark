/*
 * (c) 2014 MGRID B.V.
 * All rights reserved
 *
 * Metadata about which tables and id's are streamed to the lake.
 */

CREATE SCHEMA stream;

/*
 * This table contains new id's streamed by the ponds.
 */
CREATE TABLE stream.append_id
(
        schema_name     text,
        table_name      text,
        id              bigint
);


/*
 * View that returns all tables that will be uploaded to the lake:
 * - all tables in rim* schemas
 */
CREATE OR REPLACE VIEW stream.table
AS
        SELECT table_schema,
               table_name,
               EXISTS (SELECT *
                         FROM information_schema.columns c
                        WHERE c.table_schema = t.table_schema
                          AND c.table_name = t.table_name
                          AND c.column_name = '_id') AS has_id
          FROM information_schema.tables t
         WHERE table_schema LIKE 'rim%'
           AND table_type = 'BASE TABLE'
      ORDER BY table_schema, table_name;
