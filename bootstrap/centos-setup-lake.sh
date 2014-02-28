#
# axle-healthcare-benchmark
#
# install lake prerequisites on CentOS 6.
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

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

# packages for building postgresql
yum install -y git gcc bison flex gdb make readline-devel zlib-devel uuid-devel

# packages for profiling
yum install -y perf graphviz readline-devel zlib-devel pgagent_92 libxslt-devel

# bootstrap the database server software and cluster
sudo -u ${USER} sh -c "cd ${AXLE}/bootstrap && make && echo \"export PATH=\\\${PATH}:${PGSERVER}/bin\" >> ~/.bashrc"

# create data warehouse
sudo -iu ${USER} sh -c "cd ${AXLE}/$LAKEDIR && make datawarehouse"

cat > /etc/init/pgserver.conf <<EOF
description "PostgreSQL server"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
    exec su -c "cd ${BASEDIR} && ${PGSERVER}/bin/pg_ctl -D ./data -l logfile start" ${USER}
end script
EOF

initctl start pgserver