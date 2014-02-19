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
import redis

partitions = 4096

# sequence number space S = sequence number space in postgres = domain of int8

S_total = 2**64-1
S_start = -2**63
S_end = 2**63 - 1

partsize = S_total / partitions

r = redis.Redis(host='localhost',port=6379, db=0)

print("Seeding redis sequence_space with %ld partitions of %ld size"% (partitions, partsize))

for p in range(0, partitions):
    r.lpush("sequence_space", "%ld:%ld" % ((S_start + (p * partsize)), (S_start + ((p + 1) * partsize) - 1)))
