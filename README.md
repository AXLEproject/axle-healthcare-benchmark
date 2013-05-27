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
