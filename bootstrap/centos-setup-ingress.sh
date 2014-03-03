#
# axle-healthcare-benchmark
#
# install ingress prerequisites on CentOS 6.
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

MESSAGING_DIR=${AXLE}/messaging

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

yum install -y java-1.7.0-openjdk

rpm -Uvh http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/0.13.1/sbt.rpm

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

sudo -u ${USER} sh -c "cd $MESSAGING_DIR && sbt clean compile stage \
  || _error 'Could not build ingress messaging software'"

CPUS=`grep MHz /proc/cpuinfo | wc -l`

for i in $(seq $CPUS)
do
cat > /etc/init/axle-ingress$i.conf <<EOF
description "AXLE Messaging Ingress"
start on runlevel [2345]
stop on runlevel [016]
respawn
expect fork

script
  exec su -l -c "(source /home/$USER/.bashrc; cd $MESSAGING_DIR && ./target/start -Dconfig.rabbitmq.host=$BROKERHOST \
    net.mgrid.tranzoom.ingress.IngressApplication 2>&1 | logger -t axle-ingress$i)" \
    ${USER}
end script
EOF

initctl start axle-ingress$i
done
