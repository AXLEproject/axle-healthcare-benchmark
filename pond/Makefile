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
	PATH=$(PGSERVER)/bin:${PATH} psql $(TEMPLATEDB) -c "SELECT 1" || ./create_pond.sh $(PONDHOST) $(PONDPORT) $(PONDUSER) $(TEMPLATEDB) create

ponds:	template
	for i in {1..$(CPUS)} ; do PATH=$(PGSERVER)/bin:${PATH} createdb --template=$(TEMPLATEDB) pond$$i ; done



