#
# axle-healthcare-benchmark
#
# bootstrap script
#
# Copyright (c) 2013, Portavita B.V.
#
.PHONY: all start stop psql

# Name of database containing datawarehouse. Note: also configure in ../datawarehouse/Makefile
DWH=dwh

PGGIT= git://git.postgresql.org/git/postgresql.git

BASEDIR=$(shell pwd)/../database
DATAWAREHOUSE=$(shell pwd)/../datawarehouse
PGSOURCE=$(BASEDIR)/postgresql
PGSERVER=$(BASEDIR)/postgres
PGDATA=$(BASEDIR)/data

MGRIDHDL=mgridhdl-9.2-linux-x64-installer.run
MGRIDHDLFILE=$(BASEDIR)/$(MGRIDHDL)

all: start installhdl createdb

# Get PostgreSQL source code.
# Note that only HEAD is fetched
$(PGSOURCE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; git clone --depth 1 $(PGGIT)
	touch $@

# Compile PostgreSQL server
$(PGSERVER): $(PGSOURCE)
	cd $(PGSOURCE) ; ./configure --prefix=$(PGSERVER) --with-ossp-uuid && make clean && make -j4 && make install
	touch $@

# Initialise cluster
$(PGDATA): $(PGSERVER)
	PATH=$(PGSERVER)/bin:${PATH} initdb -D $(PGDATA)
	echo "TODO: proper postgresql.conf configuration for decision support setup"

# Start cluster
start: $(PGDATA)
	PATH=$(PGSERVER)/bin:${PATH} pg_isready -d postgres || PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) start

# Download HDL and HDM
$(MGRIDHDLFILE):
	wget -O $(MGRIDHDLFILE) http://www.mgrid.net/downloads/hdl/9.2/$(MGRIDHDL)
	chmod +x $(MGRIDHDLFILE)
	touch $@

# Install HDL and some Healthcare Data Models
installhdl: $(MGRIDHDLFILE) $(PGSERVER)
	$(MGRIDHDLFILE) --pg_config_path $(PGSERVER)/bin/pg_config --mode unattended --enable-components hl7v3models_edition2011,snomedctvocab_20110731,loinc_242

# Create datawarehouse
createdb: start installhdl
	cd $(DATAWAREHOUSE) ; PATH=$(PGSERVER)/bin:$${PATH} make createdb

# Some other useful targets
stop: $(PGDATA)
	PATH=$(PGSERVER)/bin:${PATH} pg_isready -d postgres && PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) stop -m fast

psql: start
	PATH=$(PGSERVER)/bin:${PATH} ; psql dwh
