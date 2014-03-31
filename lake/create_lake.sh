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

pgcommand() {
    psql -a --host $PG_HOST --port $PG_PORT $1 --user $PG_USER -c "$2" || fail "could not $2"
}

pgext2sql() {
    echo "Manually loading extension $2"
    EXTDIR=$(pg_config --sharedir)/extension
    cat ${EXTDIR}/$2 | sed 's/MODULE_PATHNAME/\$libdir\/hl7/g' | PGOPTIONS='--client-min-messages=warning' psql -q1 --host $PG_HOST --port $PG_PORT $1 --user $PG_USER --log-file=log.txt || fail "could not load SQL script from extension $2, see log.txt"
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

        pgcommand $DBNAME "CREATE EXTENSION hl7basetable"
        pgcommand $DBNAME "CREATE EXTENSION ucum"
        pgcommand $DBNAME "CREATE EXTENSION hl7"
        pgcommand $DBNAME "CREATE EXTENSION adminpack"

        # create 2011 vocabulary: has support for previous RIMs
        pgcommand $DBNAME "CREATE EXTENSION hl7v3vocab_edition2011"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=atomic, public, hl7, pg_hl7, \"\$user\";"

        pgext2sql $DBNAME hl7v3datatypes_r1--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2005"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2005, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql $DBNAME hl7v3rim_edition2005--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2006"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2006, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql $DBNAME hl7v3rim_edition2006--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2008"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2008, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql $DBNAME hl7v3rim_edition2008--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2009"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2009, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql $DBNAME hl7v3rim_edition2009--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2010"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2010, public, hl7, pg_hl7, \"\$user\";"
#        pgext2sql $DBNAME hl7v3rim_edition2010--2.0.sql

#        pgcommand $DBNAME "CREATE SCHEMA rim2011"
#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=rim2011, public, hl7, pg_hl7, \"\$user\";"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public, hl7, pg_hl7, \"\$user\";"
        pgext2sql $DBNAME hl7v3rim_edition2011--2.0.sql
	# In standard PostgreSQL, foreign keys cannot refer to inheritance child relations, so
	# we need to disable these checks.
        pgcommandfromfile $DBNAME "rim_dropforeignkeys.sql"
        # Load term mappings
        pgcommandfromfile $DBNAME "terminology_mapping.sql"

#        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=public, rim2011, rim2010, rim2009, rim2008, rim2006, rim2005, hl7, pg_hl7, \"\$user\";"

        pgcommand $DBNAME "SELECT table_schema,count(*) from information_schema.tables where table_schema like 'rim%' group by table_schema;"

        echo "..Restricting login to owner"
        pgcommand $DBNAME "BEGIN; REVOKE connect ON DATABASE $DBNAME FROM public; GRANT connect ON DATABASE $DBNAME TO $DBNAME; COMMIT;"
        ;;

    *)
        usage
;;
esac

exit 0
