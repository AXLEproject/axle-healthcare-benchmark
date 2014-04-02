#!/bin/bash
#
# Copyright (c) 2013, Portavita BV Netherlands
#

usage() {
cat << EOF
usage: $0 options

This script downloads the dependencies of the CDA generator.

OPTIONS:
   -h      Show this message
   -p      Path of password file
EOF
}

passwordPath="password.txt"
while getopts "hp" opt; do
	case $opt in
	h)
		usage
		exit 1
	;;
	p)
		passwordPath="$OPTARG"
	;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
	;;
	esac
done


mkdir "encrypted"

# Encrypt terminology
tar cvz terminology | openssl aes-256-cbc -salt -out encrypted/terminology.tar.gz.enc -pass file:"$passwordPath"

# Encrypt models
tar cvz models | openssl aes-256-cbc -salt -out encrypted/models.tar.gz.enc -pass file:"$passwordPath"

# Encrypt libraries
openssl aes-256-cbc -salt -in lib/message-builders-1.0-SNAPSHOT-jar-with-dependencies.jar -out encrypted/message-builders-1.0-SNAPSHOT-jar-with-dependencies.jar.enc -pass file:"$passwordPath"
openssl aes-256-cbc -salt -out encrypted/terminology-provider-1.0-SNAPSHOT-jar-with-dependencies.jar.enc -in lib/terminology-provider-1.0-SNAPSHOT-jar-with-dependencies.jar.enc -pass file:"$passwordPath"

