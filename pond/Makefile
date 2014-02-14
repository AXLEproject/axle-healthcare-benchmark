#
# axle-healthcare-benchmark
#
# pond database management
#
# Copyright (c) 2014, Portavita B.V.
#
include ../default_settings

BASEDIR=$(shell pwd)/../$(DATABASEDIR)

TEMPLATEDB=pondtemplate
CPUS=$(shell grep MHz /proc/cpuinfo | wc -l)


template:
	PATH=$(PGSERVER)/bin:${PATH} psql $(TEMPLATEDB) -c "SELECT 1" || PATH=$(PGSERVER)/bin:${PATH} ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) create

ponds:	template
	@echo
	@echo "DETECTED $(CPUS) CORES: CREATING DATABASES pond1 .. pond$(CPUS)"
	@echo
	for i in {1..$(CPUS)} ; do PATH=$(PGSERVER)/bin:${PATH} createdb --template=$(TEMPLATEDB) pond$$i ; PATH=$(PGSERVER)/bin:${PATH} psql postgres -c "ALTER DATABASE pond$$i SET search_path=public,pg_hl7,hl7,\"\$$user\";" ; done


desert:
	for i in {1..$(CPUS)} ; do PATH=$(PGSERVER)/bin:${PATH} psql postgres -c "DROP DATABASE IF EXISTS pond$$i" ; done
clean:	desert
	PATH=$(PGSERVER)/bin:${PATH} psql $(TEMPLATEDB) -c "SELECT 1" && PATH=$(PGSERVER)/bin:${PATH} ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) drop
