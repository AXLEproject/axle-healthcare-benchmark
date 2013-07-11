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
dropdb:
	./create_prestaging.sh $(PSTHOST) $(PSTPORT) $(PSTUSER) $(PSTDB) drop
	./create_staging.sh $(STHOST) $(STPORT) $(STUSER) $(STDB) drop
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) drop

createdb:
	./create_prestaging.sh $(PSTHOST) $(PSTPORT) $(PSTUSER) $(PSTDB) create
	./create_staging.sh $(STHOST) $(STPORT) $(STUSER) $(STDB) create
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) create

all: createdb
