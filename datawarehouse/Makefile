#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2014, MGRID BV Netherlands
#
.PHONY: dropdb createdb all gpload pgload stage opaque transform

include ../default_settings

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension

DWHHOST=localhost
DWHPORT=5432
DWHUSER=$(USER)
DWHDB=madrim

all: datawarehouse

# create databases
createdb:
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) create

dropdb:
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) drop

datawarehouse: createdb

# load some generated cdas
opaque:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');" $(STDB)
