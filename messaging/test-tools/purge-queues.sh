#!/bin/bash
#
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

usage() {
cat << EOF
usage: $0 [OPTIONS]

This script purges the RabbitMQ queues used for tranzoom.
Requires the HTTP management plugin enabled.

OPTIONS:
   -h      Show this message
   -n      RabbitMQ hostname (default localhost)
   -u      RabbitMQ username (default guest)
   -p      RabbitMQ password (default guest)
EOF
}

HOSTNAME="localhost"
USERNAME="guest"
PASSWORD="guest"

while getopts ":hn:u:p:" opt; do
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
        \?)
                echo "Invalid option: -$OPTARG" >&2
        ;;
        esac
done

for q in ingress-fhir ingress-hl7v3 dlx-errors dlx-ingress dlx-transform transform-sql transform-hl7v3 errors-ingress errors-transform errors-sql pond-seq unrouted; do 
  curl -i -u $USERNAME:$PASSWORD -XDELETE http://$HOSTNAME:15672/api/queues/%2fmessaging/$q/contents
done
