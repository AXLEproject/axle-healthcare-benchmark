#!/bin/bash
#
# runone.sh
# Run a single query with profiling
#
# This file is part of the AXLE Healthcare Benchmark.
#
# Copyright (c) 2013, Portavita BV Netherlands
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

#
# Set up perf
#
perf_set_kernel_params() {
  if [ -r /proc/sys/kernel/kptr_restrict ] && [ $(cat /proc/sys/kernel/kptr_restrict) -ne 0 ]; then
    echo "Perf requires reading kernel symbols."
    echo 0 | ${SUDO} tee /proc/sys/kernel/kptr_restrict
  fi
  if [ -r /proc/sys/kernel/perf_event_paranoid ] && [ $(cat /proc/sys/kernel/perf_event_paranoid) -ne -1 ]; then
    echo "Need to enable the reading of performance events."
    echo -1 | ${SUDO} tee /proc/sys/kernel/perf_event_paranoid
  fi
  if [ -r /proc/sys/kernel/perf_event_mlock_kb ] && [ $(cat /proc/sys/kernel/perf_event_mlock_kb) -lt 1024 ]; then
    echo "Need to give more memory to perf."
    echo 1024 | ${SUDO} tee /proc/sys/kernel/perf_event_mlock_kb
  fi
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

# Calculates elapsed time
timer() {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local  stime=$1
        etime=$(date '+%s')

        if [[ -z "$stime" ]]; then stime=$etime; fi

        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%d:%02d:%02d' $dh $dm $ds
    fi
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

### From here more or less follows tpch_runone
perf_set_kernel_params

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

### Execute query with explain analyze to get query plan
#echo "Execute query with explain analyze to get query plan"
#${SUDO} -u $PGUSER $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME <"$BASEDIR/$fa" > analyze.txt
#restart_drop_caches

### Get execution time without perf
/usr/bin/time -f '%e\n%Uuser %Ssystem %Eelapsed %PCPU (%Xtext+%Ddata %Mmax)k'\
    -o exectime.txt \
    $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME < $Q 2> exectime.txt
restart_drop_caches

### Collect data with perf to generate callgraph
echo "Collect data with perf to generate callgraph"
/usr/bin/time -f '%e\n%Uuser %Ssystem %Eelapsed %PCPU (%Xtext+%Ddata %Mmax)k'\
  ${SUDO} -u $PGUSER perf record -a -C 2 -s -g -m 512 --\
  $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME < $Q 2> exectime_perf.txt
tail -n 2 exectime_perf.txt > exectime_p.txt && mv exectime_p.txt exectime_perf.txt

### Call the query second time and record in perf.data.warm
/usr/bin/time -f '%e\n%Uuser %Ssystem %Eelapsed %PCPU (%Xtext+%Ddata %Mmax)k'\
  ${SUDO} -u $PGUSER perf record -o perf.data.warm -a -C 2 -s -g -m 512 --\
  $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME < $Q 2> /dev/null

restart_drop_caches

### Collect basic stats with perf
echo "Collect basic stats with perf"
${SUDO} -u $PGUSER perf stat -a -C 2 -B --log-fd 2 --\
  $PGBINDIR/psql -h /tmp -p $PGPORT -d $DB_NAME < $Q 2> stats.txt
restart_drop_caches

${SUDO} chown $USER:$USER *
chmod 775 .

cgf="../${QUERY}-callgraph.pdf"
echo "Creating the call graph: $cgf"
perf script | python "$BASEDIR/gprof2dot.py" -f perf | dot -Tpdf -o $cgf &

fgf="../${QUERY}-flamegraph.svg"
fgfw="../${QUERY}-flamegraph-warm.svg"
echo "Creating the flame graph: $fgf"
perf script | "$BASEDIR/stackcollapse-perf.pl" | \
    "$BASEDIR/flamegraph.pl" --title "Portavita Benchmark ${SIZE} Query ${QUERY} cold" > $fgf
perf script -i perf.data.warm | "$BASEDIR/stackcollapse-perf.pl" | \
    "$BASEDIR/flamegraph.pl" --title "Portavita Benchmark ${SIZE} Query ${QUERY} warm" > $fgfw

cd - >/dev/null

# Stop the server
${SUDO} -u $PGUSER $PGBINDIR/pg_ctl stop -D $PGDATADIR

for p in $(jobs -p);
do
  wait $p
done

rm $Q
