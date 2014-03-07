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

run() {
  bash -c "$1" &
  store_pid "$!"
}

trap onexit SIGINT SIGTERM EXIT

BROKERHOST="localhost"
USERNAME="guest"
PASSWORD="guest"
MSGDIR="../../mgrid-messaging"

while getopts ":hu:p:M:D:G:" opt; do
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
                MSGDIR=$OPTARG
        ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
        ;;
        esac
done

source $MSGDIR/pyenv/bin/activate

./test-tools/makepond.sh pond
./test-tools/makelake.sh lake

./test-tools/purge-queues.sh -u admin -p tr4nz00m

$MSGDIR/pyenv/bin/python ../pond/rabbitmq_seed_pond_seq.py

echo
echo ====
echo Start components
echo ====
echo

run "$MSGDIR/pyenv/bin/python $MSGDIR/integration/rabbitmq/transformer.py"

run "./target/start net.mgrid.tranzoom.ingress.IngressApplication"

run "./target/start -Dconfig.pond.dbuser=${USER} -Dconfig.pond.dbname=pond -Dconfig.lake.dbuser=${USER} -Dconfig.lake.dbname=lake net.mgrid.tranzoom.ccloader.LoaderApplication"

wait
