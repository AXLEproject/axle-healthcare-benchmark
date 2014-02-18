#
# axle-healthcare-benchmark
#
# install xfm prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

if [ $# -ne 2 ];
then
  echo "Usage: $0 <broker-ip> <username>"
  exit 127
fi

BROKERIP=$1
USER=$2

AXLE=/home/${USER}/axle-healthcare-benchmark
BASEDIR=${AXLE}/database

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ${AXLE}/default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash
source /tmp/default_settings_bash

_error() {
    echo "ERROR: $1"
    exit 1
}

MESSAGING_DIR=/home/ec2-user/mgrid-messaging-0.9

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

yum install -y python-pip python-lxml

pip install importlib kombu

tar -xvf axle-healthcare-benchmark/messaging/mgrid-messaging-0.9.tar.gz

cat > /etc/init/axle-xfm.conf <<EOF
description "AXLE Messaging Transformer"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
  cd $MESSAGING_DIR && python integration/rabbitmq/transformer.py -n $BROKERIP
end script
EOF

initctl start axle-xfm
