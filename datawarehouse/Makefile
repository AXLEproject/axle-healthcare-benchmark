#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2013, MGRID BV Netherlands
#
.PHONY: dropdb createdb all

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension


PSTHOST= localhost
PSTPORT= 5432
PSTUSER= ${USER}
PSTDB= prestaging

STHOST= localhost
STPORT= 5432
STUSER= ${USER}
STDB= staging

DWHHOST= localhost
DWHPORT= 6543
DWHUSER= ${USER}
DWHDB= dwh


# create databases
dropdb_prestaging:
	./create_prestaging.sh $(PSTHOST) $(PSTPORT) $(PSTUSER) $(PSTDB) drop
dropdb_staging:
	./create_staging.sh $(STHOST) $(STPORT) $(STUSER) $(STDB) drop
dropdb_dwh:
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) drop
dropdb: dropdb_prestaging dropdb_staging dropdb_dwh

createdb_prestaging:
	./create_prestaging.sh $(PSTHOST) $(PSTPORT) $(PSTUSER) $(PSTDB) create
createdb_staging:
	./create_staging.sh $(STHOST) $(STPORT) $(STUSER) $(STDB) create
createdb_dwh:
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) create
createdb: createdb_prestaging createdb_staging createdb_dwh

all: createdb

# Add Portavita codesystem as opaque codesystem.
aoo:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');" $(STDB)

stream:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT stream_etl_observation_evn(); SELECT copy_dwh_tables();" $(STDB)
