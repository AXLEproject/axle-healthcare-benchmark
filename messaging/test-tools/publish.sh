#!/bin/bash
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

usage() {
cat << EOF
usage: $0 [OPTIONS]

This script publishes a message to RabbitMQ.

OPTIONS:
   -h      Show this message
   -r      Routing key (e.g., "source.fhir.resource" or "source.hl7v3.resource")
   -f      Path to the file with the payload
   -v      RabbitMQ vhost (default /)
   -e      RabbitMQ exchange (default amqp.topic)
   -n      RabbitMQ hostname (default localhost)
   -u      RabbitMQ username
   -p      RabbitMQ password
EOF
}

KEY="somesource.fhir.organization"
PAYLOAD=""
HOSTNAME="localhost"
VHOST="%2f"
EXCHANGE="amqp.topic"
USERNAME="guest"
PASSWORD="guest"

while getopts ":hr:f:v:e:n:u:p:" opt; do
        case $opt in
        h)
                usage
                exit 1
        ;;
        r)
                KEY=$OPTARG
        ;;
        f)
                PAYLOAD=`base64 --wrap=0 $OPTARG`
        ;;
        v)
                VHOST=${OPTARG//\//%2f}
        ;;
        e)
                EXCHANGE=$OPTARG
        ;;
        u)
                USERNAME=$OPTARG
        ;;
        p)
                PASSWORD=$OPTARG
        ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
        ;;
        esac
done

curl -i -u $USERNAME:$PASSWORD -H "content-type:applation/json" \
  -XPOST -d'{"properties":{"content_type":"text/plain"},"routing_key":"'$KEY'", "payload":"'$PAYLOAD'", "payload_encoding":"base64"}' \
  http://$HOSTNAME:15672/api/exchanges/$VHOST/$EXCHANGE/publish
