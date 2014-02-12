#!/bin/bash
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

usage() {
cat << EOF
usage: $0 [OPTIONS]

This script gets messages from a RabbitMQ queue.
Requires the HTTP management plugin enabled.

OPTIONS:
   -h      Show this message
   -n      RabbitMQ hostname (default localhost)
   -u      RabbitMQ username (default guest)
   -p      RabbitMQ password (default guest)
   -v      RabbitMQ vhost (default /)
   -q      RabbitMQ queue name (default q)
   -c      Item count to get (default 100)
EOF
}

HOSTNAME="localhost"
USERNAME="guest"
PASSWORD="guest"
VHOST="%2f"
QUEUE="q"
COUNT=100

while getopts ":hn:u:p:v:q:c:" opt; do
        case $opt in
        h)
                usage
                exit 1
        ;;
        n)
                HOSTNAME="$OPTARG"
        ;;
        u)
                USERNAME=$OPTARG
        ;;
        p)
                PASSWORD=$OPTARG
        ;;
        v)
                VHOST=${OPTARG//\//%2f}
        ;;
        q)
                QUEUE=$OPTARG
        ;;
        c)
                COUNT=$OPTARG
        ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
        ;;
        esac
done

curl -i -u $USERNAME:$PASSWORD -H "content-type:application/json" \
  -XPOST http://$HOSTNAME:15672/api/queues/$VHOST/$QUEUE/get -d'{"count":'$COUNT',"requeue":false,"encoding":"auto","truncate":500}'