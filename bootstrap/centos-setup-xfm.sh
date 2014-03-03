#
# axle-healthcare-benchmark
#
# install xfm prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

if [ $# -ne 3 ];
then
  echo "Usage: $0 <broker-host> <lake-external-host> <user>"
  exit 127
fi

BROKERHOST=$1
LAKEEXTERNALHOST=$2
USER=$3

AXLE=/home/${USER}/axle-healthcare-benchmark
BASEDIR=${AXLE}/database

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ${AXLE}/default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash
source /tmp/default_settings_bash

_error() {
    echo "ERROR: $1"
    exit 1
}

MESSAGING_DIR=/home/${USER}/mgrid-messaging-${MGRIDMSGVERSION}

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

yum install -y python-pip python-lxml

pip install importlib kombu

sudo -u ${USER} sh -c "cd ${AXLE}/bootstrap && make installmsg"

CPUS=`grep MHz /proc/cpuinfo | wc -l`

for i in $(seq $CPUS)
do
cat > /etc/init/axle-xfm$i.conf <<EOF
description "AXLE Messaging Transformer"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
  exec su -l -c "(cd $MESSAGING_DIR && python integration/rabbitmq/transformer.py -n $BROKERHOST 2>&1 | logger -t axle-xfm$i)" ${USER}
end script
EOF

initctl start axle-xfm$i
done

