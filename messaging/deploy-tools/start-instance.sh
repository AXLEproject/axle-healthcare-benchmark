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

if [ $# -ne 13 ];
then
    echo "Usage: $0 <ami> <amiusername> <keypairname> <keypairfile> <region> <instancetype> <groupname> <instancename> <ingress-broker-host> <broker-host> <lake-external-host> <placement-group> <availability-zone>"
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
INGRESSBROKERHOST="$9"
BROKERHOST="${10}"
LAKEEXTERNALHOST="${11}"
PLACEMENTGROUP=${12}
AVAILABILITYZONE=${13}

# allow some settings to be passed via the environment (for testing)
SSHPORT=${SSHPORT:-22}
INSTANCEWAIT=${INSTANCEWAIT:-25}
LOGINWAIT=${LOGINWAIT:-10}

# allow setting the branch via the environment
AXLEBRANCH="${AXLEBRANCH:-topic/fawork/10TB}"

echo "Starting instance: ami $1 amiusername $2 keypairname $4 keypairuser $5 ec2_region $5 instancetype $6 groupname $7 instancename $8 ingressbrokerhost $9 brokerhost ${10} lakeexternalhost ${11} placementgroup ${12} availabilityzone ${13}"

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

RES=`ec2-run-instances ${AMI} -k ${KEYPAIRNAME} --region ${EC2_REGION} --availability-zone ${AVAILABILITYZONE} --instance-type ${INSTANCETYPE} --placement-group ${PLACEMENTGROUP}` \
	|| _error "Could not start instance ${AMI}"

echo ...
echo $RES
echo ...

INSTANCE=`echo ${RES} | tr '\n' ' ' | awk '{print $5}'`
ZONE=`euca-describe-instances --filter instance-id=${INSTANCE} | tr '\n' ' ' | awk '{print $13}'`

echo "Succesfully runned ${INSTANCE} on zone ${ZONE}"

# It takes about 30 seconds to start the instance
sleep ${INSTANCEWAIT}

while ! test `euca-describe-instances --filter instance-id=${INSTANCE} | tr '\n' ' ' | awk '{print $9}'` = "running"; do
	echo "Waiting for the instance to become running"
	sleep 5
done

IP=`euca-describe-instances --filter instance-id=${INSTANCE} | tr '\n' ' ' | awk '{print $7}'`

echo "Succesfully started ${INSTANCE} running on ip ${IP}"

# Create tags for groupname and instancename
RES=`euca-create-tags --tag groupname=${GROUPNAME} --tag instancename=${INSTANCENAME} ${INSTANCE}` \
        || _error "Could not create tags '${GROUPNAME}' and '${INSTANCENAME}' for instance ${INSTANCE} on region ${EC2_REGION}"

while ! test `nmap ${IP} -PN -p ${SSHPORT} | grep tcp | awk '{print $2}'` = "open"
do
	echo "Waiting for SSH to be available on ${IP}"
	sleep 2
done

# Need to sleep a bit more since otherwise we cannot login
sleep ${LOGINWAIT}

# On the official CentOS image we need to create the ec2-user
if [ "X$AMI" = "Xami-230b1b57" ];
then
    ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no root@${IP} <<EOF
adduser ec2-user
cp -a .ssh ~ec2-user
chown -R ec2-user.ec2-user ~ec2-user/.ssh
echo "ec2-user ALL=(ALL)  NOPASSWD: ALL" >> /etc/sudoers
exit
EOF
fi

# On the hs1.8xlarge instance we must manually mount the EBS volume
if [ "X$INSTANCETYPE" = "Xhs1.8xlarge" ];
then
    ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ec2-user@${IP} <<EOF
sudo mkfs.ext4 -m 0 /dev/xvdf
sudo sed -i 's/sdb/xvdf/' /etc/fstab
sudo mount -a
exit
EOF
fi

# The double -t is necessary to not cause sudo to given an error about
# incorrect terminal settings
ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
T=`mktemp`
sudo yum install -y git
sudo git init /media/ephemeral0/axle-healthcare-benchmark
sudo chown -R ${AMIUSERNAME}.${AMIUSERNAME} /media/ephemeral0/axle-healthcare-benchmark
sudo ln -s /media/ephemeral0/axle-healthcare-benchmark axle-healthcare-benchmark
cd axle-healthcare-benchmark && git config receive.denyCurrentBranch ignore
exit
EOF

ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
echo "export PS1=\"[\u@${GROUPNAME}-${INSTANCENAME} \W]\$ \"" >> ~/.bashrc
exit
EOF

cat >> ~/.ssh/config <<EOF
Host ${GROUPNAME}-${INSTANCENAME}
  HostName ${IP}
  Port ${SSHPORT}
  User ${AMIUSERNAME}
  IdentityFile ${KEYPAIR}
  StrictHostKeyChecking no
EOF

pushd $(git rev-parse --show-cdup)
git remote add ${GROUPNAME}-${INSTANCENAME} ssh://${GROUPNAME}-${INSTANCENAME}/home/${AMIUSERNAME}/axle-healthcare-benchmark
git push ${GROUPNAME}-${INSTANCENAME} ${AXLEBRANCH}
git remote rm ${GROUPNAME}-${INSTANCENAME}
popd

# Install axle-healthcare-benchmark project including password
STARTTYPE=`expr match "${INSTANCENAME}" '\(^[a-zA-Z]*\)'`
ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
cd axle-healthcare-benchmark
git checkout ${AXLEBRANCH}
git reset --hard
exit
EOF

# We want to run the generator from the ingress machine, so need to copy the
# password before bootstrapping, since the axle / cdagenpwd is necessary to
# download the HDL installer We also need the password to download mgrid
# software, so just copy it to all machines.
if [ "x$STARTTYPE" = "xingressbroker" -o "x$STARTTYPE" = "xingress" -o "x$STARTTYPE" = "xxfm" -o "x$STARTTYPE" = "xloader" -o "x$STARTTYPE" = "xlake" ];
then
    echo "Copying axle password for type $STARTTYPE"
    pwd
    TOPDIR=$(git rev-parse --show-cdup)
    scp -P ${SSHPORT} -i ${KEYPAIR} ${TOPDIR}/cda-generator/axle-generator-password.txt ${AMIUSERNAME}@${IP}:axle-healthcare-benchmark/cda-generator/password.txt || _error "Could not copy axle generator password"
fi

if [ "x$STARTTYPE" = "xloader" ];
then
    echo "Copying private key to loader"
    pwd
    TOPDIR=$(git rev-parse --show-cdup)
    scp -p -P ${SSHPORT} -i ${KEYPAIR} ${TOPDIR}/messaging/loader-key ${AMIUSERNAME}@${IP}:.ssh/loader-key || _error "Could not copy loader private key"
ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
cd
chmod 600 .ssh/loader-key
exit
EOF
fi

if [ "x$STARTTYPE" = "xlake" ];
then
    echo "Adding loader key to lake authorized keys"
    pwd
    TOPDIR=$(git rev-parse --show-cdup)
    PUBKEY=$(<${TOPDIR}/messaging/loader-key.pub)
    scp -p -P ${SSHPORT} -i ${KEYPAIR} ${TOPDIR}/messaging/loader-key.pub ${AMIUSERNAME}@${IP}:.ssh/loader-key.pub || _error "Could not copy loader public key"
ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
cd
cat .ssh/loader-key.pub >> .ssh/authorized_keys
chmod 600 .ssh/authorized_keys
exit
EOF
fi

# Start the setup script based on the instance name
ssh -p ${SSHPORT} -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${IP} <<EOF
cd
sudo ./axle-healthcare-benchmark/bootstrap/centos-setup-${STARTTYPE}.sh ${INGRESSBROKERHOST} ${BROKERHOST} ${LAKEEXTERNALHOST} ${AMIUSERNAME}
exit
EOF

exit $WARN
