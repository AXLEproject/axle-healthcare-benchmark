#!/bin/bash
#
# createdb_sensors.sh
#
# Creates a database to receive sensor data in, and
# templates for converting to CDA.
#
# Copyright (c) 2013, Portavita BV Netherlands
#


usage() {
    echo "USAGE: $0 <PG_HOST> <PG_PORT> <PG_USER> <DB_NAME> <CDAOUTPUTDIR> <ACTION>"
    echo "e.g.: $0 localhost 5432 m sensor output create"
    exit 1
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
    CDAOUTPUTDIR=$5;
    ACTION=$6;
fi

PWD=`pwd`
OUTPUTDIR=${PWD}/${CDAOUTPUTDIR}
PWD_ESC=`echo ${PWD} | sed 's/\//\\\\\//g'`
OUTPUTDIR_ESC=`echo ${OUTPUTDIR} | sed 's/\//\\\\\//g'`

mkdir -p ${OUTPUTDIR}


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
        echo "..Dropping role and database"
        pgcommand postgres "DROP DATABASE IF EXISTS $DBNAME"
        pgcommand postgres "DROP USER IF EXISTS $DBNAME"
        ;;

    create)
        echo "..Creating role and database"
        pgcommand postgres "CREATE USER $DBNAME"
        pgcommand postgres "CREATE DATABASE $DBNAME"
        sed -e "s/_OUTPUTDIR_/${OUTPUTDIR_ESC}/" \
            -e "s/_TEMPLATEDIR_/${PWD_ESC}/" \
            sensor_map.sql | ${PSQL} -q --dbname ${DBNAME}
        ;;

    *)
        usage
;;
esac


cat <<EOF

EOF

exit 0

