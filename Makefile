#
# axle-healthcare-benchmark
#
# master makefile
#
# Copyright (c) 2013, Portavita B.V.
#
include default_settings

.PHONY: prepare prepare_database prepare_generator

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

run:
	echo "TODO"



clean_database:
	$(MAKE) -C $(BOOTSTRAPDIR) stop || echo ""
	rm -rf $(DATABASEDIR)

clean_generator:
	rm -rf $(CDAOUTPUT)

clean:	clean_generator clean_database
