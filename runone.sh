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

usage() {
    echo "USAGE: $0 <QUERY> <PGDATA> <DWHDB> <PERFDATADIR>"
    echo "e.g. $0 2.1.1 database/data lake perfresults"
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
    echo 0 | sudo tee /proc/sys/kernel/kptr_restrict
  fi
  if [ -r /proc/sys/kernel/perf_event_paranoid ] && [ $(cat /proc/sys/kernel/perf_event_paranoid) -ne -1 ]; then
    echo "Need to enable the reading of performance events."
    echo -1 | sudo tee /proc/sys/kernel/perf_event_paranoid
  fi
  if [ -r /proc/sys/kernel/perf_event_mlock_kb ] && [ $(cat /proc/sys/kernel/perf_event_mlock_kb) -lt 1024 ]; then
    echo "Need to give more memory to perf."
    echo 1024 | sudo tee /proc/sys/kernel/perf_event_mlock_kb
  fi
}

BASEDIR=$(dirname "$0")
BASEDIR=$(cd "$BASEDIR"; pwd)

if [ $# -lt 4 ]; then
    usage
else
    QUERY=$1
    PWD=`pwd`
    PGDATADIR=$2;
    DWHDB=$3;
    PERFDATADIR=$4;
fi

test [ ${PGDATADIR:0:1} == "/" ] || PGDATADIR="$PWD/$PGDATADIR"

DB_NAME=${DWHDB}

### Query to be executed
f=`ls queries/${QUERY}*.sql`

Q=`mktemp`
echo "set search_path to rim2011, public, hl7, hdl, r1;" | cat - "$BASEDIR/$f" > $Q

################ from here script follows pg-tpch/tpch_runone ###################

perf_set_kernel_params

dir="$PERFDATADIR/${QUERY}"
mkdir -p $dir
cd "$dir"

### Get execution time without perf
/usr/bin/time -f '%e\n%Uuser %Ssystem %Eelapsed %PCPU (%Xtext+%Ddata %Mmax)k'\
    -o exectime.txt \
    postgres --single -j -D $PGDATADIR $DB_NAME < $Q

### Collect data with perf to generate callgraph
perf record -g -- postgres --single -j -D $PGDATADIR $DB_NAME < $Q

### Collect basic stats with perf
perf stat -B --log-fd 2 --\
    postgres --single -j -D $PGDATADIR $DB_NAME < $Q 2> stats.txt

cgf="../${QUERY}-callgraph.pdf"
echo "Creating the call graph: $cgf"
perf script | python "$BASEDIR/gprof2dot.py" -f perf | dot -Tpdf -o $cgf &
cd - >/dev/null

for p in $(jobs -p);
do
  wait $p
done

rm $Q
