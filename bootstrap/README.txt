Run make all in this directory to bootstrap an empty datawarehouse.

This will:
- download the PostgreSQL git in ../database/postgresql
- compile it, install it in ../database/postgres
- initialise a cluster in ../database/data
- download and install MGRID HDL and the appropriate data models.
- create a database called 'dwh' and install datawarehouse schema
  and ETL functions in it.

To delete what this script has created:
- make stop in this directory
- delete the ../database directory and subdirectories
