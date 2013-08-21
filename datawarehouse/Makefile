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
createdb: createdb_prestaging createdb_dwh createdb_staging

all: createdb

# load some generated cdas
stage:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');" $(STDB)
# todo: remove sed replacements once bugs finished in cda generator models
	cd ../cda-generator/output ; time ls | parallel "python /home/$(USER)/mgrid-messaging-0.9/cda_r2/convert_CDA_R2.py --quiet --dir={} | sed -e 's/m^2/m2/' -e 's/mm Hg/mm[Hg]/' -e 's/17074200/170742000/' -e 's/18803012/88803002/' | psql staging" > /tmp/parse_cdas.log 2>&1

transform:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT stream_etl_observation_evn(); SELECT copy_dwh_tables();" $(STDB)

load:
	gpload -f load_dim_concept.yaml
	gpload -f load_dim_concept_role.yaml
	gpload -f load_dim_organization.yaml
	gpload -f load_dim_patient.yaml
	gpload -f load_dim_provider.yaml
	gpload -f load_dim_template.yaml
	gpload -f load_dim_time.yaml
	gpload -f load_fact_observation_evn_cv.yaml
	gpload -f load_fact_observation_evn_pq.yaml
