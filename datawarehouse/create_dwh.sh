#!/bin/bash
#
# create_dwh.sh
# Creates a sample RIM data warehouse.
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

        # Dimension tables and fact tables are created in schema atomic
        pgcommand $DBNAME "CREATE SCHEMA atomic"

        # Period-to-date views are created in schema period_to_date
        pgcommand $DBNAME "CREATE SCHEMA period_to_date"
        pgcommand $DBNAME "ALTER DATABASE $DBNAME SET search_path=atomic, period_to_date, public, \"\$user\";"

        echo ".. Creating DWH tables"
        pgcommandfromfile $DBNAME ddl-tab-dwh.sql

        echo ".. Create period_to_date tables"
        pgcommandfromfile $DBNAME ddl-view-period-to-date.sql

        echo "..Restricting login to owner"
        pgcommand $DBNAME "BEGIN; REVOKE connect ON DATABASE $DBNAME FROM public; GRANT connect ON DATABASE $DBNAME TO $DBNAME; COMMIT;"
        ;;

    *)
        usage
;;
esac

exit 0
