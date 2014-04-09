#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, Portavita B.V.
#
set -e

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
##CENTOSAMI="${AMI:-ami-ce10e0b9}"

# Amazon Linux 64 bit HVM. Instance-store backed otherwise no media/ephemeral storage
CENTOSAMI="${AMI:-ami-0f21df78}"
UBUNTUAMI="${AMI:-ami-aa56a1dd}"

AMIUSERNAME="${AMIUSERNAME:-ec2-user}"
EC2_REGION="eu-west-1"
AVAILABILITYZONE="eu-west-1c"
# need 4GB ram minimal
INSTANCETYPE="${INSTANCETYPE:-m1.large}"
KEYPAIRNAME="axle"
KEYPAIR="/home/${USER}/.aws/axle.pem"

# c3.large 2 cpu, 3.75GB 2x16 SSD
# c3.xlarge 4 cpu, 7.5GB 2x40 SSD

BROKERTYPE="c3.2xlarge"
INGRESSTYPE="c3.2xlarge"
XFMTYPE="c3.2xlarge"
LOADTYPE="c3.2xlarge"
LAKETYPE="hs1.8xlarge"

PLACEMENTGROUP="axle-cluster"

# Error handlers
_error() {
    echo "ERROR: $1"
    test "x$INSTANCE" = "x" || euca-terminate-instances ${INSTANCE}
    exit 1
}

test "x$EC2_URL" = "x" && _error "source AWS credentials file first"

# make sure the group name is not already present in the ssh config
grep -q "^Host ${GROUPNAME}.*" ~/.ssh/config && _error "There already exist hosts with the ${GROUPNAME} prefix in your ssh config, \
  please choose another groupname or clean up you ssh config to avoid clashes."

echo "Starting group ${GROUPNAME}"

ec2-describe-placement-groups ${PLACEMENTGROUP}

if [ $? -ne 0 ]
then
  echo "Placement group ${PLACEMENTGROUP} does not exist, create it first..."
  ec2-create-placement-group ${PLACEMENTGROUP} -s cluster --region ${EC2_REGION}
fi

# NOTE the instance name is used to determine the name of the setup script,
# you should use the format "TYPE-ID" where TYPE is one of {broker, ingress, 
# xfm, loader} and ID is an arbitrary identifier (e.g., a number).
# Example: broker-1

echo "Start brokers first (we need to propagate their IP address to the other instances)"

./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${BROKERTYPE} ${GROUPNAME} "ingressbroker-1" "localhost" "dontcare" ${LAKEEXTERNALHOST:-dontcare} ${PLACEMENTGROUP} ${AVAILABILITYZONE} 2>&1 > ingressbroker-1.log &

./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${BROKERTYPE} ${GROUPNAME} "broker-1" "dontcare" "localhost" ${LAKEEXTERNALHOST:-dontcare} ${PLACEMENTGROUP} ${AVAILABILITYZONE} 2>&1 > broker-1.log &

# It takes about 30 seconds to start the instance
sleep 25

while ! test "X`euca-describe-instances --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=ingressbroker-1 | tr '\n' ' ' | awk '{print $9}'`" = "Xrunning" -a \
    "X`euca-describe-instances --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=broker-1 | tr '\n' ' ' | awk '{print $9}'`" = "Xrunning"; do
  echo "Waiting for the ingress broker to become running"
  sleep 5
done

INGRESSBROKERHOST=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=ingressbroker-1 | tr '\n' ' ' | awk '{print $7}'`
BROKERHOST=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=broker-1 | tr '\n' ' ' | awk '{print $7}'`

if [ "x${LAKEEXTERNALHOST}" = "x" ];
then
  echo "No lake host provided, creating new lake instance of type ${LAKETYPE}"

  ./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
      ${LAKETYPE} ${GROUPNAME} "lake" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKELOCALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE} 2>&1 > lake.log  &

  # It takes about 30 seconds to start the instance
  sleep 25

  while ! test "X`euca-describe-instances --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=lake | tr '\n' ' ' | awk '{print $9}'`" = "Xrunning"; do
    echo "Waiting for the lake to become running"
    sleep 5
  done

  LAKEEXTERNALHOST=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=lake | tr '\n' ' ' | awk '{print $7}'`
fi

echo "============= INGRESS BROKER RUNNING ON HOST ${INGRESSBROKERHOST} ============="
echo "============= BROKER RUNNING ON HOST ${BROKERHOST} ============="
echo "=============== LAKE RUNNING ON HOST ${LAKEEXTERNALHOST} ================"

./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
   ${INGRESSTYPE} ${GROUPNAME} "ingress-1" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE} 2>&1 > ingress-1.log &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${XFMTYPE} ${GROUPNAME} "xfm-1" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}        2>&1 > xfm-1.log     &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${XFMTYPE} ${GROUPNAME} "xfm-2" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}        2>&1 > xfm-2.log     &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${XFMTYPE} ${GROUPNAME} "xfm-3" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}        2>&1 > xfm-3.log     &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${XFMTYPE} ${GROUPNAME} "xfm-4" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}        2>&1 > xfm-4.log     &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${LOADTYPE} ${GROUPNAME} "loader-1" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}    2>&1 > loader-1.log  &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${LOADTYPE} ${GROUPNAME} "loader-2" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}    2>&1 > loader-2.log  &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${LOADTYPE} ${GROUPNAME} "loader-3" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}    2>&1 > loader-3.log  &
./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${LOADTYPE} ${GROUPNAME} "loader-4" ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${PLACEMENTGROUP} ${AVAILABILITYZONE}    2>&1 > loader-4.log  &

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
