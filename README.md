# axle-healthcare-benchmark #

Synthetic healthcare database generator and decision support benchmark

### Requires ###
* minimally 4GB RAM
* Oracle JDK 7 or OpenJDK
* Maven 2.2
* CentOS 6 or Ubuntu 12.04

The project contains for CentOS and Ubuntu scripts that must be run as root,
and will take care of installing the prerequisites.

* CentOS 6
  * `yum install -y git` (as root)
  * `git clone https://github.com/AXLEproject/axle-healthcare-benchmark`
  * `bash -c axle-healthcare-benchmark/bootstrap/centosroot.sh` (as root)
* Ubuntu 12.04
  * `sudo apt-get update`
  * `sudo apt-get install -y git-core`
  * `git clone https://github.com/AXLEproject/axle-healthcare-benchmark`
  * `sudo bash -c axle-healthcare-benchmark/bootstrap/ubunturoot.sh`

# Components #

## CDA Generator ##

Generates an endless stream of CDA documents.  The structure and distribution
of the content of the documents is defined in a set of models in the models/
directory.  Terminology data is read from the terminology/ directory that
defines the value types and display names of all acts and coded values.

## Staging HL7v3 RIM database ##

The staging database is used to 'stage' the persisted CDA documents.  The XML
documents are loaded by the example CDA R2 parser that is part of the MGRID
Messaging SDK.

## Data Warehouse and ETL ##

The data warehouse follows a star schema design.  Data from the staging
database is transformed using ETL, that is programmed as stored procedures.

# Preparation #

* Mail info@portavita.eu for the 'axle synthetic models' password and put it in
  `axle-healthcare-benchmark/cda-generator/password.txt`
* Extract models with `cd axle-healthcare-benchmark/cda-generator ; bash initialize.sh`
* Configure the CDA generator
  `nano axle-healthcare-benchmark/cda-generator/src/main/resources/application.conf`
  * Configure `outputDirectory` to a suitable directory
  * Configure `numberOfCdas` to generate. (100,000 ~= 5GB datawarehouse)
* Bootstrapping the datawarehouse:
 `cd axle-healthcare-benchmark/bootstrap; make all`
 * download the PostgreSQL git in ../database/postgresql
 * compile it, install it in ../database/postgres
 * initialise a cluster in ../database/data
 * download and install MGRID HDL and the appropriate data models.
 * download and install the MGRID Messaging SDK.
 * create 'staging' and 'dwh' databases.
* `echo 'export PATH=/home/${USER}/axle-healthcare-benchmark/database/postgres/bin:${PATH}' >> ~/.bashrc`
* `source ~/.bashrc`

# Generate and load data #
* `cd axle-healthcare-benchmark/cda-generator; bash start.sh`
* `cd axle-healthcare-benchmark/datawarehouse; make opaque ; make stage ; make transform ; make pgload`

# Run queries #
* `PAGER= psql -f queries/q01.sql dwh`
* `PAGER=cat psql -f queries/q01.sql dwh`

# Delete data #
* rm -rf the output directory configured in `src/main/resources/application.conf`
* `cd axle-healthcare-benchmark/bootstrap; make stop; rm -rf ../database`
