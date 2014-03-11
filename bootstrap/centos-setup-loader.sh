#
# axle-healthcare-benchmark
#
# install loader prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#
if [ $# -ne 4 ];
then
  echo "Usage: $0 <ingress-broker-host> <broker-host> <lake-external-host> <user>"
  exit 127
fi

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

MESSAGING_DIR=${AXLE}/messaging

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

# packages for building postgresql
yum install -y git gcc bison flex gdb make readline-devel zlib-devel uuid-devel

# packages for profiling
yum install -y perf graphviz readline-devel zlib-devel pgagent_92 libxslt-devel

# package for autorestart SSH tunnels (to lake)
yum install -y autossh

yum install -y java-1.7.0-openjdk

rpm -Uvh http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/0.13.1/sbt.rpm

sudo -u ${USER} sh -c "cd $MESSAGING_DIR && sbt clean compile stage \
  || _error 'Could not build loader messaging software'"

# setup shared memory parameters
sh ${AXLE}/bootstrap/sysctl.sh

# bootstrap the database server software and cluster
sudo -u ${USER} sh -c -c "cd ${AXLE}/bootstrap && make && echo \"export PATH=\\\${PATH}:${PGSERVER}/bin\" >> ~/.bashrc"

# create pond databases
sudo -iu ${USER} sh -c "cd ${AXLE}/pond && make ponds"

# setup tunnel to lake
cat > /etc/init/axle-laketunnel.conf <<EOF
description "AXLE Data Pond to Lake Tunneling"
start on (local-filesystems and net-device-up IFACE!=lo)
stop on runlevel [016]

respawn

script
  exec su -l -c "autossh -M 0 -N -i ~/.ssh/loader-key -L${LAKELOCALPORT}:${LAKELOCALHOST}:5432 \
    -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=4 ${LAKEUSER}@${LAKEEXTERNALHOST}" \
    ${USER}
end script
EOF

initctl start axle-laketunnel

CPUS=`grep MHz /proc/cpuinfo | wc -l`

for i in $(seq $CPUS)
do
cat > /etc/init/axle-loader$i.conf <<EOF
description "AXLE Messaging Loader"
start on started axle-laketunnel
stop on runlevel [016]
respawn
expect fork

script
  exec su -l -c "(source /home/$USER/.bashrc; cd $MESSAGING_DIR && ./target/start \
    -Dconfig.rabbitmq.host=${BROKERHOST} \
    -Dconfig.pond.dbhost=${PONDHOST} \
    -Dconfig.pond.dbname=${PONDDBPREFIX}${i} \
    -Dconfig.pond.dbuser=${PONDUSER} \
    -Dconfig.lake.dbhost=${LAKELOCALHOST} \
    -Dconfig.lake.dbname=${LAKEDB} \
    -Dconfig.lake.dbport=${LAKELOCALPORT} \
    -Dconfig.lake.dbuser=${LAKEUSER} \
    net.mgrid.tranzoom.ccloader.LoaderApplication 2>&1 | logger -t axle-loader$i)" \
    ${USER}
end script
EOF

  initctl start axle-loader$i
done

# pgserver is already started but make sure it survives reboot
cat > /etc/init/pgserver.conf <<EOF
description "PostgreSQL server"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
    exec su -c "cd ${BASEDIR} && ${PGSERVER}/bin/pg_ctl -D ./data -l logfile start" ${USER}
end script
EOF
