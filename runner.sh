#!/bin/bash
set -e

CDAGENCONF=cda-generator/src/main/resources/application.conf

for i in 500 750
do
    # clean up previous stuff
    rm -rf cda-generator/output
    make -C datawarehouse dropdb
    make -C datawarehouse createdb
    make -C datawarehouse opaque

    # start generation
    sed -i "/numberOfCdas/c\numberOfCdas = ${i}" ${CDAGENCONF}
    cd cda-generator && bash ./initialize.sh
    echo "TIME XML GENERATION"
    time bash ./start.sh
    sync
    cd ..

    echo "TIME STAGING"
    time make -C datawarehouse stage

    echo "TIME TRANSFORM"
    time make -C datawarehouse transform

    echo "TIME LOAD"
    time make -C datawarehouse pgload

    # how big xml?"
    du -sh cda-generator/output
    psql dwh -c "vacuum full"
    psql dwh -c "select pg_size_pretty(pg_database_size('dwh'));"
    psql dwh -c "select count(*) from dim_patient;"
    grep DO /tmp/parse_cdas.log  | wc -l
done
