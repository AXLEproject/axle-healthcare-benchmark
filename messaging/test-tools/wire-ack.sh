#!/bin/bash
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

usage() {
cat << EOF
usage: $0 [OPTIONS]

This script captures AMQP acks sent by the broker (i.e. publisher confirms).

OPTIONS:
   -h      Show this message
EOF
}

while getopts ":h" opt; do
        case $opt in
        h)
                usage
                exit 1
        ;;
        esac
done

TCP_DATA_OFFSET="((tcp[12:1]&0xf0)>>2)"
AMQP_METHOD="tcp[($TCP_DATA_OFFSET+9):2]"
AMQP_ACK="0x50"

sudo tcpdump -i any "((src port 5672) and ($AMQP_METHOD = $AMQP_ACK))"