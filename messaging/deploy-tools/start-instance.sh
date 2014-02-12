#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, Portavita B.V.
#
# start a generic AXLE instance at amazon:
# - create
# - assign groupname and instancename
# - install git
# - clone axle-healthcare-benchmark
# - copy the password
#

if [ $# -ne 9 ];
then
    echo "Usage: $0 <ami> <amiusername> <keypairname> <keypairfile> <region> <instancetype> <groupname> <instancename> <broker-ip>"
    exit 127
fi

AMI="$1"
AMIUSERNAME="$2"
KEYPAIRNAME="$3"
KEYPAIR="$4"
EC2_REGION="$5"
INSTANCETYPE="$6"
GROUPNAME="$7"
INSTANCENAME="$8"
BROKERIP=$9

TEMP_REPO="ssh://vagrant@217.21.198.42:2222/home/vagrant/Development/axle-healthcare-benchmark"

#exit code
WARN=0

# Error handlers
_error() {
    echo "ERROR: $1"
    exit 1
}

_warn() {
    echo "WARNING: $1"
    WARN=2
}

test "x$EC2_URL" = "x" && _error "source AWS credentials file first"

RES=`euca-run-instances ${AMI} -k ${KEYPAIRNAME} --region ${EC2_REGION} --instance-type ${INSTANCETYPE}` \
	|| _error "Could not start instance ${AMI}"

echo ...
echo $RES
echo ...

INSTANCE=`echo ${RES} | tr '\n' ' ' | awk '{print $5}'`
ZONE=`euca-describe-instances --filter instance-id=${INSTANCE} | tr '\n' ' ' | awk '{print $13}'`

echo "Succesfully runned ${INSTANCE} on zone ${ZONE}"

# It takes about 30 seconds to start the instance
sleep 25

while ! test `euca-describe-instances --filter instance-id=${INSTANCE} | tr '\n' ' ' | awk '{print $9}'` = "running"; do
	echo "Waiting for the instance to become running"
	sleep 5
done

IP=`euca-describe-instances --filter instance-id=${INSTANCE} | tr '\n' ' ' | awk '{print $7}'`

echo "Succesfully started ${INSTANCE} running on ip ${IP}"

# Create tags for groupname and instancename
RES=`euca-create-tags --tag groupname=${GROUPNAME} --tag instancename=${INSTANCENAME} ${INSTANCE}` \
        || _error "Could not create tags '${GROUPNAME}' and '${INSTANCENAME}' for instance ${INSTANCE} on region ${EC2_REGION}"

# Wait 5 more seconds before we can login
sleep 5

while ! test `nmap ${IP} -PN -p ssh | grep tcp | awk '{print $2}'` = "open"
do
	echo "Waiting for SSH to be available on ${IP}"
	sleep 2
done

# Copy SSH keys for temp repo access
scp -i ${KEYPAIR} axle_tmp_rsa ${AMIUSERNAME}@${IP}:~/.ssh/id_rsa || _error "Could not copy SSH key"

# The double -t is necessary to not cause sudo to given an error about
# incorrect terminal settings
ssh -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
sudo yum install -y git
git clone $TEMP_REPO
exit
EOF

# Need to copy the password before bootstrapping, since the axle / cdagenpwd is necessary
# to download the HDL installer
#scp -i ${KEYPAIR} axle-generator-password.txt ${AMIUSERNAME}@${IP}:axle-healthcare-benchmark/cda-generator/password.txt || error "Could not copy axle generator password"

# choose the setup script based on the instance name
STARTTYPE=`expr match "${INSTANCENAME}" '\(^[a-zA-Z]*\)'`
ssh -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
sudo ./axle-healthcare-benchmark/bootstrap/centos-setup-${STARTTYPE}.sh ${BROKERIP}
EOF

exit $WARN
