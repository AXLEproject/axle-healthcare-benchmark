#
# axle-healthcare-benchmark
#
# pond database management
#
# Copyright (c) 2014, Portavita B.V.
#
include ../default_settings

.PHONY: reconfig template ponds desert clean

SHELL=/bin/bash
BASEDIR=$(shell pwd)/../$(DATABASEDIR)

TEMPLATEDB=pondtemplate
# PONDCOUNT should equal LOADERCOUNT in bootstrap/centos-setup-loader.sh
PONDCOUNT=$(shell expr 2 + `grep MHz /proc/cpuinfo | wc -l`)

reconfig:
	@echo "$$NONDEFAULTPOSTGRESQLCONFPOND" >> $(PGDATA)/postgresql.conf
	PATH=$(PGSERVER)/bin:${PATH} pg_ctl reload -D $(PGDATA)

template:
	PATH=$(PGSERVER)/bin:${PATH} psql --dbname $(TEMPLATEDB) --host $(PONDHOST) --port $(PONDPORT) --user $(PONDUSER) -c "SELECT 1" || PATH=$(PGSERVER)/bin:${PATH} ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) create

ponds:	reconfig template
	@echo
	@echo "CREATING DATABASES pond1 .. pond$(PONDCOUNT)"
	@echo
	for i in {1..$(PONDCOUNT)} ; do PATH=$(PGSERVER)/bin:${PATH} createdb --template=$(TEMPLATEDB) --host $(PONDHOST) --port $(PONDPORT) --user $(PONDUSER) pond$$i ; PATH=$(PGSERVER)/bin:${PATH} psql --dbname $(TEMPLATEDB) --host $(PONDHOST) --port $(PONDPORT) --user $(PONDUSER) -c "ALTER DATABASE pond$$i SET search_path=rim2011, public, hdl,hl7, r1, \"\$$user\";" ; done

desert:
	for i in {1..$(PONDCOUNT)} ; do PATH=$(PGSERVER)/bin:${PATH} psql --dbname postgres --host $(PONDHOST) --port $(PONDPORT) --user $(PONDUSER)  -c "DROP DATABASE IF EXISTS pond$$i" ; done
clean:	desert
	PATH=$(PGSERVER)/bin:${PATH} psql --dbname $(TEMPLATEDB) --host $(PONDHOST) --port $(PONDPORT) --user $(PONDUSER) -c "SELECT 1" && PATH=$(PGSERVER)/bin:${PATH} ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) drop
