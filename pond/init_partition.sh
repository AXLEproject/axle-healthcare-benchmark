#!/bin/bash
#
# Copyright (c) 2013, MGRID BV Netherlands
#
# Prepare a "staging" database on a tranzoom messageloader to be a
# partition. To that end, we ensure that the ids used to create inserts are
# disjunct over an entire mgrid.
#
PARTITIONS=4096
DATABASE=$1
NUMBER=$2

# bigint is signed 8 bit integer, so a 2^64-1 space from 2^63-1 to -2^63

# Determine partition size.
PARTSIZE=$(echo "(2^64)  / ${PARTITIONS}" | bc)
PARTSTART=$(echo "(-2^63) + (${NUMBER} * ${PARTSIZE})" | bc)
PARTSTOP=$(echo "(-2^63) + ((${NUMBER} + 1) * ${PARTSIZE}) - 1" | bc)
SEQNAME=$(psql -d ${DATABASE} -tc "SELECT pg_get_serial_sequence('\"InfrastructureRoot\"', '_id')")

cat <<EOF
Partition size is ${PARTSIZE}
Partition ${NUMBER} ranges from [${PARTSTART}; ${PARTSTOP}]
EOF

# Adjust sequence
psql -d ${DATABASE} -c "ALTER SEQUENCE ${SEQNAME} MINVALUE ${PARTSTART} START WITH ${PARTSTART} RESTART WITH ${PARTSTART} MAXVALUE ${PARTSTOP} NO CYCLE INCREMENT BY 1"

