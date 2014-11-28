#!/bin/bash
#
# Copyright (c) 2014, Portavita BV Netherlands

usage() {
	echo "Usage: $0 <database_name>";
	exit 1;
}

if [ $# -lt 1 ]; then
	usage
else
	DATABASE=$1;
fi

echo "..Creating links between acts, care provisions and patients"
psql $DATABASE -f map_acts_to_pcpr.sql


echo "..Creating links between acts, care provisions and patients"
psql $DATABASE -f get_optout_consents.sql

echo "..Applying RLS policies"
psql $DATABASE -f apply_rls_policies.sql


