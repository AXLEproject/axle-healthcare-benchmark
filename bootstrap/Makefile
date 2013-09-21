#
# axle-healthcare-benchmark
#
# bootstrap script
#
# Copyright (c) 2013, Portavita B.V.
#
include ../default_settings

.PHONY: prepare start stop psql login

BASEDIR=$(shell pwd)/../$(DATABASEDIR)
AXLEPWD=$(shell cat ../$(CDAGENERATOR)/password.txt)

MGRIDHDLVERSION=1.0rc2
MGRIDHDL=mgridhdl-$(MGRIDHDLVERSION)-linux-x64-installer.run
MGRIDHDLFILE=$(BASEDIR)/$(MGRIDHDL)
MGRIDHDLURL=http://www.mgrid.net/system/files/downloads/hdl/$(MGRIDHDLVERSION)/$(MGRIDHDL)
MGRIDHDLCOMPONENTS=hl7v3models_edition2011,snomedctvocab_20110731,loinc_242

MGRIDMSG=mgridmsg-0.9-linux-x64-installer.run
MGRIDMSGFILE=$(BASEDIR)/$(MGRIDMSG)
MGRIDMSGURL=http://www.mgrid.net/system/files/downloads/msg/0.9/$(MGRIDMSG)

prepare: start installhdl installmsg installhdl

# Get PostgreSQL source code.
# Note that only HEAD is fetched
$(PGSOURCE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; wget $(PGSRCURL) ; tar jxf $(PGSRCTAR) ; ln -s postgresql-$(PGRELEASE)/ postgresql

# Compile PostgreSQL server
$(PGSERVER): $(PGSOURCE)
	cd $(PGSOURCE) ; ./configure --prefix=$(PGSERVER) --enable-debug --with-ossp-uuid --with-python && make clean && make -j4 && make install
	cd $(PGSOURCE)/contrib ; make -j4 && make install
	touch $@

# Get pgtune
$(PGTUNE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; git clone --depth 1 $(PGTUNEGIT)
	touch $@

# Get plsh and install
$(PLSH):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; git clone --depth 1 $(PLSHGIT)
	cd $(BASEDIR)/plsh && make USE_PGXS=1 install
	touch $@

# Initialise cluster
$(PGDATA): $(PGSERVER) $(PGTUNE) $(PLSH)
	PATH=$(PGSERVER)/bin:${PATH} initdb -D $(PGDATA)
	$(PGTUNE)/pgtune -i $(PGDATA)/postgresql.conf -o $(PGDATA)/postgresql.conf -T $(PGTUNEDBTYPE) -P $(PGTUNESYSTEMTYPE) -c $(PGTUNEMAXCONN) || rm -rf $(PGDATA)
	@echo "$$NONDEFAULTPOSTGRESQLCONF" >> $(PGDATA)/postgresql.conf

# Start cluster
start: $(PGDATA)
	PATH=$(PGSERVER)/bin:${PATH} pg_isready -d "dbname=postgres" || PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) -l $(PGDATA)/logfile start

login:
	wget --save-cookies cookies.txt --post-data 'name=axle&pass=$(AXLEPWD)&op=submit&form_build_id=form-eZqiGNVQiZgeVGmMosZH-iZFz8C5DwBTVygPrQ3I8cU&form_id=user_login' --delete-after http://www.mgrid.net/user/login

# Download HDL and HDM
$(MGRIDHDLFILE): login
	wget --load-cookies cookies.txt -O $(MGRIDHDLFILE) $(MGRIDHDLURL)
	chmod +x $(MGRIDHDLFILE)
	touch $@

# Install HDL and some Healthcare Data Models
installhdl: $(MGRIDHDLFILE) $(PGSERVER)
	$(MGRIDHDLFILE) --pg_config_path $(PGSERVER)/bin/pg_config --mode unattended --enable-components $(MGRIDHDLCOMPONENTS)

# Download messaging SDK and install
$(MGRIDMSGFILE): login
	wget --load-cookies cookies.txt -O $(MGRIDMSGFILE) $(MGRIDMSGURL)
	chmod +x $(MGRIDMSGFILE)
	touch $@

# Install messaging SDK
installmsg: $(MGRIDMSGFILE)
	$(MGRIDMSGFILE) --mode unattended

# Some other useful targets
stop:
	test -d $(PGDATA) && PATH=$(PGSERVER)/bin:${PATH} pg_isready -d "dbname=postgres" && PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) stop -m fast || echo ""

psql: start
	PATH=$(PGSERVER)/bin:${PATH} ; psql dwh
