#!/bin/bash
#
# axle-healthcare-benchmark
#
# Copyright (c) 2014, Portavita B.V.
#
# Perform start-instance on local VM

set -x

usage() {
cat << EOF
usage: $0 [OPTIONS]

Perform start-instance on local VM

OPTIONS:
   -h      Show this message
   -H      Hostname of VM
   -P      SSH port of VM
   -I      Instance name to test
   -K      Private key to use for SSH session
   -U      Username to use on VM
   -B      Broker hostname
   -N      LAKE username
   -D      LAKE hostname
EOF
}

VMHOST="localhost"
VMPORT="22"
INSTANCE="broker"
KEY="~/.ssh/id_rsa"
VMUSER="vagrant"
BROKERHOST="localhost"
LAKEUSER=$VMUSER
LAKEHOST="localhost"
GROUP="itest"

while getopts ":hH:P:I:K:U:B:N:D:" opt; do
        case $opt in
        h)
                usage
                exit 1
        ;;
        H)
                VMHOST=$OPTARG
        ;;
        P)
                VMPORT=$OPTARG
        ;;
        I)
                INSTANCE=$OPTARG
        ;;
        K)
                KEY=$OPTARG
        ;;
        U)
                VMUSER=$OPTARG
        ;;
        B)
                BROKERHOST=$OPTARG
        ;;
        N)
                LAKEUSER=$OPTARG
        ;;
        D)
                LAKEHOST=$OPTARG
        ;;
        \?)
                echo "Invalid option: -$OPTARG" >&2
        ;;
        esac
done

function _log {
  echo "LOCALTEST: $@" >&2
}

function euca-run-instances {
  _log "euca-run-instances $@"
  cat <<-EOF
RESERVATION	r-dc7b4f9f	736077515261
INSTANCE	i-bf4450fc	ami-ce10e0b9		ip-172-31-15-122.eu-west-1.compute.internal	pending	axle0t1.micro	2014-02-19T09:20:26.000Z	eu-west-1b	aki-71665e05			monitoring-disabled	172.31.15.122	vpc-df8861b5	subnet-dc8861b6	ebs
EOF
}

function euca-describe-instances {
  _log "euca-describe-instances $@"
  cat <<-EOF
RESERVATION	r-dc7b4f9f	736077515261
INSTANCE	i-bf4450fc	ami-ce10e0b9	$VMHOST	$VMHOST	running	axle	0		t1.micro	2014-02-19T09:20:26.000Z	eu-west-1b	aki-71665e05			monitoring-disabled	54.194.149.54	172.31.15.122	vpc-df8861b5	subnet-dc8861b6	ebs
TAG	instance	i-bf4450fc	groupname	$GROUP
TAG	instance	i-bf4450fc	instancename	$INSTANCE
EOF
}

function euca-create-tags {
  _log "euca-create-tags $@"
}

function ssh {
  _log "ssh $@"
  /usr/bin/ssh -p $VMPORT $@
}

function nmap {
  _log "nmap $@"
  cat <<-EOF
Starting Nmap 6.40 ( http://nmap.org ) at 2014-02-19 10:45 CET
Nmap scan report for $VMHOST ($VMHOST)
Host is up (0.00014s latency).
PORT   STATE SERVICE
$VMPORT/tcp open  ssh

Nmap done: 1 IP address (1 host up) scanned in 0.03 seconds
EOF
}

export SSHPORT=$VMPORT INSTANCEWAIT=0 LOGINWAIT=0

source ./start-instance.sh ami-ce10e0b9 $VMUSER $VMUSER $KEY eu-west-1 c3.large itest $INSTANCE $BROKERHOST $LAKEHOST
