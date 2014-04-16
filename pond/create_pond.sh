#!/bin/bash
#
# create_pond.sh
# Create a pond staging RIM database.
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2013, MGRID BV Netherlands
#
set -e

usage() {
    echo "USAGE: $0 <PG_HOST> <PG_PORT> <PG_USER> <DB_NAME> <ACTION>"
    echo "e.g.: $0 localhost 5432 ${USER} pond1 create"
    echo "action is one of drop, create"
    exit 1
}

fail() {
    echo $1
    exit 1
}

if [ $# -ne 5 ]; then
    usage
else
    PG_HOST=$1;
    PG_PORT=$2;
    PG_USER=$3;
    DBNAME=$4;
    ACTION=$5;
fi

PSQL="psql -v ON_ERROR_STOP=true --host ${PG_HOST} --port ${PG_PORT} --user ${PG_USER}"

pgcommand() {
    ${PSQL} --dbname $1 -c "$2" || fail "could not $2"
}

pgcommandfromfile() {
    echo "executing commands from file $2"
    ${PSQL} --dbname $1 -f $2 || fail "error while executing commands from $2"
}

pgext2sql_unlogged() {
    echo "Manually loading extension $2"
    EXTDIR=$(pg_config --sharedir)/extension
    cat ${EXTDIR}/$2 | sed -e 's/MODULE_PATHNAME/\$libdir\/hl7/g' \
        -e 's/PRIMARY KEY,/PRIMARY KEY, _id_cluster BIGINT,/g' \
        -e 's/_clonename TEXT,/_clonename TEXT, _pond_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, _type_1_hash INT, _type_2_hash INT, _weight INT,/g' \
        -e 's/"source" BIGINT, "target" BIGINT,/"source" BIGINT, "target" BIGINT, "source_original" BIGINT, "target_original" BIGINT,/g' \
        -e 's/"act" BIGINT, "role" BIGINT,/"act" BIGINT, "role" BIGINT, "act_original" BIGINT, "role_original" BIGINT,/g' \
        -e 's/"player" BIGINT, "scoper" BIGINT,/"player" BIGINT, "scoper" BIGINT, "player_original" BIGINT, "scoper_original" BIGINT,/g' \
        -e '/CREATE TABLE "[[:alpha:]]*Participation"/ {s/_clonename TEXT,/_clonename TEXT, _origin BIGINT,/}' \
        -e 's/"value" "ANY",/_value_pq_value NUMERIC, _value_pq_unit TEXT, _value_code_code TEXT, _value_code_codesystem TEXT, "value" "ANY",/g' \
        -e 's/, "effectiveTime"/, _effective_time_low TIMESTAMPTZ, _effective_time_low_year INT, _effective_time_low_month INT, _effective_time_low_day INT, _effective_time_high TIMESTAMPTZ, _effective_time_high_year INT, _effective_time_high_month INT, _effective_time_high_day INT, "effectiveTime"/g' \
        -e 's/CREATE TABLE/CREATE UNLOGGED TABLE/g' \
        -e 's/\([^a-z]\)cs\(([^)]\+)\)/\1cv\2/gi' \
        | PGOPTIONS='--client-min-messages=warning' ${PSQL} -q1 --dbname $1 --log-file=log.txt || fail "could not load SQL script from extension $2, see log.txt"
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

        # Load term mappings (take care not to load in stream or rimxxx)
        pgcommandfromfile $DBNAME "terminology_mapping.sql"

        echo "..Creating stream functions"
        pgcommandfromfile $DBNAME "stream.sql"
        pgcommandfromfile $DBNAME "pond.sql"

        echo "..Creating healthcare modules"
        pgcommand $DBNAME "CREATE EXTENSION hl7basetable"
        pgcommand $DBNAME "CREATE EXTENSION ucum"
        pgcommand $DBNAME "CREATE EXTENSION hl7"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3vocab_edition2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public,pg_hl7,hl7,\"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3datatypes_r1"
        pgcommand $DBNAME "CREATE EXTENSION snomedctvocab_20140131"
        pgcommand $DBNAME "CREATE EXTENSION loinc_2_42"

        echo "..Creating RIM in schema rim2011"
        pgcommand $DBNAME "CREATE SCHEMA rim2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2011, public, hl7, pg_hl7, \"\$user\";"
        pgext2sql_unlogged $DBNAME "hl7v3rim_edition2011--2.0.sql"
        pgext2sql_unlogged $DBNAME "hl7v3crud_edition2011--2.0.sql"
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
