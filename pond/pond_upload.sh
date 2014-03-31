#!/bin/bash
#
# Transfer a local data pond to the data lake


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

# If there are no organizations we can exit
R=`psql -U ${DPUSER} -d ${DPDB} -tAc 'SELECT 1 FROM "Organization" LIMIT 1'`
test "X${R}" = "X1" || exit 0
#logger -t axle-pond-upload "database is empty"

# Execute all pre-processing SQL files first.
for i in $(ls $(dirname $0)/preprocess/*sql)
do
    SECS=`TIME="%e" psql -1 -vON_ERROR_STOP=on -U ${DPUSER} -d ${DPDB} -f ${i}`
    logger -t axle-pond-upload "${i} execution time ${SECONDS} seconds"
done

psql -U ${DPUSER} -d ${DPDB} -c "SELECT pond_recordids()"

# TODO: lake must have db, pond_ddl and cc_ddl!

psql -U ${DPUSER} -d ${DPDB} -tc "SELECT pond_ddl()" | psql -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER}
pg_dump -aOx ${DPDB} -U ${DPUSER} | sed 's/^SET search_path = public, pg_catalog;$/SET search_path = public, pg_catalog, hl7;/' | psql -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER}

psql -U ${DPUSER} -d ${DPDB} -c "SELECT pond_empty()"
