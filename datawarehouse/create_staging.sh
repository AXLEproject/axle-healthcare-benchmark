#!/bin/bash
#
# create_staging.sh
# Creates staging RIM database.
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2013, MGRID BV Netherlands
#
usage() {
    echo "USAGE: $0 <PG_HOST> <PG_PORT> <PG_USER> <DB_NAME> <ACTION> <DWHHOST> <DWHPORT> <DWHDB>"
    echo "e.g.: $0 localhost 5432 m staging create localhost 6543 dwh"
    echo "action is one of drop, create"
    exit 1
}

fail() {
    echo $1
    exit 1
}

if [ $# -lt 8 ]; then
    usage
else
    PG_HOST=$1;
    PG_PORT=$2;
    PG_USER=$3;
    DBNAME=$4;
    ACTION=$5;
    DWHHOST=$6;
    DWHPORT=$7;
    DWHDB=$8
fi

PSQL="psql --host ${PG_HOST} --port ${PG_PORT} --user ${PG_USER}"

pgcommand() {
    ${PSQL} --dbname $1 -c "$2" || fail "could not $2"
}

pgcommandfromfile() {
    echo "executing commands from file $2"
    ${PSQL} --dbname $1 -f $2 || fail "error while executing commands from $2"
}

case "${ACTION}" in
    drop)
        echo "..Dropping database and owner role"
        pgcommand postgres "DROP DATABASE IF EXISTS $DBNAME"
        pgcommand postgres "DROP USER IF EXISTS $DBNAME"
        ;;

    create)
        echo "..Creating owner role and database"
        pgcommand postgres "CREATE USER $DBNAME"
        pgcommand postgres "CREATE DATABASE $DBNAME"

        echo "..Loading modules"
        pgcommand $DBNAME "CREATE EXTENSION dblink"
        pgcommand $DBNAME "CREATE EXTENSION hl7basetable"
        pgcommand $DBNAME "CREATE EXTENSION ucum"
        pgcommand $DBNAME "CREATE EXTENSION hl7"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3vocab_edition2011"
        pgcommand $DBNAME "CREATE SCHEMA etl"
        pgcommand $DBNAME "CREATE SCHEMA staging_rim2011"
        pgcommand $DBNAME "CREATE SCHEMA view_snomed_tree"
        pgcommand $DBNAME "CREATE SCHEMA view_templates"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public,hl7_composites,pg_hl7,hl7,\"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3datatypes_r1"
        pgcommand $DBNAME "CREATE EXTENSION snomedctvocab_20110731"
        pgcommand $DBNAME "CREATE EXTENSION loinc_2_42"
        # We want the RIM to be in schema 'staging_rimxxx' instead of 'public'."
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=staging_rim2011,public,hl7_composites,pg_hl7,hl7,\"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3rim_edition2011"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3crud_edition2011"
        pgcommand $DBNAME "CREATE EXTENSION bp"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3_c_block_contextconduction_edition2011"
	# In standard PostgreSQL, foreign keys cannot refer to inheritance child relations, so
	# we need to disable these checks.
        pgcommandfromfile $DBNAME "rim_dropforeignkeys.sql"

        echo ".. Creating ETL support tables, views and indexes"
        # To transform to the dwh format, the staging database has a copy of
        # the datawarehouse tables. To keep things organized, we load the dwh
        # tables in the schema etl.
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=etl,staging_rim2011,public,hl7_composites,pg_hl7,hl7,\"\$user\";"
        # Load term mappings
        pgcommandfromfile $DBNAME "terminology_mapping.sql"
        pgcommandfromfile $DBNAME ddl-tab-dwh.sql

        sed -e "s/_DWHHOST_/${DWHHOST}/" \
            -e "s/_DWHNAME_/${DWHDB}/" \
            -e "s/_DWHPORT_/${DWHPORT}/" \
            ddl-tab-staging.sql | ${PSQL} -q --dbname ${DBNAME}

        echo ".. Creating ETL functions"
        pgcommandfromfile $DBNAME ddl-etl-functions.sql
        # Finally set the search_path to the final setup
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public,etl,staging_rim2011,view_snomed_tree,view_templates,hl7_composites,pg_hl7,hl7,\"\$user\";"

        echo "..Restricting login to owner"
        pgcommand $DBNAME "BEGIN; REVOKE connect ON DATABASE $DBNAME FROM public; GRANT connect ON DATABASE $DBNAME TO $DBNAME; COMMIT;"
        ;;

    *)
        usage
;;
esac

exit 0
