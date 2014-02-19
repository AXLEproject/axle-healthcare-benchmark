#
# axle-healthcare-benchmark
#
# install broker prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y erlang
yum install -y curl wget htop mc joe

rpm -Uvh http://www.rabbitmq.com/releases/rabbitmq-server/v3.2.3/rabbitmq-server-3.2.3-1.noarch.rpm

mkdir -p /etc/rabbitmq
cat > /etc/rabbitmq/rabbitmq.config <<EOF
[
  {rabbit,
   [
     {tcp_listeners, [{"0.0.0.0", 5672}]}
   ]}
].
EOF

rabbitmq-plugins enable rabbitmq_management

service rabbitmq-server restart

curl -i -u guest:guest -H "content-type:application/json" -XPOST http://localhost:15672/api/definitions \
  -d @axle-healthcare-benchmark/messaging/config/rabbitmq_broker_definitions.json

# Load loader sequences in queue
yum install -y python-pip python-lxml
pip install importlib kombu
python axle-healthcare-benchmark/pond/rabbitmq_seed_pond_seq.py

# Add symon
yum install -y httpd rrdtool php
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mon-2.87-1.el6.x86_64.rpm
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/symon-mux-2.87-1.el6.x86_64.rpm
rpm -Uhv http://wpd.home.xs4all.nl/el6/x86_64/syweb-0.65-1.el6.x86_64.rpm
chkconfig --add symon
chkconfig --add symux
chkconfig --add httpd
LOCALIP=`wget -qO- http://instance-data/latest/meta-data/local-ipv4`
/usr/share/symon/c_config.sh ${LOCALIP} > /etc/symon.conf
service symon start
service httpd start
