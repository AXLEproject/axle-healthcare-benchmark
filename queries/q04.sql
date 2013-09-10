-- DATABASE staging

SET search_path=public,etl,staging_rim2011,view_snomed_tree,view_templates,hl7_composites,pg_hl7,hl7,"$user";

-- Update the organization dimension
SELECT create_temp_tables();
SELECT update_dim_organization();
