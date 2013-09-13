#
# axle-healthcare-benchmark
#
# master makefile
#
# Copyright (c) 2013, Portavita B.V.
#
include default_settings
BASEDIR=$(shell pwd)/$(DATABASEDIR)

QUERY=1

.PHONY: prepare prepare_database prepare_generator etl stop run runone clean_database clean_generator clean

all:
	$(error Choose make prepare or make run)

prepare_database:
	$(MAKE) -C $(BOOTSTRAPDIR) prepare

prepare_generator:
	sed -i '/^#\?numberOfCdas.\+$$/s/^#\?\(.\+\) = .\+$$/\1 = $(NUMBEROFCDAS)/' $(CDAGENCONF)
	cd $(CDAGENERATOR) && bash initialize.sh && bash start.sh

etl:
	$(MAKE) -C $(DWHDIR) createdb
	$(MAKE) -C $(DWHDIR) opaque
	$(MAKE) -C $(DWHDIR) stage
	$(MAKE) -C $(DWHDIR) transform
	$(MAKE) -C $(DWHDIR) pgload

prepare: prepare_generator prepare_database etl

stop:
	$(MAKE) -C $(BOOTSTRAPDIR) stop || echo ""

run:
	echo "TODO"

runone: stop
	bash ./runone.sh $(QUERY) $(PGDATA) $(DWHDB) $(STDB) $(PERFDATADIR)

clean_database: stop
	rm -rf $(DATABASEDIR)

clean_generator:
	rm -rf $(CDAOUTPUT)

clean:	clean_generator clean_database
