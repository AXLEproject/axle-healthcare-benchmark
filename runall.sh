#!/bin/bash
#
# runall.sh
# Run all queries with profiling
#
# This file is part of the AXLE Healthcare Benchmark.
#
# Copyright (c) 2015, Portavita BV Netherlands
#
set -e

PGDATADIR=${PGDATA}
PGPORT=${LAKEPORT}
PGUSER=${USER}
SUDO=/usr/bin/sudo

usage() {
    echo "USAGE: $0 <DWHDB> <PERFDATADIR>"
    echo "e.g. $0 lake perfresults"
    exit 1
}

fail() {
    echo $1
    exit 1
}

if [ $# -lt 2 ]; then
    usage
else
    DWHDB=$1;
    PERFDATADIR=$2;
fi

test -d ${PERFDATADIR} && fail "Directory ${PERFDATADIR} already exists. Please choose an empty directory."

mkdir -p ${PERFDATADIR}
echo "Hint: view a single image to enable mouseover symbol lookup in the svg's" > ${PERFDATADIR}/index.html

for q in {1..21}
do
    ./runone.sh ${q} ${DWHDB} ${PERFDATADIR}
done
