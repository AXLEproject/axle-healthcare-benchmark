#
# axle-healthcare-benchmark
#
# install xfm prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

if [ $# -ne 1 ];
then
  echo "Usage: $0 <broker-ip>"
  exit 127
fi

BROKERIP=$1
MESSAGING_DIR=/home/ec2-user/mgrid-messaging-0.9

rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm

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
