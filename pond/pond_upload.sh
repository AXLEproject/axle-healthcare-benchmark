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
     -p      Pond port
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

while getopts "hn:u:p:H:N:U:P:" opt; do
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
        p)
          DPPORT=$OPTARG
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

# Execute all pre-processing SQL files first.
echo $(ls $(dirname $0)/preprocess/*sql) | logger -t axle-pond-upload

t_before=$(timestamp)
cat $(ls $(dirname $0)/preprocess/*sql) | \
PGOPTIONS='--client-min-messages=warning' psql -vON_ERROR_STOP=on -U ${DPUSER} -d ${DPDB} -p ${DPPORT} -p ${DPPORT}> /dev/null
t_after=$(timestamp)
##logger -t axle-pond-upload "preprocess execution time $(( t_after - t_before ))  seconds"

t_before=$(timestamp)
PGOPTIONS='--hdl.concept_print_mode=complex_r1' pg_dump -aOx -n stream -n rim2011 ${DPDB} -U ${DPUSER}  -p ${DPPORT}| sed \
    -e '/SET search_path/ s/;/, hl7, hdl, r1;/' \
    -e '/SET lock_timeout/d' \
    -e '/pg_catalog.setval/d' \
    -e '/SET row_security/d' \
    -e 's/COPY "Participation"/COPY "Participation_in"/g' \
    | psql -1 -v ON_ERROR_STOP=true -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER}
t_after=$(timestamp)
logger -t axle-pond-upload "dump and upload total execution time $(( t_after - t_before )) seconds"


t_before=$(timestamp)
psql -U ${DPUSER} -d ${DPDB}  -p ${DPPORT} -c "SELECT pond_empty()"
t_after=$(timestamp)
#logger -t axle-pond-upload "pond_empty() execution time $(( t_after - t_before )) seconds"
