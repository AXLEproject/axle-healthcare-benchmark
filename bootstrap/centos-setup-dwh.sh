#
# axle-healthcare-benchmark
#
# install dwh prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#
if [ $# -ne 1 ];
then
  echo "Usage: $0 <broker-ip>"
  exit 127
fi

BROKERIP=$1
DB_DIR=/home/ec2-user/axle-healthcare-benchmark/database
USER=ec2-user

_error() {
    echo "ERROR: $1"
    exit 1
}

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

# packages for building postgresql
yum install -y git gcc bison flex gdb
yum install -y make readline-devel zlib-devel uuid-devel

# packages for profiling
yum install -y perf graphviz readline-devel zlib-devel pgagent_92 libxslt-devel

# bootstrap the database server software and cluster
sudo -u ${USER} sh -c "cd \$HOME/axle-healthcare-benchmark/bootstrap && make && echo \"export PATH=\\\${PATH}:/home/\${USER}/axle-healthcare-benchmark/database/postgres/bin\" >> ~/.bashrc"

# create data warehouse
sudo -u ${USER} sh -c "cd \$HOME/axle-healthcare-benchmark/datawarehouse && make datawarehouse"

cat > /etc/init/axle-dwh.conf <<EOF
description "AXLE Data Warehouse"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
    exec su -c "cd ${DB_DIR} && ./postgres/bin/pg_ctl -D ./data -l logfile start" ${USER}
end script
EOF

initctl start axle-dwh
