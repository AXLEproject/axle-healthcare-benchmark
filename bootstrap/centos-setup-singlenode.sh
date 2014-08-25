#
# axle-healthcare-benchmark
#
# install prerequisites on CentOS 6.
#
# For a proper installation of maven, this script should be run from the home
# directory of the user that owns the axle dataset software.
#
# Copyright (c) 2013, Portavita B.V.
#

set -ex

# Error handlers
_error() {
    popd || echo -n
    echo "ERROR: $1"
    exit 1
}


if [ $# -ne 1 ];
then
    echo "Usage: $0 <userdir>"
    exit 127
fi

USERDIR="$1"
USER=$(basename ${USERDIR})

AXLE=${USERDIR}/axle-healthcare-benchmark
BASEDIR=${AXLE}/database

# ingest part of the default_settings include makefile
sed -e 's/(/{/g' -e 's/)/}/g' ${AXLE}/default_settings | sed '/shell/d' | sed -n '/^define/,$!p'  > /tmp/default_settings_bash
source /tmp/default_settings_bash

pushd ${USERDIR}

BROKERHOST=localhost
LAKEEXTERNALHOST=localhost
LAKELOCALPORT=5432
INGRESSBROKERHOST=localhost

# test assumptions

if [ ! -d ${AXLE} ];
then
    _error "axle-healthcare-benchmark should be placed in the home directory of the unprivileged user."
fi


yum install -y bc

# setup shared memory parameters
sh ${AXLE}/bootstrap/sysctl.sh

# Add EPEL repository
rpm -q epel-release || rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm

yum install -y wget screen man-pages man joe htop erlang curl \
               git gcc bison flex gdb make readline-devel zlib-devel uuid-devel \
               perf graphviz readline-devel zlib-devel pgagent_92 libxslt-devel \
               java-1.7.0-openjdk-devel python-pip python-lxml \
               httpd php autossh gettext

# Maven
if [ ! -d ${USERDIR}/bin/apache-maven* ];
then
 wget http://apache.cs.uu.nl/dist/maven/maven-3/3.2.1/binaries/apache-maven-3.2.1-bin.tar.gz
 tar xf apache-maven-3.2.1-bin.tar.gz
 mkdir bin
 mv apache-maven-3.2.1 bin
 rm -f apache-maven-3.2.1-bin.tar.gz
 cat >> .bashrc <<EOF
export M2_HOME=/home/\${USER}/bin/apache-maven-3.2.1
export M2=\${M2_HOME}/bin
export PATH=\${M2}:\${PATH}
# unset JAVA_HOME so mvn picks the (1.7) jdk from /usr/bin/java
export JAVA_HOME=
EOF
fi

# Broker
rpm -q rabbitmq-server || \
    rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.4/rabbitmq-server-3.2.4-1.noarch.rpm

mkdir -p /etc/rabbitmq
cat > /etc/rabbitmq/rabbitmq.config <<EOF
[
  {rabbit,
   [
     {tcp_listeners, [{"127.0.0.1", 5672}]}
   ]}
].
EOF

rabbitmq-plugins enable rabbitmq_management
service rabbitmq-server restart
chkconfig rabbitmq-server on --level 2345

# Give rabbit some time to setup
sleep 1

curl -i -u guest:guest -H "content-type:application/json" -XPOST http://localhost:15672/api/definitions \
  -d @axle-healthcare-benchmark/messaging/config/rabbitmq_broker_definitions.json

# Load loader sequences in queue
pip install importlib
pip install https://github.com/celery/py-amqp/archive/v1.4.4.tar.gz
python axle-healthcare-benchmark/pond/rabbitmq_seed_pond_seq.py

# initialize cda generator
(cd ${AXLE}/${CDAGENERATOR} && ./initialize.sh)

# create upstart job for cda generator to be started manually
cat > /etc/init/axle-cdagen.conf <<EOF
description "AXLE CDA Generator"
stop on runlevel [016]

script
  export CDAGEN_RABBITHOST=${INGRESSBROKERHOST}
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- ${AXLE}/${CDAGENERATOR}/start.sh
end script
EOF


# Mgrid messaging
MESSAGING_DIR=${USERDIR}/mgrid-messaging-${MGRIDMSGVERSION}
test -d ${MESSAGING_DIR} || sudo -u ${USER} sh -c "cd ${AXLE}/bootstrap && make installmsg"

TRANSFORMERS=1
for i in $(seq $TRANSFORMERS)
do
  cat > /etc/init/axle-xfm$i.conf <<EOF
description "AXLE Messaging Transformer"
start on runlevel [2345]
stop on runlevel [016]

respawn

script
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- python ${MESSAGING_DIR}/integration/rabbitmq/transformer.py \
     ${RABBITMQUSER} ${RABBITMQPASSWORD} ${BROKERHOST} 2>&1 | logger -t axle-xfm$i
end script
EOF

  initctl start axle-xfm$i || echo 'already running'
done

# Ingress
AXLEMESSAGING_DIR=${AXLE}/messaging
rpm -q sbt || \
    rpm -Uvh http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/0.13.1/sbt.rpm
sudo -u ${USER} sh -c "cd $AXLEMESSAGING_DIR && sbt clean compile stage" \
  || _error 'Could not build ingress messaging software'

INGRESSORS=1
for i in $(seq $INGRESSORS)
do
  cat > /etc/init/axle-ingress$i.conf <<EOF
description "AXLE Messaging Ingress"
start on runlevel [2345]
stop on runlevel [016]

respawn

script
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- $AXLEMESSAGING_DIR/target/start \
    -Dconfig.rabbitmq.gateway.host=$INGRESSBROKERHOST \
    -Dconfig.rabbitmq.tranzoom.host=$BROKERHOST \
    net.mgrid.tranzoom.ingress.IngressApplication 2>&1 | logger -t axle-ingress$i
end script
EOF

  initctl start axle-ingress$i || echo 'already running'
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


# bootstrap the database server software and cluster
test -d ${PGDATA} || sudo -u ${USER} sh -c -c "cd ${AXLE}/bootstrap && make && echo \"export PATH=\\\${PATH}:${PGSERVER}/bin\" >> ~/.bashrc"

# create pond databases
sudo -iu ${USER} sh -c "cd ${AXLE}/pond && make ponds"

# create lake
sudo -iu ${USER} sh -c "cd ${AXLE}/${LAKEDIR} && make lake"

LOADERCOUNT=1
for i in $(seq $LOADERCOUNT)
do
cat > /etc/init/axle-loader$i.conf <<EOF
description "AXLE Messaging Loader"
start on runlevel [2345]
stop on runlevel [016]

respawn

script
  exec su -s /bin/sh -c 'exec "\$0" "\$@"' ${USER} -- $AXLEMESSAGING_DIR/target/start \
    -Dconfig.rabbitmq.host=${BROKERHOST} \
    -Dconfig.pond.uploadscript=${AXLE}/pond/pond_upload.sh \
    -Dconfig.pond.dbhost=${PONDHOST} \
    -Dconfig.pond.dbname=${PONDDBPREFIX}${i} \
    -Dconfig.pond.dbuser=${PONDUSER} \
    -Dconfig.lake.dbhost=${LAKELOCALHOST} \
    -Dconfig.lake.dbname=${LAKEDB} \
    -Dconfig.lake.dbport=${LAKELOCALPORT} \
    -Dconfig.lake.dbuser=${LAKEUSER} \
    net.mgrid.tranzoom.ccloader.LoaderApplication 2>&1 | logger -t axle-loader$i
end script
EOF

  initctl start axle-loader$i || echo 'already running'
done


# Add symon
rpm -q symon-mon || rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mon-2.87-1.el6.x86_64.rpm
rpm -q rrdtool || rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/rrdtool-1.4.8-2git.el6.x86_64.rpm
rpm -q syweb || rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/syweb-0.66-1.el6.x86_64.rpm
rpm -q symon-mux || rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mux-2.87-1.el6.x86_64.rpm
chkconfig --add symon
chkconfig --add symux
chkconfig --add httpd
/usr/share/symon/c_config.sh 127.0.0.1 > /etc/symon.conf

cat >/etc/symux.conf <<EOF
mux 127.0.0.1
EOF
clientdir=/var/www/symon/rrds/singlenode
cat /etc/symon.conf | sed -n "/monitor/ s/monitor/source 127.0.0.1 { accept/;s,stream .*$, datadir \"${clientdir}\"},p" >> /etc/symux.conf
mkdir -p ${clientdir}
/usr/share/symon/c_smrrds.sh all

service symon start
service symux start
service httpd start
