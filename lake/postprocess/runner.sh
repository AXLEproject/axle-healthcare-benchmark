#!/bin/bash
#
# Copyright (c) 2014, MGRID BV Netherlands
#
# Run post processing on the lake.
#
# Exit immediately on error
set -e

SCRIPTDIR="$(dirname "$0")"
AXLE=${SCRIPTDIR}/../..

usage() {
cat << EOF
usage: $0 [OPTIONS]

OPTIONS:
   -h      Show this message
   -p      Lake port
   -u      Lake user
   -d      Lake database
EOF
}

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ${AXLE}/default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash_runner
source /tmp/default_settings_bash_runner

# allow command line settings to override default settings
while getopts ":hp:u:d:" opt; do
        case $opt in
        h)
                usage
                exit 1
        ;;
        p)
                LAKEPORT="${OPTARG}"
        ;;
        u)
                LAKEUSER="${OPTARG}"
        ;;
        d)
                LAKEDB=${OPTARG}
        ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
        ;;
        esac
done

PSQL="psql -v ON_ERROR_STOP=true -v VERBOSITY=terse -p ${LAKEPORT} -U ${LAKEUSER} ${LAKEDB}"

cd ${SCRIPTDIR}

while true
do PGOPTIONS='--client-min-messages=warning' \
    ${PSQL} -f runner.sql
    ${PSQL} -c "VACUUM VERBOSE stream.append_id"
    sleep 2
done
