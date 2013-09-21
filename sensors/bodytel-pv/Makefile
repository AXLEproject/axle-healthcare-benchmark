#
# Makefile
#
# Sensor input to CDA transformation.
# 1.- Bodytel PressureTel and GlucoTel to Portavita CDA templates
#
# Copyright (c) 2013, Portavita BV Netherlands
#
.PHONY: check_stagingdb prerequisites dropdb createdb all stage opaque transform

include ../../default_settings

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension

CDAOUTPUTDIR=output

SEHOST=127.0.0.1
SEPORT=5432
SEUSER=${USER}
SEDB=sensor

check_stagingdb:
	PATH=$(PGSERVER)/bin:${PATH} psql "postgresql://$(STUSER)@$(STHOST):$(STPORT)/$(STDB)" -tAqc "select 1" || (echo "Staging database is not ready" && exit 1)

check_sensordb:
	PATH=$(PGSERVER)/bin:${PATH} psql "postgresql://$(SEUSER)@$(SEHOST):$(SEPORT)/$(SEDB)" -tAqc "select 1" || make createdb_sensors

prerequisites: check_stagingdb

dropdb_sensors:
	./createdb_sensors.sh $(SEHOST) $(SEPORT) $(SEUSER) $(SEDB) $(CDAOUTPUTDIR) drop

dropdb: dropdb_sensors

createdb_sensors:
	bash -x ./createdb_sensors.sh $(SEHOST) $(SEPORT) $(SEUSER) $(SEDB) $(CDAOUTPUTDIR) create
createdb: createdb_sensors

all: createdb

transform_sensor:
	PATH=$(PGSERVER)/bin:${PATH} psql "postgresql://$(SEUSER)@$(SEHOST):$(SEPORT)/$(SEDB)" -tAqc "SELECT sensor_to_hl7v3(); SELECT writefiles()"

stage:
# todo: remove sed replacements once bugs finished in cda generator models
	time ls -d $(CDAOUTPUTDIR) | parallel "python /home/$(USER)/mgrid-messaging-0.9/cda_r2/convert_CDA_R2.py --quiet --dir={} | sed -e 's/COMPLETED/completed/' -e 's/m^2/m2/' -e 's/mmHg/mm[Hg]/' -e 's/mm Hg/mm[Hg]/' -e 's/17074200/170742000/' -e 's/18803012/88803002/' | psql -1 -h $(STHOST) -p $(STPORT) -U $(STUSER) $(STDB)" > /tmp/parse_cdas.log 2>&1
##	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "VACUUM ANALYZE" $(STDB)

clean: dropdb
	rm -rf $(CDAOUTPUTDIR)

transform:
	cd ../../datawarehouse ; $(MAKE) transform

pgload:
	cd ../../datawarehouse ; $(MAKE) pgload

gpload:
	cd ../../datawarehouse ; $(MAKE) gpload

runonce:  prerequisites check_sensordb
	$(MAKE) transform_sensor
	$(MAKE) stage
	rm $(CDAOUTPUTDIR)/*
	$(MAKE) transform
	$(MAKE) pgload

test: prerequisites check_sensordb
	PATH=$(PGSERVER)/bin:${PATH} psql "postgresql://$(SEUSER)@$(SEHOST):$(SEPORT)/$(SEDB)" -f sql/test1.sql
	$(MAKE) runonce

showdb:
	PATH=$(PGSERVER)/bin:${PATH} psql "postgresql://$(DWHUSER)@$(DWHHOST):$(DWHPORT)/$(DWHDB)" -f sql/q01.sql
