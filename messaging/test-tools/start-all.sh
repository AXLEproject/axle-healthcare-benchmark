#!/bin/bash
#
# Start ingress and staging applications
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

echo "Stop any running instances..."
pkill -f net.mgrid.tranzoom.ingress.IngressApplication
#pkill -f transformer.py
pkill -f net.mgrid.tranzoom.staging.StagingApplication

sleep 1

echo "Start ingress application"
./target/start net.mgrid.tranzoom.ingress.IngressApplication > /tmp/tz-ingress.log 2>&1 &

#echo "Start transform application"
#../mgrid-messaging/pyenv/bin/python ../mgrid-messaging/integration/rabbitmq/transformer.py > /tmp/tz-transform.log 2>&1 &

echo "Start staging application"
./target/start net.mgrid.tranzoom.staging.StagingApplication > /tmp/tz-staging.log 2>&1 &

echo "Give applications some time to start"
sleep 5

#echo "Publish messages"
#sbt "test:runMain net.mgrid.messaging.publish.PublishDir ../axle-healthcare-benchmark/cda-generator/output"
