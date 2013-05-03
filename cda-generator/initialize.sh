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
   -u      URL of the path which contains the terminology and model files
EOF
}

while getopts "hu:" opt; do
	case $opt in
	h)
		usage
		exit 1
	;;
	u)
		url="$OPTARG"
	;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
	;;
	esac
done


# Download and decompress terminology
curl "$url/terminology.tar.gz" | tar xvz -C .

# Download and decompress models
curl "$url/models.tar.gz" | tar xvz -C .

# Download libraries
mkdir "lib/"
wget -O "lib/cda-builder-1.0-SNAPSHOT.jar" "$url/lib/cda-builder-1.0-SNAPSHOT.jar"
wget -O "lib/cda-marshaller-1.0-SNAPSHOT-jar-with-dependencies.jar" "$url/lib/cda-marshaller-1.0-SNAPSHOT-jar-with-dependencies.jar"
wget -O "lib/terminology-provider-1.0-SNAPSHOT-jar-with-dependencies.jar" "$url/lib/terminology-provider-1.0-SNAPSHOT-jar-with-dependencies.jar"

