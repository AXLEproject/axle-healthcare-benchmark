#
# axle-healthcare-benchmark
#
# install xfm prerequisites on CentOS 6.
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#

yum install -y python-pip python-lxml

pip install importlib kombu

tar -xvf axle-healthcare-benchmark/messaging/mgrid-messaging-0.9.tar.gz

cd mgrid-messaging-0.9 && python integration/rabbitmq/transformer.py
