#!/bin/bash
#
# runone.sh
# Run a single query, no profiling.
#
# This file is part of the AXLE Healthcare Benchmark.
#
# Copyright (c) 2015, Portavita BV Netherlands
#
set -e
BASEDIR="$(pwd)/database"

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ./default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash
source /tmp/default_settings_bash

PGBINDIR=${PGSERVER}/bin
PGDATADIR=${PGDATA}
PGPORT=${LAKEPORT}
PGUSER=${USER}
SUDO=/usr/bin/sudo

usage() {
    echo "USAGE: $0 <QUERY> <DWHDB> <PERFDATADIR>"
    echo "e.g. $0 1 lake perfresults"
    exit 1
}

fail() {
    echo $1
    exit 1
}

# Restart and drop caches
restart_drop_caches() {
    echo "Restart postgres and drop caches."
    ${SUDO} -u $PGUSER $PGBINDIR/pg_ctl stop -D $PGDATADIR
    sync && echo 3 | ${SUDO} tee /proc/sys/vm/drop_caches
    ${SUDO} -u $PGUSER taskset -c 2 $PGBINDIR/postgres -D "$PGDATADIR" -p $PGPORT &
    PGPID=$!
    while ! ${SUDO} -u $PGUSER $PGBINDIR/pg_ctl status -D $PGDATADIR | grep "server is running" -q; do
        echo "Waiting for the Postgres server to start"
        sleep 3
    done
}

BASEDIR=$(dirname "$0")
BASEDIR=$(cd "$BASEDIR"; pwd)

if [ $# -lt 3 ]; then
    usage
else
    QUERY=$(printf "%02d" $1)
    PWD=`pwd`
    DWHDB=$2;
    PERFDATADIR=$3;
fi

test "${PGDATADIR:0:1}" == "/" || PGDATADIR="$PWD/$PGDATADIR"

DB_NAME=${DWHDB}

### Query to be executed
f=`ls queries/${QUERY}_*.sql`

Q=`mktemp`
echo "set search_path to rim2011, public, hl7, hdl, r1;" | cat - "$BASEDIR/$f" > $Q

## Start a new instance of Postgres
${SUDO} -u $PGUSER taskset -c 2 $PGBINDIR/postgres -D "$PGDATADIR" -p $PGPORT &
PGPID=$!
while ! ${SUDO} -u $PGUSER $PGBINDIR/pg_ctl status -D $PGDATADIR | grep "server is running" -q; do
  echo "Waiting for the Postgres server to start"
  sleep 1
done

# wait for it to finish starting
sleep 5
echo "Postgres running"

# Get size
SIZE=`$PGBINDIR/psql -p $PGPORT -d $DB_NAME -tAc "select pg_size_pretty(pg_database_size('${DB_NAME}'));"`

dir="$PERFDATADIR/${QUERY}"
mkdir -p $dir
cd "$dir"

### Get execution time cold
/usr/bin/time -f '%e\n%Uuser %Ssystem %Eelapsed %PCPU (%Xtext+%Ddata %Mmax)k'\
    -o exectime.txt \
    $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME < $Q 2> exectime.txt

## Warm execution time
/usr/bin/time -f '%e\n%Uuser %Ssystem %Eelapsed %PCPU (%Xtext+%Ddata %Mmax)k'\
    -o exectime_warm.txt \
    $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME < $Q 2> exectime_warm.txt

cd - >/dev/null

# Stop the server
${SUDO} -u $PGUSER $PGBINDIR/pg_ctl stop -D $PGDATADIR

for p in $(jobs -p);
do
  wait $p
done

rm $Q
