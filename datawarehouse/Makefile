#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2013, MGRID BV Netherlands
#
.PHONY: installhdl installhdm dropdb createdb createtestcodesystems cda_r2tests carestatementtests updatedimperson makeall

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension

SRCBASEDIR= /home/mgrid
MSGSRC= $(SRCBASEDIR)/mgrid-messaging

PGHOST= localhost
PGPORT= 5432
PGUSER= ${USER}
TESTDB= dwh

# create database
dropdb:
	./create_dwh.sh $(PGHOST) $(PGPORT) $(PGUSER) $(TESTDB) drop

createdb:
	./create_dwh.sh $(PGHOST) $(PGPORT) $(PGUSER) $(TESTDB) create

createtestcodesystems:
	for i in spiritvocab_20110101 ihecc_20120504 ihepcc_r7 ; do psql -a --host $(PGHOST) --port $(PGPORT) --user $(PGUSER) $(TESTDB) -c "CREATE EXTENSION $$i" ; done

cda_r2tests:
	export IFS=":" l cd $(MSGSRC)/cda_r2 ; parallel python convert_CDA_R2.py ::: `find tests/source -name *xml` | psql $(TESTDB)

ccda_tests:
#	psql $(TESTDB) -c "select add_opaque_oid('2.16.840.1.113.883.5.6')" || echo ok
#	psql $(TESTDB) -c "select add_opaque_oid('2.16.840.1.113883.6.88')" || echo ok
	export IFS=":" ; cd $(MSGSRC)/ccda ; parallel python convert_CCDA.py ::: `find tests/source -name *xml` | psql $(TESTDB)

carestatementtests:
	cd $(MSGSRC)/carestatement ; parallel python convert_REPC_MT000100UV01.py ::: `find tests/source -name *xml` | psql testhdw

etl:
	psql $(TESTDB) -f run-etl.sql

all: createdb createtestcodesystems ccda_tests
