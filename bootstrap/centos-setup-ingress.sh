#
# axle-healthcare-benchmark
#
# install ingress prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#
if [ $# -ne 1 ];
then
  echo "Usage: $0 <broker-ip>"
  exit 127
fi

BROKERIP=$1
MESSAGING_DIR=/home/ec2-user/axle-healthcare-benchmark/messaging

_error() {
    echo "ERROR: $1"
    exit 1
}

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y curl wget htop mc joe

yum install -y java-1.7.0-openjdk

rpm -Uvh http://repo.scala-sbt.org/scalasbt/sbt-native-packages/org/scala-sbt/sbt/0.13.1/sbt.rpm

cd /home/ec2-user
wget http://apache.cs.uu.nl/dist/maven/maven-2/2.2.1/binaries/apache-maven-2.2.1-bin.tar.gz
tar xf apache-maven-2.2.1-bin.tar.gz
mkdir bin
mv apache-maven-2.2.1 bin
rm -f apache-maven-2.2.1-bin.tar.gz
cat >> .bashrc <<EOF
export M2_HOME=/home/\${USER}/bin/apache-maven-2.2.1 
export M2=\${M2_HOME}/bin 
export PATH=\${M2}:\${PATH}
EOF

cd $MESSAGING_DIR && sbt clean compile stage \
  || _error "Could not build ingress messaging software"

cat > /etc/init/axle-ingress.conf <<EOF
description "AXLE Messaging Ingress"
start on runlevel [2345]
stop on runlevel [016]
respawn

script
  cd $MESSAGING_DIR && ./target/start -Dconfig.rabbitmq.host=$BROKERIP net.mgrid.tranzoom.ingress.IngressApplication 2>&1 | logger -t axle-ingress
end script
EOF

initctl start axle-ingress
