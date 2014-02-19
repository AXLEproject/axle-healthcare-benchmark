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
from kombu import Connection, Exchange, Producer

partitions = 4096

# sequence number space S = sequence number space in postgres = domain of int8

S_total = 2**64-1
S_start = -2**63
S_end = 2**63 - 1

partsize = S_total / partitions

conn = Connection('pyamqp://admin:tr4nz00m@localhost//messaging')
exchange_seq = Exchange(name='sequencer', type='direct', durable=True, auto_delete=False, delivery_mode='persistent')

print("Seeding rabbitmq sequence_space with %ld partitions of %ld size"% (partitions, partsize))

with conn.Producer(conn, exchange=exchange_seq, routing_key='pond') as producer:
    for p in range(0, partitions):
        producer.publish("%ld:%ld" % ((S_start + (p * partsize)), (S_start + ((p + 1) * partsize) - 1)))
