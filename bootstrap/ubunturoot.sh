#
# axle-healthcare-benchmark
#
# install prerequisites on Ubuntu 12.04.
#
# Copyright (c) 2013, Portavita B.V.
#

# Especially maven needs up to date package lists
apt-get update

# misc packages
apt-get install -y wget screen man htop

# packages for building postgresql
apt-get install -y git gcc bison flex gdb make
apt-get install -y libxml2-dev make libreadline-dev zlib1g-dev libossp-uuid-dev

# packages for the cda generator
# install 7 explicitly, since the generator does not work on java 6, ubuntu 12.04's default
apt-get install -y openjdk-7-jdk
update-alternatives --set java /usr/lib/jvm/java-7-openjdk-amd64/jre/bin/java
apt-get install -y maven2

# packages for the message parser
apt-get install -y zeroinstall-injector
0alias parallel http://git.savannah.gnu.org/cgit/parallel.git/plain/packager/0install/parallel.xml
add-apt-repository -y ppa:fkrull/deadsnakes
apt-get update
apt-get install -y python2.6 python2.6-dev python-lxml

# packages for ETL
apt-get install -y python-yaml python-pip
pip install shyaml

# packages for profiling
full_version=$(uname -r)
flavour_abi=${full_version#*-}
flavour=${flavour_abi#*-}
version=${full_version%-$flavour}
apt-get install -y linux-tools-common linux-tools-${version} graphviz pgagent libxslt1-dev evince
