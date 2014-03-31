#!/bin/sh
#
# Create an empty rim database
DB=$1 || "test"

dropdb $DB
createdb $DB
psql $DB -qc "alter database $DB set search_path=public,hl7"
psql $DB -qc "CREATE EXTENSION hl7basetable"
psql $DB -qc "CREATE EXTENSION ucum"
psql $DB -qc "CREATE EXTENSION hl7"
psql $DB -qc "CREATE EXTENSION hl7v3vocab_edition2010"
#psql $DB -qc "CREATE EXTENSION snomedctvocab_20110731"
#psql $DB -qc "CREATE EXTENSION spiritvocab_20110101"
#psql $DB -qc "CREATE EXTENSION ihepcc_r7"
#psql $DB -qc "CREATE EXTENSION loinc_2_34"
#psql $DB -qc "CREATE EXTENSION ihecc_20120504"
psql $DB -qc "CREATE EXTENSION hl7v3datatypes_r1"
psql $DB -qc "CREATE EXTENSION hl7v3rim_edition2010"
psql $DB -qc "CREATE EXTENSION hl7v3crud_edition2010"
psql $DB -qf "../pond/rim_dropforeignkeys.sql"

# load pond functions
psql $DB < ../pond/pond.sql
