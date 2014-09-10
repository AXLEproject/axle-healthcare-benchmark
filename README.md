# axle-healthcare-benchmark #

Synthetic healthcare database generator and decision support benchmark.

## Components ##

* CDA Generator and Loading Engine:
  Generate and load synthetic healthcare data
* Data Lake:
  Database containing the synthetic healthcare data
* Benchmark queries:
  Queries that can be executed on the Data Lake

### Requirements ###
* minimally 4GB RAM
* CentOS 6 or Ubuntu 12.04

## Getting started ##

### Preparation ###

* Mail info@portavita.eu for the 'axle synthetic models' password and put it in
  `axle-healthcare-benchmark/cda-generator/password.txt`

### Dataset generation (CentOS 6 only) ###

Dataset generation is performed by the CDA Generator and Loading Engine. The
Generator generates an endless stream of CDA documents. The structure and
distribution of the content of the documents is defined in a set of models in
the models/ directory.  Terminology data is read from the terminology/ directory
that defines the value types and display names of all acts and coded values.

Generated documents are processed by the Loading Engine such that they can be
loaded in a database. The engine can run in a single node or distributed setup.
Documents are transformed to SQL using the MGRID Messaging SDK, and loaded in
small databases called data ponds. Data ponds are HL7v3 Reference Information
Model (RIM) databases on which pre-processing is performed before data is
uploaded to the data lake.

For setting up a complete chain for dataset generation on a single node
(including the data lake), clone this repository in your home directory and do:

* `cd $HOME`
* `sudo axle-healthcare-benchmark/bootstrap/centos-setup-singlenode.sh`
* `sudo start axle-cdagen`

Note that this requires installing and setting up several dependencies so you
probably want this on a dedicated (virtual) machine.

### Create a data lake ###

If your main interest is getting access to a data lake and running queries on
it, you can create an (empty) data lake by running the following from the project root:

* `make prepare_database`
* `make -C lake`

Note that this involves building and running a PostgreSQL server, so make sure
there is no server already running.

To obtain an example dataset that can be loaded in the data lake, send a mail to
info@portavita.eu.

### Querying ###

Once you have a data lake with some data in it, you can run the benchmark
queries on it. They can be found in the `queries/` directory.

