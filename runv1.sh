# this script was used to generate several size databases
#!/bin/bash
set -e

CDAGENCONF=cda-generator/src/main/resources/application.conf


for i in 2500000 5000000 10000000 5000000 10000000
do
    echo "RUN ${i}"
    # clean up previous stuff
    rm -rf cda-generator/output
    make -C datawarehouse dropdb
    make -C datawarehouse createdb
    make -C datawarehouse opaque

    # remove context conduction
    psql staging -c "drop extension bp cascade"

    # start generation
    sed -i "/numberOfCdas/c\numberOfCdas = ${i}" ${CDAGENCONF}
    cd cda-generator && bash ./initialize.sh
    echo "TIME XML GENERATION"
    time bash ./start.sh
    sync
    cd ..

    echo "TIME XML TO PLSQL"
    cd cda-generator/output ; time ls | parallel --gnu "python /home/${USER}/mgrid-messaging-0.9/cda_r2/convert_CDA_R2.py --quiet --dir={1} | sed -e 's/m^2/m2/' -e 's/mm Hg/mm[Hg]/' -e 's/17074200/170742000/' -e 's/18803012/88803002/' > {1}.sql"
    echo "TIME PLSQL TO DB"
    time ls *sql | parallel --gnu "psql -p 5432 -f {1} staging" | grep DO | wc -l
    echo last line was no documents
    echo "TIME VACUUM ANALYZE"
    time psql staging -c "VACUUM ANALYZE"
    cd ../..

    echo "TIME TRANSFORM"
    time make -C datawarehouse transform

    echo "TIME LOAD"
    time make -C datawarehouse pgload

    # how big xml?"
    du -sh cda-generator/output
    psql dwh -c "vacuum analyze"
    psql dwh -c "select pg_size_pretty(pg_database_size('dwh'));"
    psql dwh -c "select pg_size_pretty(pg_database_size('staging'));"
    psql dwh -c "select count(*) from dim_patient;"
done
