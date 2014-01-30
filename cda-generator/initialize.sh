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
while getopts ":hp:" opt; do
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


# Decrypt and decompress terminology
rm -rf terminology
openssl enc -d -aes-256-cbc -salt -in encrypted/terminology.tar.gz.enc -pass file:"$passwordPath" | tar xvz -C .

# Decrypt and decompress models
rm -rf models
openssl enc -d -aes-256-cbc -salt -in encrypted/models.tar.gz.enc -pass file:"$passwordPath" | tar xvz -C .

# Decrypt libraries
mkdir "lib/"
openssl enc -d -aes-256-cbc -salt -in encrypted/terminology-provider-1.0-SNAPSHOT-jar-with-dependencies.jar.enc -out lib/terminology-provider-1.0-SNAPSHOT-jar-with-dependencies.jar -pass file:"$passwordPath"
openssl enc -d -aes-256-cbc -salt -in encrypted/message-builders-1.0-SNAPSHOT-jar-with-dependencies.jar.enc -out lib/message-builders-1.0-SNAPSHOT-jar-with-dependencies.jar -pass file:"$passwordPath"

