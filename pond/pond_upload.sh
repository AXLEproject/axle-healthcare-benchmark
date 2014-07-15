#!/bin/bash
#
# Copyright (c) 2013, MGRID BV Netherlands
#
# Transfer a local data pond to the data lake
#
# Set pipefail option: "The return value of a pipeline is the value of the last (rightmost) command to exit with a non-zero status, or 
# zero if all commands in the pipeline exit successfully.
set -o pipefail
# Exit immediately on error
set -e

usage() {
  cat << EOF
  usage: $0 [OPTIONS]

  Transfer a local data pond to the data lake

  OPTIONS:
     -h      Show this message
     -n      Pond database name
     -u      Pond database username
     -H      Lake database host
     -N      Lake database name
     -U      Lake database username
     -P      Lake database port
EOF
}

timestamp() {
  date +"%s"
}

# Set PATH
source $HOME/.bashrc

DPDB=pond1
DPUSER=${USER}
DLHOST=127.0.0.1
DLPORT=5432
DLDB=lake
DLUSER=${USER}

while getopts "hn:u:H:N:U:P:" opt; do
        case $opt in
        h)
          usage
          exit 1
        ;;
        n)
          DPDB=$OPTARG
        ;;
        u)
          DPUSER=$OPTARG
        ;;
        H)
          DLHOST=$OPTARG
        ;;
        N)
          DLDB=$OPTARG
        ;;
        U)
          DLUSER=$OPTARG
        ;;
        P)
          DLPORT=$OPTARG
        ;;
        ?)
          exit 1
        ;;
        esac
done

# If there are no roles we can exit
R=`psql -U ${DPUSER} -d ${DPDB} -tAc 'SELECT 1 FROM "Role" LIMIT 1'`
test "X${R}" = "X1" || exit 0
#logger -t axle-pond-upload "database is empty"

# Execute all pre-processing SQL files first.
for i in $(ls $(dirname $0)/preprocess/*sql)
do
    SECS=`TIME="%e" PGOPTIONS='--client-min-messages=warning' psql -vON_ERROR_STOP=on -U ${DPUSER} -d ${DPDB} -f ${i}`
    logger -t axle-pond-upload "${i} execution time ${SECONDS} seconds"
done

t_before=$(timestamp)
psql -U ${DPUSER} -d ${DPDB} -c "SELECT pond_recordids()"
t_after=$(timestamp)

logger -t axle-pond-upload "pond_recordids() execution time $(( t_after - t_before )) seconds"

t_before=$(timestamp)
PGOPTIONS='--hdl.concept_print_mode=complex_r1' pg_dump -aOx -n stream -n rim2011 ${DPDB} -U ${DPUSER} | sed \
    -e '/SET search_path/ s/;/, hl7;/' \
    -e '/SET lock_timeout/d' \
    -e '/pg_catalog.setval/d' \
    | psql -1 -v ON_ERROR_STOP=true -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER}
t_after=$(timestamp)

logger -t axle-pond-upload "dump and upload total execution time $(( t_after - t_before )) seconds"

t_before=$(timestamp)
psql -U ${DPUSER} -d ${DPDB} -c "SELECT pond_empty()"
t_after=$(timestamp)

logger -t axle-pond-upload "pond_empty() execution time $(( t_after - t_before )) seconds"
