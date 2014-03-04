#!/bin/sh

# Update sysctl.conf script
# Copyright (c) 2014 MGRID BV

HALFMEMINB=`grep MemTotal /proc/meminfo | awk '{print $2 * 1024 / 2}' | bc`
PAGESIZE=`getconf PAGE_SIZE`
NROFPAGES=`echo "2 * ${HALFMEMINB} / ${PAGESIZE}" | bc`
AUTOVACW=10
MAXCONN=$(expr 10 + $(grep MHz /proc/cpuinfo | wc -l))
SEMMSL=250
SEMOPM=100
SEMMNI=`echo "((${MAXCONN}+${AUTOVACW}+4)/16)*2" | bc`
SEMMNS=`echo "${SEMMNI}*${SEMMSL}" | bc`

## Update PostgreSQL sysctl settings

TMP=`mktemp`
sed '/## PostgreSQL settings start ##/,/## PostgreSQL settings end ##/d' /etc/sysctl.conf > ${TMP}

cat >> ${TMP} <<EOF
## PostgreSQL settings start ##
kernel.shmmax = ${HALFMEMINB}
kernel.shmall = ${NROFPAGES}
kernel.shmmni = 4096
fs.file-max = 327679
net.core.wmem_max = 262144
net.core.wmem_default = 262144
kernel.sem = ${SEMMSL}  ${SEMMNS}  ${SEMOPM}  ${SEMMNI}
## PostgreSQL settings end ##
EOF

mv ${TMP} /etc/sysctl.conf
sysctl -p
