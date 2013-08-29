#
# axle-healthcare-benchmark
#
# bootstrap script
#
# Copyright (c) 2013, Portavita B.V.
#
.PHONY: all start stop psql login

# Name of database containing datawarehouse. Note: also configure in ../datawarehouse/Makefile
DWH=dwh


PGRELEASE=9.3rc1
PGSRCTAR=postgresql-$(PGRELEASE).tar.bz2
PGSRCURL=http://ftp.postgresql.org/pub/source/v$(PGRELEASE)/$(PGSRCTAR)
PGTUNEGIT= https://github.com/gregs1104/pgtune.git

BASEDIR=$(shell pwd)/../database
DATAWAREHOUSE=$(shell pwd)/../datawarehouse
PGSOURCE=$(BASEDIR)/postgresql
PGSERVER=$(BASEDIR)/postgres
PGBRANCH=REL9_3_STABLE
PGDATA=$(BASEDIR)/data
PGTUNE=$(BASEDIR)/pgtune
PGCONN=$(shell expr 3 + `grep MHz /proc/cpuinfo | wc -l`)
AXLEPWD=$(shell cat ../cda-generator/password.txt)

MGRIDHDL=mgridhdl-1.0rc1-linux-x64-installer.run
MGRIDHDLFILE=$(BASEDIR)/$(MGRIDHDL)
MGRIDHDLURL=http://www.mgrid.net/system/files/downloads/hdl/1.0rc1/$(MGRIDHDL)
MGRIDHDLCOMPONENTS=hl7v3models_edition2011,snomedctvocab_20110731,loinc_242

MGRIDMSG=mgridmsg-0.9-linux-x64-installer.run
MGRIDMSGFILE=$(BASEDIR)/$(MGRIDMSG)
MGRIDMSGURL=http://www.mgrid.net/system/files/downloads/msg/0.9/$(MGRIDMSG)

all: start installhdl installmsg createdb

# Get PostgreSQL source code.
# Note that only HEAD is fetched
$(PGSOURCE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; wget $(PGSRCURL) ; tar jxf $(PGSRCTAR) ; ln -s postgresql-$(PGRELEASE)/ postgresql

# Compile PostgreSQL server
$(PGSERVER): $(PGSOURCE)
	cd $(PGSOURCE) ; ./configure --prefix=$(PGSERVER) --with-ossp-uuid && make clean && make -j4 && make install
	cd $(PGSOURCE)/contrib ; make -j4 && make install
	touch $@

# Get pgtune
$(PGTUNE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; git clone --depth 1 $(PGTUNEGIT)
	touch $@

# Initialise cluster
$(PGDATA): $(PGSERVER) $(PGTUNE)
	PATH=$(PGSERVER)/bin:${PATH} initdb -D $(PGDATA)
	echo "shared_preload_libraries = 'pg_stat_statements'" >> $(PGDATA)/postgresql.conf
	echo "pg_stat_statements.max = 1000" >> $(PGDATA)/postgresql.conf
	echo "pg_stat_statements.track = top" >> $(PGDATA)/postgresql.conf
	$(PGTUNE)/pgtune -i $(PGDATA)/postgresql.conf -o $(PGDATA)/postgresql.conf -T DW -P Linux -c $(PGCONN) || rm -rf $(PGDATA)

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

# Create datawarehouse
createdb: start installhdl
	cd $(DATAWAREHOUSE) ; PATH=$(PGSERVER)/bin:$${PATH} make createdb

# Download messaging SDK and install
$(MGRIDMSGFILE): login
	wget --load-cookies cookies.txt -O $(MGRIDMSGFILE) $(MGRIDMSGURL)
	chmod +x $(MGRIDMSGFILE)
	touch $@

# Install messaging SDK
installmsg: $(MGRIDMSGFILE)
	$(MGRIDMSGFILE) --mode unattended

# Some other useful targets
stop: $(PGDATA)
	PATH=$(PGSERVER)/bin:${PATH} pg_isready -d "dbname=postgres" && PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) stop -m fast

psql: start
	PATH=$(PGSERVER)/bin:${PATH} ; psql dwh
