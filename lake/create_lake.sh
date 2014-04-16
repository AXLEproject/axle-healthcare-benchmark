#!/bin/bash
#
# create_lake.sh
#
# Creates a RIM based data warehouse.
#
# This file is part of the axle-healthcare-benchmark.
#
# Copyright (c) 2014, MGRID BV Netherlands
#
usage() {
    echo "USAGE: $0 <PG_HOST> <PG_PORT> <PG_USER> <DB_NAME> <ACTION>";
    echo "action is one of drop, create";
    exit 1;
}

fail() {
    echo $1
    exit 1
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

PSQL="psql -v ON_ERROR_STOP=true --host ${PG_HOST} --port ${PG_PORT} --user ${PG_USER}"

pgcommand() {
    ${PSQL} --dbname $1 -a -c "$2" || fail "could not $2"
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
        -e 's/_clonename TEXT,/_clonename TEXT, _pond_timestamp TIMESTAMPTZ, _lake_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, _type_1_hash INT, _type_2_hash INT, _weight INT,/g' \
        -e 's/"source" BIGINT, "target" BIGINT,/"source" BIGINT, "target" BIGINT, "source_original" BIGINT, "target_original" BIGINT,/g' \
        -e 's/"act" BIGINT, "role" BIGINT,/"act" BIGINT, "role" BIGINT, "act_original" BIGINT, "role_original" BIGINT,/g' \
        -e 's/"player" BIGINT, "scoper" BIGINT,/"player" BIGINT, "scoper" BIGINT, "player_original" BIGINT, "scoper_original" BIGINT,/g' \
        -e '/CREATE TABLE "[[:alpha:]]*Participation"/ {s/_clonename TEXT,/_clonename TEXT, _origin BIGINT,/}' \
        -e 's/"value" "ANY",/_value_pq_value NUMERIC, _value_pq_unit TEXT, _value_code_code TEXT, _value_code_codesystem TEXT, "value" "ANY",/g' \
        -e 's/, "effectiveTime"/, _effective_time_low TIMESTAMPTZ, _effective_time_low_year INT, _effective_time_low_month INT, _effective_time_low_day INT, _effective_time_high TIMESTAMPTZ, _effective_time_high_year INT, _effective_time_high_month INT, _effective_time_high_day INT, "effectiveTime"/g' \
        -e 's/CREATE TABLE/CREATE UNLOGGED TABLE/g' \
        | PGOPTIONS='--client-min-messages=warning' ${PSQL} -q1 --dbname $1 --log-file=log.txt || fail "could not load SQL script from extension $2, see log.txt"
}

# WITH (appendonly = true, orientation = column, compresslevel = 9)\

gpext2sql() {
    echo "Manually loading extension $2"
    EXTDIR=$(pg_config --sharedir)/contrib
    cat ${EXTDIR}/$2 | sed -e 's/MODULE_PATHNAME/\$libdir\/hl7/g' \
        -e 's/, TYPMOD_.*$//g' \
        -e 's/, MERGES//g' \
        -e 's/^COST[ 0-9]\+$//g' \
        -e '/CREATE OPERATOR CLASS "*gin_/,/;$/d' \
        -e '/DELETE FROM pg_depend/,/;$/d' \
        -e '/ALTER TABLE/d' \
        -e '/SELECT __warn_extension_deps_removal/,/;$/d' \
        -e 's/\([^a-z]cv"*\)([^)]\+)/\1/gi' \
        -e 's/\([^a-z]cs"*\)([^)]\+)/\1/gi' \
        -e 's/\([^a-z]set"*\)([^)]\+)/\1/gi' \
        -e 's/PRIMARY KEY,/PRIMARY KEY, _id_cluster BIGINT,/g' \
        -e 's/_clonename TEXT,/_clonename TEXT, _pond_timestamp TIMESTAMPTZ, _lake_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, _type_1_hash INT, _type_2_hash INT, _weight INT,/g' \
        -e 's/"source" BIGINT, "target" BIGINT,/"source" BIGINT, "target" BIGINT, "source_original" BIGINT, "target_original" BIGINT,/g' \
        -e 's/"act" BIGINT, "role" BIGINT,/"act" BIGINT, "role" BIGINT, "act_original" BIGINT, "role_original" BIGINT,/g' \
        -e 's/"player" BIGINT, "scoper" BIGINT,/"player" BIGINT, "scoper" BIGINT, "player_original" BIGINT, "scoper_original" BIGINT,/g' \
        -e '/CREATE TABLE "[[:alpha:]]*Participation"/ {s/_clonename TEXT,/_clonename TEXT, _origin BIGINT,/}' \
        -e 's/ INHERITS (\"[[:alpha:]]*\")//g' \
        -e 's/ PRIMARY KEY//g' \
        -e 's/ REFERENCES \"[[:alpha:]]*\"//g' \
        -e 's/"value" "ANY",/_value_pq_value NUMERIC, _value_pq_unit TEXT, _value_code_code TEXT, _value_code_codesystem TEXT, "value" "ANY",/g' \
        -e 's/, "effectiveTime"/, _effective_time_low TIMESTAMPTZ, _effective_time_low_year INT, _effective_time_low_month INT, _effective_time_low_day INT, _effective_time_high TIMESTAMPTZ, _effective_time_high_year INT, _effective_time_high_month INT, _effective_time_high_day INT, "effectiveTime"/g' \
        -e '/CREATE TABLE "Act"/ {s/;//}' \
        -e '/CREATE TABLE "Act"/ {a\
WITH (appendonly = false)\
DISTRIBUTED BY (_id);
}' \
        -e '/CREATE TABLE "Participation"/ {s/;//}' \
        -e '/CREATE TABLE "Participation"/ {a\
WITH (appendonly = true, orientation = column, compresslevel = 6)\
DISTRIBUTED BY (act);
}' \
        -e '/CREATE TABLE "Observation"/ {s/;//}' \
        -e '/CREATE TABLE "Observation"/ {a\
WITH (appendonly = true, orientation = column, compresslevel = 6)\
DISTRIBUTED BY (_id)\
PARTITION BY RANGE (_effective_time_low_year)\
  SUBPARTITION BY RANGE (_effective_time_low_month)\
    SUBPARTITION TEMPLATE (\
      START (1) END (13) EVERY (1),\
      DEFAULT SUBPARTITION other_months )\
  (START (2008) END (2016) EVERY (1),\
   DEFAULT PARTITION other_years );
}' | PGOPTIONS='--client-min-messages=warning' ${PSQL} -q1 --dbname $1 --log-file=log.txt || fail "could not load SQL script from extension $2, see log.txt"
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

        echo "..Creating stream info"
        pgcommandfromfile $DBNAME "stream.sql"

        echo "..Creating healthcare modules"

GP=`psql -tA --host $PG_HOST --port $PG_PORT $DBNAME --user $PG_USER -c "select version() like '%reenplum%'"` || fail "could not query database version"
if [ "x${GP}" = "xt" ];
then
        # Install HDL modules in Greenplum
        # install_hdl includes installation of hl7v3datatypes_r1--2.0.sql
        pushd /home/m/mgrid-hdl/greenplum ; ./install_hdl.sh ${DBNAME} ${PG_PORT} ${PG_HOST} ${PG_USER} || fail "could not install hdl"
        popd

        echo "..Creating RIM in schema rim2011"
        pgcommand $DBNAME "CREATE SCHEMA rim2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2011, public, hl7, pg_hl7, \"\$user\";"
        gpext2sql $DBNAME hl7v3rim_edition2011--2.0.sql
else
        pgcommand $DBNAME "CREATE EXTENSION hl7basetable"
        pgcommand $DBNAME "CREATE EXTENSION ucum"
        pgcommand $DBNAME "CREATE EXTENSION hl7"
        pgcommand $DBNAME "CREATE EXTENSION adminpack"
        # Vocabulary 2011 has support for previous editions
        pgcommand $DBNAME "CREATE EXTENSION hl7v3vocab_edition2011"

        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public, hl7, pg_hl7, \"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3datatypes_r1"

        pgcommand $DBNAME "CREATE SCHEMA rim2005"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2005, public, hl7, pg_hl7, \"\$user\";"
        pgext2sql_unlogged $DBNAME hl7v3rim_edition2005--2.0.sql

        pgcommand $DBNAME "CREATE SCHEMA rim2006"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2006, public, hl7, pg_hl7, \"\$user\";"
        pgext2sql_unlogged $DBNAME hl7v3rim_edition2006--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2008"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2008, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql_unlogged $DBNAME hl7v3rim_edition2008--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2009"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2009, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql_unlogged $DBNAME hl7v3rim_edition2009--2.0.sql

        pgcommand $DBNAME "CREATE SCHEMA rim2010"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2010, public, hl7, pg_hl7, \"\$user\";"
        pgext2sql_unlogged $DBNAME hl7v3rim_edition2010--2.0.sql

        echo "..Creating RIM in schema rim2011"
        pgcommand $DBNAME "CREATE SCHEMA rim2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2011, public, hl7, pg_hl7, \"\$user\";"
        pgext2sql_unlogged $DBNAME hl7v3rim_edition2011--2.0.sql
	# In standard PostgreSQL, foreign keys cannot refer to inheritance child relations, so
	# we need to disable these checks.
        pgcommandfromfile $DBNAME "rim_dropforeignkeys.sql"

        pgcommand $DBNAME "SELECT table_schema,count(*) from information_schema.tables where table_schema like 'rim%' group by table_schema;"
fi

#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public, rim2011, rim2010, rim2009, rim2008, rim2006, rim2005, hl7, pg_hl7, \"\$user\";"

        echo "..Restricting login to owner"
        pgcommand $DBNAME "BEGIN; REVOKE connect ON DATABASE $DBNAME FROM public; GRANT connect ON DATABASE $DBNAME TO $DBNAME; COMMIT;"
        ;;

    *)
        usage
;;
esac

exit 0
