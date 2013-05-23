#
# axle-healthcare-benchmark
#
# install prerequisites on Ubuntu 12.04.
#
# Copyright (c) 2013, Portavita B.V.
#

apt-get update

# misc packages
apt-get install -y wget screen man htop

# packages for building postgresql
apt-get install -y git gcc bison flex gdb make
apt-get install -y libxml2-dev make libreadline-dev zlib1g-dev libossp-uuid-dev

# packages for the cda generator
apt-get install -y maven2

# packages for the message parser
apt-get install -y zeroinstall-injector
0alias parallel http://git.savannah.gnu.org/cgit/parallel.git/plain/packager/0install/parallel.xml

