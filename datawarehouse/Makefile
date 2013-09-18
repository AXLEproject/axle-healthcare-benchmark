#
# Makefile
#
# This file is part of the MGRID HDW sample datawarehouse release.
#
# Copyright (c) 2013, MGRID BV Netherlands
#
.PHONY: dropdb createdb all gpload pgload stage opaque transform

include ../default_settings

SHAREDIR=$(shell pg_config --sharedir)
EXTENSIONDIR= $(SHAREDIR)/extension

# create databases
dropdb_prestaging:
	./create_prestaging.sh $(PSTHOST) $(PSTPORT) $(PSTUSER) $(PSTDB) drop
dropdb_staging:
	./create_staging.sh $(STHOST) $(STPORT) $(STUSER) $(STDB) drop  $(DWHHOST) $(DWHPORT) $(DWHDB)
dropdb_dwh:
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) drop
#\todo prestaging layer
dropdb: dropdb_staging dropdb_dwh

createdb_prestaging:
	./create_prestaging.sh $(PSTHOST) $(PSTPORT) $(PSTUSER) $(PSTDB) create
createdb_staging:
	./create_staging.sh $(STHOST) $(STPORT) $(STUSER) $(STDB) create  $(DWHHOST) $(DWHPORT) $(DWHDB)
createdb_dwh:
	./create_dwh.sh $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB) create
#\todo prestaging layer
createdb: createdb_dwh createdb_staging

all: createdb

# load some generated cdas
opaque:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT add_opaque_oid('2.16.840.1.113883.2.4.3.31.2.1');" $(STDB)
stage:
# todo: remove sed replacements once bugs finished in cda generator models
	cd ../cda-generator/output ; time ls | parallel "python /home/$(USER)/mgrid-messaging-0.9/cda_r2/convert_CDA_R2.py --quiet --dir={} | sed -e 's/m^2/m2/' -e 's/mm Hg/mm[Hg]/' -e 's/17074200/170742000/' -e 's/18803012/88803002/' | psql -1 -h $(STHOST) -p $(STPORT) -U $(STUSER) $(STDB)" > /tmp/parse_cdas.log 2>&1
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "VACUUM ANALYZE" $(STDB)

transform:
	psql -h $(STHOST) -p $(STPORT) -U $(STUSER) -c "SELECT stream_etl_observation_evn(); SELECT copy_dwh_tables();" $(STDB)

gpload:
	gpload -f load_dim_concept.yaml
	gpload -f load_dim_concept_role.yaml
	gpload -f load_dim_organization.yaml
	gpload -f load_dim_patient.yaml
	gpload -f load_dim_provider.yaml
	gpload -f load_dim_template.yaml
	gpload -f load_dim_time.yaml
	gpload -f load_fact_observation_evn_cv.yaml
	gpload -f load_fact_observation_evn_pq.yaml
	gpload -f load_fact_act_evn.yaml

pgload_dim_concept:
	./pgload load_dim_concept.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dim_concept_role:
	./pgload load_dim_concept_role.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dim_organization:
	./pgload load_dim_organization.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dim_patient:
	./pgload load_dim_patient.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dim_provider:
	./pgload load_dim_provider.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dim_template:
	./pgload load_dim_template.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dim_time:
	./pgload load_dim_time.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_fact_observation_evn_cv:
	./pgload load_fact_observation_evn_cv.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_fact_observation_evn_pq:
	./pgload load_fact_observation_evn_pq.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_fact_act_evn:
	./pgload load_fact_act_evn.yaml $(DWHHOST) $(DWHPORT) $(DWHUSER) $(DWHDB)
pgload_dimensions: pgload_dim_concept pgload_dim_concept_role pgload_dim_organization pgload_dim_patient pgload_dim_provider pgload_dim_template pgload_dim_time

pgload_facts: pgload_fact_observation_evn_cv pgload_fact_observation_evn_pq pgload_fact_act_evn

pgload:
	$(MAKE) -j pgload_dimensions
	$(MAKE) -j pgload_facts
