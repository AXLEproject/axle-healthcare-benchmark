#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, Portavita B.V.
#

GROUPNAME="${1:-mytest}"
LAKEEXTERNALHOST="$2"

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' $(git rev-parse --show-cdup)/default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash
source /tmp/default_settings_bash

# A note about AMIs: these are bound to a region.

# Official Centos Image (does not recognize additional storage)
##CENTOSAMI="${AMI:-ami-230b1b57}"

# Bashton Centos Image (recognized additional storage, but may experience
# troubles resulting in unable to install packages with yum since it cannot
# resolve mirror.centos.org.)
##CENTOSAMI="${AMI:-ami-8aa3a8fe}"

# Copy of Bashton Image: in case the Bashton image is taken offline:
CENTOSAMI="${AMI:-ami-ce10e0b9}"
UBUNTUAMI="${AMI:-ami-aa56a1dd}"

AMIUSERNAME="${AMIUSERNAME:-ec2-user}"
EC2_REGION="eu-west-1"
# need 4GB ram minimal
INSTANCETYPE="${INSTANCETYPE:-m1.large}"
KEYPAIRNAME="axle"
KEYPAIR="/home/${USER}/.aws/axle.pem"

# c3.large 2 cpu, 3.75GB 2x16 SSD
# c3.xlarge 4 cpu, 7.5GB 2x40 SSD

BROKERTYPE="c3.large"
INGRESSTYPE="c3.xlarge"
XFMTYPE="c3.xlarge"
LOADTYPE="c3.xlarge"
LAKETYPE="hs1.8xlarge"

# Error handlers
_error() {
    echo "ERROR: $1"
    test "x$INSTANCE" = "x" || euca-terminate-instances ${INSTANCE}
    exit 1
}

test "x$EC2_URL" = "x" && _error "source AWS credentials file first"

echo "Starting group ${GROUPNAME}"

# NOTE the instance name is used to determine the name of the setup script,
# you should use the format "TYPE-ID" where TYPE is one of {broker, ingress, 
# xfm, loader} and ID is an arbitrary identifier (e.g., a number).
# Example: broker-1

echo "Start broker first (we need to propagate its IP address to the other instances)"

./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${BROKERTYPE} ${GROUPNAME} "broker-1" "localhost" ${LAKEEXTERNALHOST:-dontcare} 2>&1 > broker.log &

# It takes about 30 seconds to start the instance
sleep 25

while ! test "X`euca-describe-instances --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=broker-1 | tr '\n' ' ' | awk '{print $9}'`" = "Xrunning"; do
  echo "Waiting for the broker to become running"
  sleep 5
done

BROKERHOST=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=broker-1 | tr '\n' ' ' | awk '{print $7}'`

if [ "x${LAKEEXTERNALHOST}" = "x" ];
then
  echo "No lake host provided, creating new lake instance of type ${LAKETYPE}"

  ./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
      ${LAKETYPE} ${GROUPNAME} "lake" ${BROKERHOST} ${LAKELOCALHOST} 2>&1 > lake.log  &

  # It takes about 30 seconds to start the instance
  sleep 25

  while ! test "X`euca-describe-instances --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=lake | tr '\n' ' ' | awk '{print $9}'`" = "Xrunning"; do
    echo "Waiting for the lake to become running"
    sleep 5
  done

  LAKEEXTERNALHOST=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=lake | tr '\n' ' ' | awk '{print $7}'`
fi

echo "============= BROKER RUNNING ON HOST ${BROKERHOST} ============="
echo "=============== LAKE RUNNING ON HOST ${LAKEEXTERNALHOST} ================"

./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
   ${INGRESSTYPE} ${GROUPNAME} "ingress-1" ${BROKERHOST} ${LAKEEXTERNALHOST} 2>&1 > ingress-1.log &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${XFMTYPE} ${GROUPNAME} "xfm-1" ${BROKERHOST} ${LAKEEXTERNALHOST}        2>&1 > xfm-1.log     &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${XFMTYPE} ${GROUPNAME} "xfm-2" ${BROKERHOST} ${LAKEEXTERNALHOST}        2>&1 > xfm-2.log     &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${LOADTYPE} ${GROUPNAME} "loader-1" ${BROKERHOST} ${LAKEEXTERNALHOST}    2>&1 > loader-1.log  &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${LOADTYPE} ${GROUPNAME} "loader-2" ${BROKERHOST} ${LAKEEXTERNALHOST}    2>&1 > loader-2.log  &

FAIL=0
for job in `jobs -p`
do
    echo $job
    wait $job || let "FAIL+=1"
done

echo $FAIL

if [ $FAIL -eq 0 ];
then
    # Finalize symon and symux configuration
    ./update-group-monitoring.sh ${KEYPAIR} ${GROUPNAME}
else
    exit 1;
fi

echo $FAIL
exit 0;
