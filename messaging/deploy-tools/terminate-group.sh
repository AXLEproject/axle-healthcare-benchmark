#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, Portavita B.V.
#

GROUPNAME="${1:-mytest}"

# Error handlers
_error() {
    echo "ERROR: $1"
    test "x$INSTANCE" = "x" || euca-terminate-instances ${INSTANCE}
    exit 1
}

test "x$EC2_URL" = "x" && _error "source AWS credentials file first"

echo "Terminating group ${GROUPNAME}"
sleep 2

for INSTANCE in `euca-describe-instances --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} | grep INSTANCE | awk '{print $2}'`
do
    euca-terminate-instances ${INSTANCE}
done

