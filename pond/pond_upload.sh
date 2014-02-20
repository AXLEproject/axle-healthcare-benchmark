#!/bin/bash
#
# Transfer a local data pond to the data lake
usage() {
  cat << EOF
  usage: $0 [OPTIONS]

  Transfer a local data pond to the data lake

  OPTIONS:
     -h      Show this message
     -n      Pond database name
     -H      Lake database host
     -N      Lake database name
     -U      Lake database username
EOF
}

DPDB=test
DPUSER=mgrid
DLHOST=127.0.0.1
DLPORT=5432
DLDB=dwh
DLUSER=mgrid

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

psql -d ${DPDB} -c "SELECT pond_recordids()"

if [ $? -ne 0 ]; then
    exit $?
fi

# TODO: dwh must have db, pond_ddl and cc_ddl!

psql -U ${DPUSER) -d ${DPDB} -tc "SELECT pond_ddl()" | psql -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER} || exit $?
pg_dump -aOx ${DPDB} -U ${DPUSER) | sed 's/^SET search_path = public, pg_catalog;$/SET search_path = public, pg_catalog, hl7;/' | psql -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER} || exit $?

psql -U ${DPUSER} -d ${DPDB} -c "SELECT pond_empty()"
