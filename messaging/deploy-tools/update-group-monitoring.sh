#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, MGRID B.V.
#

#
# For the group $1, setup/update group monitoring using symon. All members of
# the group will report symon monitoring data to the group local broker. The
# broker requires an up to date symux configuration to be able accept all
# incoming data.
#
# This script gathers group wide symon monitoring configuration and updates
# symux configuration on the broker. It can be called multiple times to deal
# with changes in group structure.
#

if [ $# -ne 2 ];
then
    echo "Usage: $0 <keypairname> <groupname>"
    exit 127
fi

KEYPAIR="$1"
GROUPNAME="${2:-mytest}"
AMIUSERNAME="${AMIUSERNAME:-ec2-user}"

BROKEREXTIP=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=broker-1 | tr '\n' ' ' | awk '{print $7}'`

BROKERINTIP=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} --filter tag:instancename=broker-1 | tr '\n' ' ' | awk '{print $8}'`

INSTANCES=`euca-describe-instances  --filter instance-state-name=running --filter tag:groupname=${GROUPNAME} | grep INSTANCE | awk '{print $2":"$13";"$14}'`

T=`mktemp`

cat >${T} <<EOF
mux ${BROKEREXTIP}
EOF

# Walk across all instances in our group
for i in ${INSTANCES}; do
    instanceid=${i%:*}
    ips=${i#*:}
    externalip=${ips%;*}
    internalip=${ips#*;}
    name=`euca-describe-tags --filter key=instancename --filter resource-id=${instanceid} | awk '{print $5}'`
    echo "Retrieving configation from ${name}..."
    clientdir=/var/www/symon/rrds/${name}
    DIRS="${DIRS} ${clientdir}"

    # install, configure and start symon
    ssh -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${externalip} <<EOF
sudo rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mon-2.87-1.el6.x86_64.rpm
sudo chkconfig --add symon
sudo sh -c "/usr/share/symon/c_config.sh ${BROKERINTIP} > /etc/symon.conf"
sudo service symon restart
exit
EOF
    # and determine symux stanzas based on the local symon configuration
    ssh -T -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${externalip} >>${T} <<EOF
cat /etc/symon.conf | sed -n "/monitor/ s/monitor/source ${internalip} { accept/;s,stream .*$, datadir \"${clientdir}\"},p"
EOF
done

# Upload the newly build configuration to the broker; create all host
# directories and all referenced rrds and restart symux
echo "Updating broker symux configuration..."
cat ${T} | ssh -T -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${BROKEREXTIP} "cat > /tmp/symux.conf"

ssh -t -t -i ${KEYPAIR} -o StrictHostKeyChecking=no ${AMIUSERNAME}@${BROKEREXTIP} > group-monitoring.log <<EOF
sudo mv /tmp/symux.conf /etc/symux.conf
sudo mkdir -p ${DIRS}
sudo bash /usr/share/symon/c_smrrds.sh all
sudo service symux restart
exit
EOF

rm ${T}