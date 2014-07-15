#
# Copyright (c) 2013, MGRID BV Netherlands
#
# Problem:
#
# Many loaders need to share a sequence number space S
#
# Solution: each loader retrieves a start position and after loading returns an
# end position. Multiple loaders can live in parallel by partitioning space S
# a-priori. We keep an account of which partitions are in flight, and make sure
# to return the next free partition when one is requested.
#
from amqp import Connection, Message

partitions = 4096

# sequence number space S = sequence number space in postgres = domain of int8

S_total = 2**64-1
S_start = -2**63
S_end = 2**63 - 1

partsize = S_total / partitions

print("Seeding rabbitmq sequence_space with %ld partitions of %ld size"% (partitions, partsize))

conn = Connection(host='localhost', userid='admin', password='tr4nz00m', virtual_host='/messaging')
channel = conn.channel()

for p in range(0, partitions):
    channel.basic_publish(
            Message(
                "%ld:%ld" % ((S_start + (p * partsize)), (S_start + ((p + 2) * partsize) - 1)),
                content_type='text/plain',
                content_encoding='utf-8',
                delivery_mode=2),
            exchange='sequencer',
            routing_key='pond')
