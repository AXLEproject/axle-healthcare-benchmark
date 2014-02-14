#!/bin/bash
#
# Transfer a local data pond to the data lake
#
DPDB=$1
DLHOST=$2 || 127.0.0.1
DLPORT=5432
DLDB=dwh
DLUSER=mgrid

psql -d ${DPDB} -c "SELECT pond_recordids()"

if [ $? -ne 0 ]; then
    exit $?
fi

# TODO: dwh must have db, pond_ddl and cc_ddl!

psql -d ${DPDB} -tc "SELECT pond_ddl()" | psql -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER}
pg_dump -aOx ${DPDB} | sed 's/^SET search_path = public, pg_catalog;$/SET search_path = public, pg_catalog, hl7;/' | psql -h ${DLHOST} -p ${DLPORT} -d ${DLDB} -U ${DLUSER}

psql -d ${DPDB} -c "SELECT pond_empty()"
