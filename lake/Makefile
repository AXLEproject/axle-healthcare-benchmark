#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2014, MGRID BV Netherlands
#
.PHONY: reconfig dropdb createdb all lake opaque

include ../default_settings

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension

all: lake

reconfig:
	@echo "$$NONDEFAULTPOSTGRESQLCONFLAKE" >> $(PGDATA)/postgresql.conf
	PATH=$(PGSERVER)/bin:${PATH} pg_ctl reload -D $(PGDATA)

# create databases
createdb:
	./create_lake.sh $(LAKELOCALHOST) $(LAKEPORT) $(LAKEUSER) $(LAKEDB) create

dropdb:
	./create_lake.sh $(LAKELOCALHOST) $(LAKEPORT) $(LAKEUSER) $(LAKEDB) drop

lake: reconfig createdb opaque

# load some generated cdas
opaque:
	psql -h $(LAKELOCALHOST) -p $(LAKEPORT) -U $(LAKEUSER) -c "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');" $(LAKEDB)
