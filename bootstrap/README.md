## Benchmark database bootstrapper ##

### Requires ###
See ../../README.me

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
