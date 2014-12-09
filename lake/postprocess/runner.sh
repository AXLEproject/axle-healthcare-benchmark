#!/bin/bash
#
# Copyright (c) 2014, MGRID BV Netherlands
#
# Run post processing on the lake.
#
# Exit immediately on error
set -e

AXLE=/home/${USER}/axle-healthcare-benchmark

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ${AXLE}/default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash_runner
source /tmp/default_settings_bash_runner

PSQL="psql -v ON_ERROR_STOP=true -v VERBOSITY=terse -p ${LAKEPORT} -U ${LAKEUSER} ${LAKEDB}"

cd ${AXLE}/lake/postprocess

while true
do PGOPTIONS='--client-min-messages=warning' \
    ${PSQL} -f runner.sql
    ${PSQL} -c "VACUUM VERBOSE stream.append_id"
    sleep 2
done
