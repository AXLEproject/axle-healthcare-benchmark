#!/bin/bash
#
# Calculate some statistics based on the log files
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

read startTime startNum <<<$(sed -n '/Start validate/p' /tmp/tz-ingress.log | awk '{if (NR==1) first=$6; total+=1} END {print first, total}')
read endTime endNum <<<$(sed -n '/Done staging/p' /tmp/tz-staging.log | awk '{last=$6;total+=$7} END {print last, total}')

let delta=`date +%s -d $endTime`-`date +%s -d $startTime`
let mps=$endNum/$delta

echo "Running time in seconds: $delta"
echo "Ingress messages: $startNum"
echo "Staged messages: $endNum"
echo "Message rate (#staged/time): $mps"
