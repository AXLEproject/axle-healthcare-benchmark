#
# axle-healthcare-benchmark
#
# bootstrap script
#
# Copyright (c) 2013, Portavita B.V.
#
include ../default_settings

.PHONY: prepare start stop psql login installhdl installmsg installquantile installbinning installblocksample

BASEDIR=$(shell pwd)/../$(DATABASEDIR)
AXLEPWD=$(shell cat ../$(CDAGENERATOR)/password.txt)

MGRIDHDL=mgridhdl-$(MGRIDHDLVERSION)-linux-x64-installer.run
MGRIDHDLFILE=$(BASEDIR)/$(MGRIDHDL)
MGRIDHDLURL=http://www.mgrid.net/system/files/downloads/hdl/$(MGRIDHDLVERSION)/$(MGRIDHDL)
MGRIDHDLCOMPONENTS=snomedctvocab_20140131,loinc_242,hl7v3models_edition2011

MGRIDMSG=mgridmsg-$(MGRIDMSGVERSION)-linux-x64-installer.run
MGRIDMSGFILE=$(BASEDIR)/$(MGRIDMSG)
MGRIDMSGURL=http://www.mgrid.net/system/files/downloads/msg/$(MGRIDMSGVERSION)/$(MGRIDMSG)

prepare: start installhdl installmsg installhdl installbinning installquantile installblocksample

# Get PostgreSQL source code.
# Note that only HEAD is fetched
$(PGSOURCE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) ; git clone $(PGGIT) ; ln -s $(PGGITDIR) $(PGSOURCE)
	cd $(PGSOURCE) ; git checkout $(PGBRANCH)
	touch $@

# Compile PostgreSQL server
$(PGSERVER): $(PGSOURCE)
	cd $(PGSOURCE) ; ./configure --prefix=$(PGSERVER) --enable-debug --with-ossp-uuid && make clean && make -j4 && make install
	cd $(PGSOURCE)/contrib ; make -j4 && make install
	touch $@

# Get pgtune
$(PGTUNE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) && git clone --depth 1 $(PGTUNEGIT)
	touch $@

# Get quantile and binning
$(PGQUANTILE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) && git clone --depth 1 $(PGQUANTILEGIT)
	touch $@

$(PGBINNING):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) && wget $(PGBINNINGTGZ) && tar zxvf $(shell basename $(PGBINNINGTGZ)) && rm $(shell basename $(PGBINNINGTGZ))

$(PGBLOCKSAMPLE):
	mkdir -p $(BASEDIR)
	cd $(BASEDIR) && git clone --depth 1 $(PGBLOCKSAMPLEGIT)
	touch $@

# Initialise cluster
$(PGDATA): $(PGSERVER) $(PGTUNE)
	PATH=$(PGSERVER)/bin:${PATH} initdb -D $(PGDATA)
	$(PGTUNE)/pgtune -i $(PGDATA)/postgresql.conf -o $(PGDATA)/postgresql.conf -T $(PGTUNEDBTYPE) -P $(PGTUNESYSTEMTYPE) -c $(PGTUNEMAXCONN) || rm -rf $(PGDATA)
# fix removal of checkpoint_segments in 9.5 servers
# does not work on newer Makefiles. Upstream pgtune should be fixed instead
#  PATH=$(PGSERVER)/bin:${PATH} pg_config --version | egrep -E '9.3|9.4' || sed -i '/checkpoint_segments/c\max_wal_size = 1GB' $(PGDATA)/postgresql.conf
        
# Start cluster
start: $(PGDATA)
	PATH=$(PGSERVER)/bin:${PATH} pg_isready -p $(PONDPORT) -h $(PONDHOST) -U $(PONDUSER) -d "dbname=postgres" || PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) -l $(PGDATA)/logfile start

# Download HDL and HDM
$(MGRIDHDLFILE):
	wget --save-cookies cookies.txt --post-data 'name=axle&pass=$(AXLEPWD)&op=submit&form_build_id=form-eZqiGNVQiZgeVGmMosZH-iZFz8C5DwBTVygPrQ3I8cU&form_id=user_login' --delete-after http://www.mgrid.net/user/login
	wget --load-cookies cookies.txt -O $(MGRIDHDLFILE) $(MGRIDHDLURL)
	rm cookies.txt
	chmod +x $(MGRIDHDLFILE)
	touch $@

# Install HDL and some Healthcare Data Models
installhdl: $(MGRIDHDLFILE) $(PGSERVER)
	$(MGRIDHDLFILE) --pg_config_path $(PGSERVER)/bin/pg_config --mode unattended --enable-components $(MGRIDHDLCOMPONENTS)

# Download messaging SDK and install
$(MGRIDMSGFILE): login
	mkdir -p $(BASEDIR)
	wget --save-cookies cookies.txt --post-data 'name=axle&pass=$(AXLEPWD)&op=submit&form_build_id=form-eZqiGNVQiZgeVGmMosZH-iZFz8C5DwBTVygPrQ3I8cU&form_id=user_login' --delete-after http://www.mgrid.net/user/login
	wget --load-cookies cookies.txt -O $(MGRIDMSGFILE) $(MGRIDMSGURL)
	rm cookies.txt
	chmod +x $(MGRIDMSGFILE)
	touch $@

# Install messaging SDK
installmsg: $(MGRIDMSGFILE)
	$(MGRIDMSGFILE) --mode unattended

installquantile: $(PGQUANTILE) $(PGSERVER)
	cd $(PGQUANTILE) && PATH=$(PGSERVER)/bin:${PATH} make USE_PGXS=1 install

installbinning: $(PGBINNING) $(PGSERVER)
	cd $(PGBINNING) && PATH=$(PGSERVER)/bin:${PATH} make USE_PGXS=1 install

installblocksample: $(PGBLOCKSAMPLE) $(PGSERVER)
	cd $(PGBLOCKSAMPLE) && PATH=$(PGSERVER)/bin:${PATH} make USE_PGXS=1 install

# Some other useful targets
stop:
	test -d $(PGDATA) && PATH=$(PGSERVER)/bin:${PATH} pg_isready  -p $(PONDPORT) -h $(PONDHOST) -U $(PONDUSER) -d "dbname=postgres" && PATH=$(PGSERVER)/bin:${PATH} pg_ctl -w -D $(PGDATA) stop -m fast || echo ""

