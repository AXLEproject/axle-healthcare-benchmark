psql pond1 -f test/entity_resolution.sql
../pond_upload.sh -n pond1 -P 15432 -N lake
psql -p 15432 lake -f postprocess/010_entity_resolution.sql
psql pond1 -f entity_resolution_2.sql
