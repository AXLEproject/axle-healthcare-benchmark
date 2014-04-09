#
# axle-healthcare-benchmark
#
# install ingress prerequisites on CentOS 6.
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

AXLEMESSAGING_DIR=${AXLE}/messaging

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/epel.repo
yum install -y curl wget htop mc joe

yum install -y java-1.7.0-openjdk

rpm -Uvh http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/0.13.1/sbt.rpm

sudo -u ${USER} sh -c "cd $AXLEMESSAGING_DIR && sbt clean compile stage" \
  || _error 'Could not build ingress messaging software'

CPUS=`grep MHz /proc/cpuinfo | wc -l`

for i in $(seq $CPUS)
do
cat > /etc/init/axle-ingress$i.conf <<EOF
description "AXLE Messaging Ingress"
start on (local-filesystems and net-device-up IFACE!=lo)
stop on runlevel [016]

respawn

script
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- $AXLEMESSAGING_DIR/target/start \
    -Dconfig.rabbitmq.gateway.host=$INGRESSBROKERHOST \
    -Dconfig.rabbitmq.tranzoom.host=$BROKERHOST \
    net.mgrid.tranzoom.ingress.IngressApplication 2>&1 | logger -t axle-ingress$i
end script
EOF

initctl start axle-ingress$i

done
