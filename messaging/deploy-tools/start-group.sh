#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, Portavita B.V.
#

GROUPNAME="${1:-mytest}"

# A note about AMIs: these are bound to a region.

# AMI provided by http://www.bashton.com/blog/2013/centos-6-4-ami-available/
# eu-west-1 image. Use ami-e4b5be90 for hvm image
CENTOSAMI="${AMI:-ami-8aa3a8fe}"
UBUNTUAMI="${AMI:-ami-aa56a1dd}"

AMIUSERNAME="ec2-user"
EC2_REGION="eu-west-1"
# need 4GB ram minimal
INSTANCETYPE="${INSTANCETYPE:-m1.large}"
KEYPAIRNAME="axle"
KEYPAIR="/home/${USER}/.aws/axle.pem"

# 2x40 GB SSD + 4vCPU + 7.5GB RAM
BROKERTYPE="c3.xlarge"
# 2x40 GB SSD + 4vCPU + 7.5GB RAM
INGRESSTYPE="c3.xlarge"
# 4x420 GB + 8vCPU + 7GB RAM
XFMTYPE="c1.xlarge"
# 2x40 GB SSD + 4vCPU + 7.5GB RAM
LOADTYPE="c3.xlarge"
DWHTYPE="t1.micro"

# Error handlers
_error() {
    echo "ERROR: $1"
    test "x$INSTANCE" = "x" || euca-terminate-instances ${INSTANCE}
    exit 1
}

test "x$EC2_URL" = "x" && _error "source AWS credentials file first"

echo "Creating group ${GROUPNAME}"

RES=`euca-create-group ${GROUPNAME} -d "Security group for AXLE Messaging"` \
  || _error "Could not create security group ${GROUPNAME}"

echo ...
echo $RES
echo ...

echo "Starting group ${GROUPNAME}"

echo "Start broker first (we need to propagate its IP address to the other instances)"

./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
    ${BROKERTYPE} ${GROUPNAME} broker1 0.0.0.0 \
    || _error "Could not start the broker, stop further processing"

BROKERIP=`euca-describe-instances --filter instance-id=broker1 | tr '\n' ' ' | awk '{print $7}'`

echo "Broker running on ip ${BROKERIP}"

#./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
#    ${INGRESSTYPE} ${GROUPNAME} ingress1 ${BROKERIP} &
#./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
#    ${XFMTYPE} ${GROUPNAME} xfm1 ${BROKERIP} &
#./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
#    ${XFMTYPE} ${GROUPNAME} xfm2 ${BROKERIP} &
#./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
#    ${LOADTYPE} ${GROUPNAME} loader1 ${BROKERIP} &
#./start-instance.sh ${CENTOSAMI} ${AMIUSERNAME} ${KEYPAIRNAME} ${KEYPAIR} ${EC2_REGION} \
#    ${LOADTYPE} ${GROUPNAME} loader2 ${BROKERIP} &

FAIL=0
for job in `jobs -p`
do
    echo $job
    wait $job || let "FAIL+=1"
done

echo $FAIL
exit
