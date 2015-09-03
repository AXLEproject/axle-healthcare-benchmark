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

pgext2sql() {
    echo "Manually loading extension $2"
    EXTDIR=$(pg_config --sharedir)/extension
    cat ${EXTDIR}/$2 | sed -e 's/MODULE_PATHNAME/\$libdir\/hl7/g' \
        -e 's/PRIMARY KEY,/PRIMARY KEY, _id_cluster BIGINT, _id_extension text[],/g' \
        -e 's/_clonename TEXT,/_clonename TEXT, _pond_timestamp TIMESTAMPTZ, _lake_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, _record_hash TEXT, _record_weight INT,/g' \
        -e 's/"source" BIGINT, "target" BIGINT,/"source" BIGINT, "target" BIGINT, "source_original" BIGINT, "target_original" BIGINT,/g' \
        -e 's/"act" BIGINT, "role" BIGINT,/"act" BIGINT, "role" BIGINT, "act_original" BIGINT, "role_original" BIGINT,/g' \
        -e 's/"player" BIGINT, "scoper" BIGINT,/"player" BIGINT, "scoper" BIGINT, "player_original" BIGINT, "scoper_original" BIGINT,/g' \
        -e '/CREATE TABLE "[[:alpha:]]*Participation"/ {s/_clonename TEXT,/_clonename TEXT, _origin BIGINT,/}' \
        -e 's/"code" "CD",/_code_code TEXT, _code_codesystem TEXT, "code" "CD",/g' \
        -e 's/"value" "ANY",/_value_pq pq,_value_pq_value NUMERIC, _value_pq_unit TEXT,_value_code_code TEXT, _value_code_codesystem TEXT, _value_int INT, _value_real NUMERIC, _value_ivl_real ivl_real, "value" "ANY",/g' \
        -e 's/, "effectiveTime"/, _effective_time_low TIMESTAMPTZ, _effective_time_low_year INT, _effective_time_low_month INT, _effective_time_low_day INT, _effective_time_high TIMESTAMPTZ, _effective_time_high_year INT, _effective_time_high_month INT, _effective_time_high_day INT, "effectiveTime"/g' \
        -e 's/\([^a-z]\)cv\(([^)]\+)\)/\1"CS"\2/gi' \
        -e 's/\([^a-z]CS"*\)([^)]\+)/\1/gi' \
        -e 's/\([^a-z]set"*\)([^)]\+)/\1/gi' \
        | PGOPTIONS='--client-min-messages=warning' ${PSQL} -q1 --dbname $1 --log-file=log.txt || fail "could not load SQL script from extension $2, see log.txt"
}

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
        -e 's/\([^a-z]\)cv\(([^)]\+)\)/\1"CS"\2/gi' \
        -e 's/\([^a-z]CS"*\)([^)]\+)/\1/gi' \
        -e 's/\([^a-z]set"*\)([^)]\+)/\1/gi' \
        -e 's/PRIMARY KEY,/PRIMARY KEY, _id_cluster BIGINT, _id_extension text[],/g' \
        -e 's/_clonename TEXT,/_clonename TEXT, _pond_timestamp TIMESTAMPTZ, _lake_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP, _record_hash TEXT, _record_weight INT,/g' \
        -e 's/"source" BIGINT, "target" BIGINT,/"source" BIGINT, "target" BIGINT, "source_original" BIGINT, "target_original" BIGINT,/g' \
        -e 's/"act" BIGINT, "role" BIGINT,/"act" BIGINT, "role" BIGINT, "act_original" BIGINT, "role_original" BIGINT,/g' \
        -e 's/"player" BIGINT, "scoper" BIGINT,/"player" BIGINT, "scoper" BIGINT, "player_original" BIGINT, "scoper_original" BIGINT,/g' \
        -e '/CREATE TABLE "[[:alpha:]]*Participation"/ {s/_clonename TEXT,/_clonename TEXT, _origin BIGINT,/}' \
        -e 's/ PRIMARY KEY//g' \
        -e 's/ REFERENCES \"[[:alpha:]]*\"//g' \
        -e 's/"code" "CD",/_code_code TEXT, _code_codesystem TEXT, "code" "CD",/g' \
        -e 's/"value" "ANY",/_value_pq pq,_value_pq_value NUMERIC, _value_pq_unit TEXT,_value_code_code TEXT, _value_code_codesystem TEXT, _value_int INT, _value_real NUMERIC, _value_ivl_real ivl_real, "value" "ANY",/g' \
        -e 's/, "effectiveTime"/, _effective_time_low TIMESTAMPTZ, _effective_time_low_year INT, _effective_time_low_month INT, _effective_time_low_day INT, _effective_time_high TIMESTAMPTZ, _effective_time_high_year INT, _effective_time_high_month INT, _effective_time_high_day INT, "effectiveTime"/g' \
        -e '/CREATE TABLE "Act"/ {s/;//}' \
        -e '/CREATE TABLE "Act"/ {a\
WITH (appendonly = false)\
DISTRIBUTED BY (_id);
}' \
        -e '/CREATE TABLE "[[:alpha:]]*"/ {s/ INHERITS (\"Participation\")//}' \
        -e '/CREATE TABLE "Participation"/ {s/ INHERITS (\"[[:alpha:]]*\");//}' \
        -e '/CREATE TABLE "Participation"/ {a\
WITH (appendonly = true, orientation = column, compresslevel = 6)\
DISTRIBUTED BY (act);\
ALTER TABLE "Participation" SET DISTRIBUTED BY (act);
}' \
        -e '/CREATE TABLE "[[:alpha:]]*"/ {s/ INHERITS (\"Observation\")//}' \
        -e '/CREATE TABLE "Observation"/ {s/ INHERITS (\"[[:alpha:]]*\");//}' \
        -e '/CREATE TABLE "Observation"/ {a\
WITH (appendonly = true, orientation = column, compresslevel = 6)\
DISTRIBUTED BY (_id)\
PARTITION BY RANGE (_effective_time_low_year)\
  SUBPARTITION BY RANGE (_effective_time_low_month)\
    SUBPARTITION TEMPLATE (\
      START (1) END (13) EVERY (1),\
      DEFAULT SUBPARTITION other_months )\
  (START (2012) END (2015) EVERY (1),\
   DEFAULT PARTITION other_years );
}' | PGOPTIONS='--client-min-messages=warning' ${PSQL} -q1 --dbname $1 --log-file=log.txt || fail "could not load SQL script from extension $2, see log.txt"
    rm log.txt
}

case "${ACTION}" in
    drop)
        echo "..Dropping database and owner role"
        #pgcommand postgres "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$DBNAME' AND pid <> pg_backend_pid();" || echo ""
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
	# Check that environment matches
	PGV=$(pg_config --version)
	test "x${PGV}" = "xPostgreSQL 8.2.15" || fail "pg_config is not set to Greenplum"

        # Install HDL modules in Greenplum
        # install_hdl includes installation of hl7v3datatypes.sql
        $(pg_config --sharedir)/contrib/install_hdl.sh ${DBNAME} ${PG_PORT} ${PG_HOST} ${PG_USER} || fail "could not install hdl"

        echo "..Creating RIM in schema rim2011"
        pgcommand $DBNAME "CREATE SCHEMA rim2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2011, public, hl7, hdl, r1, \"\$user\";"
        gpext2sql $DBNAME hl7v3rim_edition2011--2.0.sql

else
        # Install HDL modules in PostgreSQL

        pgcommand $DBNAME "CREATE EXTENSION hl7basetable"
        pgcommand $DBNAME "CREATE EXTENSION ucum"
        pgcommand $DBNAME "CREATE EXTENSION hl7"
        pgcommand $DBNAME "CREATE EXTENSION adminpack"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3vocab_edition2011"

        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public, hl7, hdl, r1, \"\$user\";"
        pgcommand $DBNAME "CREATE EXTENSION hl7v3datatypes"

        echo "..Creating RIM in schema rim2011"
        pgcommand $DBNAME "CREATE SCHEMA rim2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2011, public, hl7, hdl, r1, \"\$user\";"
        pgext2sql $DBNAME hl7v3rim_edition2011--2.0.sql
	# In standard PostgreSQL, foreign keys cannot refer to inheritance child relations, so
	# we need to disable these checks.
        pgcommandfromfile $DBNAME "rim_dropforeignkeys.sql"

        # add opaque oid for some observation codes in the synthetic dataset.
        pgcommand $DBNAME "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');"

        pgcommand $DBNAME "SELECT table_schema,count(*) from information_schema.tables where table_schema like 'rim%' group by table_schema;"
        pgcommand $DBNAME "CREATE EXTENSION tablefunc"

        echo "..Installing Quantile, Blocksample and Binning extension for Orange"
        pgcommand $DBNAME "SET search_path TO public; CREATE EXTENSION quantile"
        pgcommand $DBNAME "SET search_path TO public; CREATE EXTENSION binning"
        pgcommand $DBNAME "SET search_path TO public; CREATE EXTENSION blocksample"

        # Add table to collect Participations in for faster entity resolution
        pgcommand $DBNAME "CREATE TABLE \"Participation_in\" (LIKE \"Participation\"); ALTER TABLE \"Participation_in\" inherit \"Participation\";"

        echo "..Create OptOutConsent and LinkActPcpr tables, add RLS policy."
        pgcommandfromfile $DBNAME "auxiliary_tables.sql"
        pgcommandfromfile $DBNAME "observation_opt_out_rls.sql"
        
        echo "..Create blobstore"
        pgcommandfromfile $DBNAME "blobstore.sql"

        echo "..Create research schema and user"
        pgcommandfromfile $DBNAME "create_research_schema.sql"

        pgcommand $DBNAME "CREATE INDEX \"Participation_in_role_idx\" ON rim2011.\"Participation_in\" (role)"
fi

        pgcommand $DBNAME "CREATE INDEX \"Participation_role_idx\" ON rim2011.\"Participation\" (role)"
        pgcommand $DBNAME "CREATE INDEX \"Participation_act_idx\" ON rim2011.\"Participation\" (act)"
        pgcommand $DBNAME "CREATE INDEX \"Observation_code_code_idx\" ON rim2011.\"Observation\" (_code_code)"

        pgcommand $DBNAME "CREATE INDEX \"Role_player_idx\" ON rim2011.\"Role\" (player)"
        pgcommand $DBNAME "CREATE INDEX \"Role_scoper_idx\" ON rim2011.\"Role\" (scoper)"
        pgcommand $DBNAME "CREATE INDEX \"Patient_player_idx\" ON rim2011.\"Patient\" (player)"
        pgcommand $DBNAME "CREATE INDEX \"Patient_scoper_idx\" ON rim2011.\"Patient\" (scoper)"

        echo "..Restricting login to owner"
        pgcommand $DBNAME "BEGIN; REVOKE connect ON DATABASE $DBNAME FROM public; GRANT connect ON DATABASE $DBNAME TO $DBNAME; COMMIT;"

        ;;
    *)
        usage
;;
esac

exit 0
