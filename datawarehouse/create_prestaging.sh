#!/bin/bash
#
# create_prestaging.sh
# Creates a target database for MGRID Messaging parsers.
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2013, MGRID BV Netherlands
#
usage() {
    echo "USAGE: $0 <PG_HOST> <PG_PORT> <PG_USER> <DB_NAME> <ACTION>";
    echo "e.g.: $0 localhost 6042 pvmgrid dwh_eemla create";
    echo "action is one of drop, create";
    exit 1;
}

fail() {
    echo $1
    exit 1
}

pgcommand() {
    psql -a --host $PG_HOST --port $PG_PORT $1 --user $PG_USER -c "$2" || fail "could not $2"
}

pgcommandfromfile() {
    echo "executing commands from file $2"
    psql --host $PG_HOST --port $PG_PORT $1 --user $PG_USER -f $2 || fail "error while executing commands from $2"
}

if [ $# -lt 5 ]; then
    usage
else
    PG_HOST=$1;
    PG_PORT=$2;
    PG_USER=$3;
    DBNAME=$4;
    ACTION=$5;
fi

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
        pgcommand $DBNAME "CREATE EXTENSION hl7basetable"
        pgcommand $DBNAME "CREATE EXTENSION ucum"
        pgcommand $DBNAME "CREATE EXTENSION hl7"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3vocab_edition2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public,hl7_composites,pg_hl7,hl7,\"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3datatypes_r1"
        pgcommand $DBNAME "CREATE EXTENSION snomedctvocab_20110731"
        pgcommand $DBNAME "CREATE EXTENSION loinc_2_42"
        # We want the RIM to be in schema 'prestaging_rimxxx' instead of 'public'."
        pgcommand $DBNAME "CREATE SCHEMA prestaging_rim2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=prestaging_rim2011,public,hl7_composites,pg_hl7,hl7,\"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3rim_edition2011"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3crud_edition2011"
        pgcommand $DBNAME "CREATE EXTENSION bp"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3_c_block_contextconduction_edition2011"
        # In standard PostgreSQL, foreign keys cannot refer to inheritance child relations, so
        # we need to disable these checks.
        pgcommandfromfile $DBNAME "rim_dropforeignkeys.sql"

        echo "..Restricting login to owner"
        pgcommand $DBNAME "BEGIN; REVOKE connect ON DATABASE $DBNAME FROM public; GRANT connect ON DATABASE $DBNAME TO $DBNAME; COMMIT;"
        ;;

    *)
        usage
;;
esac

exit 0
