#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2014, MGRID BV Netherlands
#
.PHONY: reconfig dropdb createdb all lake opaque clean

include ../default_settings

BASEDIR=$(shell pwd)/../$(DATABASEDIR)
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

lake: reconfig createdb

clean:	dropdb
