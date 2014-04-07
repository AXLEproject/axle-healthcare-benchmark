#
# axle-healthcare-benchmark
#
# install xfm prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

if [ $# -ne 4 ];
then
  echo "Usage: $0 <ingress-broker-host> <broker-host> <lake-external-host> <user>"
  exit 127
fi

INGRESSBROKERHOST=$1
BROKERHOST=$2
LAKEEXTERNALHOST=$3
USER=$4


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

pip install importlib
pip install https://github.com/celery/py-amqp/archive/v1.4.4.tar.gz

sudo -u ${USER} sh -c "cd ${AXLE}/bootstrap && make installmsg"

CPUS=`grep MHz /proc/cpuinfo | wc -l`

for i in $(seq $CPUS)
do
cat > /etc/init/axle-xfm$i.conf <<EOF
description "AXLE Messaging Transformer"
start on (local-filesystems and net-device-up IFACE!=lo)
stop on runlevel [016]

respawn

script
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- python ${MESSAGING_DIR}/integration/rabbitmq/transformer.py \
    ${RABBITMQUSER} ${RABBITMQPASSWORD} ${BROKERHOST} 2>&1 | logger -t axle-xfm$i
end script
EOF

initctl start axle-xfm$i

done

