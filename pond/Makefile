#
# axle-healthcare-benchmark
#
# pond database management
#
# Copyright (c) 2014, Portavita B.V.
#
include ../default_settings

.PHONY: reconfig template ponds desert clean

BASEDIR=$(shell pwd)/../$(DATABASEDIR)

TEMPLATEDB=pondtemplate
PONDCOUNT=$(shell expr `grep MHz /proc/cpuinfo | wc -l` + 2)

reconfig:
	@echo "$$NONDEFAULTPOSTGRESQLCONFPOND" >> $(PGDATA)/postgresql.conf
	PATH=$(PGSERVER)/bin:${PATH} pg_ctl reload -D $(PGDATA)

template:
	PATH=$(PGSERVER)/bin:${PATH} psql $(TEMPLATEDB) -c "SELECT 1" || PATH=$(PGSERVER)/bin:${PATH} ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) create

ponds:	reconfig template
	@echo
	@echo "CREATING DATABASES pond1 .. pond$(PONDCOUNT)"
	@echo
	for i in {1..$(PONDCOUNT)} ; do PATH=$(PGSERVER)/bin:${PATH} createdb --template=$(TEMPLATEDB) pond$$i ; PATH=$(PGSERVER)/bin:${PATH} psql postgres -c "ALTER DATABASE pond$$i SET search_path=public,pg_hl7,hl7,\"\$$user\";" ; done


desert:
	for i in {1..$(PONDCOUNT)} ; do PATH=$(PGSERVER)/bin:${PATH} psql postgres -c "DROP DATABASE IF EXISTS pond$$i" ; done
clean:	desert
	PATH=$(PGSERVER)/bin:${PATH} psql $(TEMPLATEDB) -c "SELECT 1" && PATH=$(PGSERVER)/bin:${PATH} ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) drop
