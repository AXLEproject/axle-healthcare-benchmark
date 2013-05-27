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

# Add EPEL repository
rpm -Uvh http://mirrors.nl.eu.kernel.org/fedora-epel/6/x86_64/epel-release-6-8.noarch.rpm

# misc packages
yum install -y wget screen man-pages man htop

# packages for building postgresql
yum install -y git gcc bison flex gdb
yum install -y make readline-devel zlib-devel uuid-devel

# packages for the cda generator
yum install -y java-1.7.0-openjdk-devel
wget http://apache.cs.uu.nl/dist/maven/maven-2/2.2.1/binaries/apache-maven-2.2.1-bin.tar.gz
tar xf apache-maven-2.2.1-bin.tar.gz
mkdir bin
mv apache-maven-2.2.1 bin
rm -f apache-maven-2.2.1-bin.tar.gz
cat >> .bashrc <<EOF
export M2_HOME=/home/\${USER}/bin/apache-maven-2.2.1 
export M2=\${M2_HOME}/bin 
export PATH=\${M2}:$PATH 
EOF

# packages for the message parser
cat > /etc/yum.repos.d/gnupar.repo << EOF
[GNUPAR]
name=GNUPAR
baseurl=http://download.opensuse.org/repositories/home:/tange/CentOS_CentOS-6
enabled=1
gpgcheck=0
EOF
yum install -y python-lxml parallel
