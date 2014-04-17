#
# axle-healthcare-benchmark
#
# install ingress broker prerequisites on CentOS 6.
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

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/epel.repo
yum install -y erlang
yum install -y curl wget htop mc joe

rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.4/rabbitmq-server-3.2.4-1.noarch.rpm

mkdir -p /etc/rabbitmq
cat > /etc/rabbitmq/rabbitmq.config <<EOF
[
  {rabbit,
   [
     {tcp_listeners, [{"0.0.0.0", 5672}]},
     {vm_memory_high_watermark, 0.4},
     {vm_memory_high_watermark_paging_ratio, 0.75},
     {disk_free_limit, 1500000000}
   ]}
].
EOF

rabbitmq-plugins enable rabbitmq_management

service rabbitmq-server restart

chkconfig rabbitmq-server on --level 2345

curl -i -u guest:guest -H "content-type:application/json" -XPOST http://localhost:15672/api/definitions \
  -d @axle-healthcare-benchmark/messaging/config/rabbitmq_broker_definitions.json

yum install -y java-1.7.0-openjdk

# Maven
cd /home/${USER}
wget http://apache.cs.uu.nl/dist/maven/maven-3/3.2.1/binaries/apache-maven-3.2.1-bin.tar.gz
tar xf apache-maven-3.2.1-bin.tar.gz
mkdir bin
mv apache-maven-3.2.1 bin
rm -f apache-maven-3.2.1-bin.tar.gz
cat >> .bashrc <<EOF
export M2_HOME=/home/\${USER}/bin/apache-maven-3.2.1
export M2=\${M2_HOME}/bin
export PATH=\${M2}:\${PATH}
EOF

# initialize cda generator
(cd $AXLE/cda-generator && ./initialize.sh)

# create upstart job for cda generator to be started manually
cat > /etc/init/axle-cdagen.conf <<EOF
description "AXLE CDA Generator"
stop on runlevel [016]

script
  export CDAGEN_RABBITHOST=${INGRESSBROKERHOST}
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- ${AXLE}/${CDAGENERATOR}/start.sh
end script
EOF

# Add symon
yum install -y httpd gettext php cairo pango dejavu-sans-mono-fonts
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/rrdtool-1.4.8-2git.el6.x86_64.rpm
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mon-2.87-1.el6.x86_64.rpm
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mux-2.87-1.el6.x86_64.rpm
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/syweb-0.66-1.el6.x86_64.rpm
chkconfig --add symon
chkconfig --add symux
chkconfig --add httpd
LOCALIP=`wget -qO- http://instance-data/latest/meta-data/local-ipv4`
/usr/share/symon/c_config.sh ${LOCALIP} > /etc/symon.conf
service symon start
service httpd start
