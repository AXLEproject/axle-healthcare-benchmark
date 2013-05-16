# axle-healthcare-benchmark #

Synthetic healthcare database generator and decision support benchmark

### Requires ###
* minimally 4GB RAM
* Oracle JDK 7 or OpenJDK
* Maven 2.2
* Centos 6 or Ubuntu 12.04

* Centos 6
  * EPEL repository added
  * `yum install -y openssh-clients openssh-server wget screengit parallel`
  * `yum install -y make readline-devel zlib-devel uuid-devel htop man-pages man`
  * `yum install -y java-1.7.0-openjdk-devel`
  * `yum groupinstall -y "Development Tools"`
* Ubuntu 12.04
  * `apt-get install git parallel make libreadline-dev zlib1g-dev libossp-uuid-dev`
  * `apt-get install libxml2-dev flex bison gcc openssh-server`
  * `apt-get install maven2`

## CDA Generator ##

Generates an endless stream of CDA documents.
The structure and distribution of the content of the documents is defined in a set of models in the models/ directory (not provided).
Terminology data is read from the terminology/ directory that defines the value types and display names of all acts and coded values.

### Before running ###
bash initialize.sh -u &lt;required-files-url&gt;

### Running ###
* nano src/main/resources/application.conf
	* Configure outputDirectory to a suitable directory
* bash start.sh

## Benchmark database bootstrapper ##

### Bootstrap an empty datawarehouse ###
 `cd axle-healthcare-benchmark/bootstrap; make all`

This will:
* download the PostgreSQL git in ../database/postgresql
* compile it, install it in ../database/postgres
* initialise a cluster in ../database/data
* download and install MGRID HDL and the appropriate data models.
* create a database called 'dwh' and install datawarehouse schema
  and ETL functions in it.

### Delete the database cluster and data ###
 `cd axle-healthcare-benchmark/bootstrap; make stop; rm -rf ../database`
