#!/bin/bash

if [ ! -f entity_resolution.sql ];
then
    echo "$0: ./entity_resolution.sql not found. start script from lake/test directory"
    exit 1
fi

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ../../default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash
source /tmp/default_settings_bash

PONDDB=pond2

# test new clusters
psql -p ${PONDPORT} -h ${PONDHOST} -f entity_resolution.sql ${PONDDB}
../../pond/pond_upload.sh -n ${PONDDB} -P ${LAKEPORT} -N ${LAKEDB}
PGOPTIONS='--client-min-messages=warning' psql --set=VERBOSITY=terse \
  -p ${LAKEPORT} -f ../postprocess/010_entity_resolution.sql ${LAKEDB}

# test existing clusters
psql -p ${PONDPORT} -h ${PONDHOST} -f entity_resolution_2.sql ${PONDDB}
../../pond/pond_upload.sh -n ${PONDDB} -P ${LAKEPORT} -N ${LAKEDB}
PGOPTIONS='--client-min-messages=warning' psql --set=VERBOSITY=terse \
  -p ${LAKEPORT} -f ../postprocess/010_entity_resolution.sql ${LAKEDB}
