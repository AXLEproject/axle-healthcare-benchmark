#
# axle-healthcare-benchmark
#
# install broker prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm

yum install -y curl erlang

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
