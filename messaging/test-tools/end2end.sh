#!/bin/bash
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

function usage() {
cat << EOF
usage: $0 [OPTIONS]

Start end-to-end test.

OPTIONS:
   -h      Show this message
   -u      RabbitMQ username (default guest)
   -p      RabbitMQ password (default guest)
   -M      Path to MGRID Messaging
   -D      Path to AXLE database tools
EOF
}

onexit() {
  echo "EXIT"
  kill ${pids[*]} &>/dev/null
  sleep 1
}

store_pid() {
  pids=("${pids[@]}" "$1")
}

trap onexit SIGINT SIGTERM EXIT

BROKERHOST="localhost"
USERNAME="guest"
PASSWORD="guest"
MDIR="../../mgrid-messaging"
DBTOOLS="../database"

while getopts ":hu:p:M:D:" opt; do
        case $opt in
        h)
                usage
                exit 1
        ;;
        u)
                USERNAME=$OPTARG
        ;;
        p)
                PASSWORD=$OPTARG
        ;;
        M)
                MDIR=$OPTARG
        ;;
        D)
                DBTOOLSDIR=$OPTARG
        ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
        ;;
        esac
done

source $MDIR/pyenv/bin/activate

./test-tools/makepond.sh pond
./test-tools/makelake.sh lake

./test-tools/purge-queues.sh -u admin -p tr4nz00m

python ../pond/rabbitmq_seed_pond_seq.py

bash -c "python $MDIR/integration/rabbitmq/transformer.py -n ${BROKERHOST}" &
store_pid "$!"

bash -c "./target/start -Dconfig.rabbitmq.host=${BROKERHOST} net.mgrid.tranzoom.ingress.IngressApplication" &
store_pid "$!"

bash -c "./target/start \
    -Dconfig.rabbitmq.host=${BROKERHOST} \
    -Dconfig.pond.dbhost=localhost \
    -Dconfig.pond.dbname=pond \
    -Dconfig.pond.dbuser=${USER} \
    -Dconfig.lake.dbhost=localhost \
    -Dconfig.lake.dbname=lake \
    -Dconfig.lake.dbport=5432 \
    -Dconfig.lake.dbuser=${USER} \
    net.mgrid.tranzoom.ccloader.LoaderApplication" &
store_pid "$!"

wait