#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2014, MGRID BV Netherlands
#
.PHONY: dropdb createdb all opaque

include ../default_settings

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension

all: datawarehouse

# create databases
createdb:
	./create_dwh.sh $(LAKELOCALHOST) $(LAKEPORT) $(LAKEUSER) $(LAKEDB) create

dropdb:
	./create_dwh.sh $(LAKELOCALHOST) $(LAKEPORT) $(LAKEUSER) $(LAKEDB) drop

datawarehouse: createdb opaque

# load some generated cdas
opaque:
	psql -h $(LAKELOCALHOST) -p $(LAKEPORT) -U $(LAKEUSER) -c "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');" $(LAKEDB)
