#
# axle-healthcare-benchmark
#
# install loader prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#
if [ $# -ne 4 ];
then
  echo "Usage: $0 <broker-host> <dwh-user> <dwh-host> <username>"
  exit 127
fi

BROKERHOST=$1
DWHUSER=$2
DWHHOST=$3
USER=$4

DWHLOCALPORT=15432

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

# package for autorestart SSH tunnels (to dwh)
yum install -y autossh

yum install -y java-1.7.0-openjdk

rpm -Uvh http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/0.13.1/sbt.rpm

sudo -u ${USER} sh -c "cd $MESSAGING_DIR && sbt clean compile stage \
  || _error 'Could not build loader messaging software'"

# bootstrap the database server software and cluster
sudo -u ${USER} sh -c -c "cd ${AXLE}/bootstrap && make && echo \"export PATH=\\\${PATH}:${PGSERVER}/bin\" >> ~/.bashrc"

# create pond databases
sudo -iu ${USER} sh -c "cd ${AXLE}/pond && make ponds"

# setup tunnel to dwh
sudo -u ${USER} sh -c "autossh -M 0 -f -N -i ~/.ssh/loader-key -L${DWHLOCALPORT}:localhost:5432 -o StrictHostKeyChecking=no -o ServerAliveInterval=30 -o ServerAliveCountMax=4 ${DWHUSER}@${DWHHOST}"

CPUS=`grep MHz /proc/cpuinfo | wc -l`

for i in $(seq $CPUS)
do
cat > /etc/init/axle-loader$i.conf <<EOF
description "AXLE Messaging Loader"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
  su -l ${USER} -c "(source /home/$USER/.bashrc; \ cd $MESSAGING_DIR && ./target/start \
    -Dconfig.rabbitmq.host=$BROKERHOST \
    -Dconfig.pond.dbhost=localhost \
    -Dconfig.pond.dbname=pond$i \
    -Dconfig.pond.dbuser=$USER \
    -Dconfig.lake.dbhost=localhost \
    -Dconfig.lake.dbname=madrim \
    -Dconfig.lake.dbport=$DWHLOCALPORT \
    -Dconfig.lake.dbuser=$DWHUSER \
    net.mgrid.tranzoom.ccloader.LoaderApplication)" 2>&1 | logger -t axle-loader$i
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
