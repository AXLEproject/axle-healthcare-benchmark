/*
 * ddl-etl-functions.sql
 *
 * This file is part of the MGRID HDW sample datawarehouse release.
 *
 * Copyright (c) 2013, MGRID BV Netherlands
 */
DROP TYPE IF EXISTS dimension_name CASCADE;
CREATE TYPE dimension_name AS (
  name_family                   text
, name_given                    text
, name_prefix                   text
, name_suffix                   text
, name_delimiter                text
, name_full                     text
);
COMMENT ON TYPE dimension_name IS
'Interface type of bag_en2dimension_name functions';


CREATE OR REPLACE FUNCTION bag_en2dimension_name(name bag_en)
RETURNS dimension_name
AS $$
   SELECT ROW((c).name_family,
              (c).name_given,
              (c).name_prefix,
              (c).name_suffix,
              (c).name_delimiter,
              format('%s%s%s%s%s%s%s%s%s',
                           (c).name_prefix,
                           CASE WHEN (c).name_prefix IS NULL THEN '' ELSE ' ' END,
                           (c).name_given,
                           CASE WHEN (c).name_given IS NULL THEN '' ELSE ' ' END,
                           (c).name_delimiter,
                           CASE WHEN (c).name_delimiter IS NULL THEN '' ELSE ' ' END,
                           (c).name_family,
                           CASE WHEN (c).name_suffix IS NULL THEN '' ELSE ' ' END,
                           (c).name_suffix)
             )::dimension_name
 FROM (
   SELECT
        ROW(
                -- get the first family namepart from the first entity name
                value((family(name[1]))[1]),
                value((given(name[1]))[1]),
                value((prefix(name[1]))[1]),
                value((suffix(name[1]))[1]),
                value((delimiter(name[1]))[1]),
                NULL
                )::dimension_name) AS t(c);
$$ LANGUAGE sql
RETURNS NULL ON NULL INPUT;
COMMENT ON FUNCTION bag_en2dimension_name(bag_en) IS
'Transform RIM EntityName or RoleName to a dimension_name to be used in the DWHs dimension tables. This function must be refined by the user to select the desired name parts and assemble the fullname.';


CREATE OR REPLACE FUNCTION person_patient2dimension_name(e "Person", r "Patient")
RETURNS dimension_name
AS
$$
        SELECT CASE
               -- the role name is preferred, since it will be more specific for the role the person plays
               WHEN r."name" IS NOT NULL THEN
                    bag_en2dimension_name(r."name")
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    bag_en2dimension_name(e."name")
               ELSE
                    NULL
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION person_patient2dimension_name("Person", "Patient") IS
'Returns a dimension_name to be used when updating a patient dimension.';


CREATE OR REPLACE FUNCTION person_role2dimension_name(e "Person", r "Role")
RETURNS dimension_name
AS
$$
        SELECT CASE
               -- the role name is preferred
               WHEN r."name" IS NOT NULL THEN
                    bag_en2dimension_name(r."name")
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    bag_en2dimension_name(e."name")
               ELSE
                    NULL
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION person_role2dimension_name("Person", "Role") IS
'Returns a dimension_name to be used when updating a provider dimension.';


CREATE OR REPLACE FUNCTION organization_role2text(e "Organization", r "Role")
RETURNS text
AS
$$
        SELECT CASE
               -- the role name is preferred
               WHEN r."name" IS NOT NULL THEN
                    value((value(r.name[1]))[1])
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    value((value(e.name[1]))[1])
               ELSE
                    NULL
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION organization_role2text("Organization", "Role") IS
'Returns the text to be used when updating the name attribute of an organization dimension.';


DROP TYPE IF EXISTS dimension_address CASCADE;
CREATE TYPE dimension_address AS
( street                   text
, zipcode                text
, city                   text
, state                  text
, country                text
);
COMMENT ON TYPE dimension_name IS
'Interface type of bag_ad2dimension_address functions';


CREATE OR REPLACE FUNCTION bag_ad2dimension_address(address bag_ad)
RETURNS dimension_address
AS
$$
  SELECT ROW(
             -- get the first street address line from the first address
             value((streetaddressline(address[1]))[1]),
             value((postalcode(address[1]))[1]),
             value((city(address[1]))[1]),
             value((state(address[1]))[1]),
             value((country(address[1]))[1])
             )::dimension_address
$$ LANGUAGE SQL
RETURNS NULL ON NULL INPUT;
COMMENT ON FUNCTION bag_ad2dimension_address(bag_ad) IS
'Transform RIM EntityAddress or RoleAddress to a dimension_address to be used in the DWHs dimension tables. This function must be refined by the user to select the desired address parts.';


CREATE OR REPLACE FUNCTION organization_role2dimension_address(e "Organization", r "Role")
RETURNS dimension_address
AS
$$
        SELECT CASE
               -- the role address is preferred, since it will be more specific for the role the organization plays
               WHEN r."addr" IS NOT NULL THEN
                    bag_ad2dimension_address(r."addr")
               -- then the entity addr
               WHEN e."addr" IS NOT NULL THEN
                    bag_ad2dimension_address(e."addr")
               ELSE
                    NULL
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION organization_role2dimension_address("Organization", "Role") IS
'Returns a dimension_address to be used when updating an organization dimension.';


/* Transform RIM Person Patient combination to natural key set. */
CREATE OR REPLACE FUNCTION person_patient2set_nk(e "Person", r "Patient")
RETURNS text[]
AS
$$
        -- note: do not use a hash function here, because collisions are likely (birthday problem),
        -- and a collision means a false positive person match.

        SELECT CASE
               -- Using the role or entity id's is preferred.
               WHEN e."id" IS NOT NULL OR r."id" IS NOT NULL THEN
               -- make ii[] distinct and ordered for right equal semantics on set_ii
                  (select array_agg(x)::text[] from
                          (select distinct x from
                                  (select unnest(e."id") as x
                                   union all
                                   select unnest(r."id")
                                  ) AS y order by x
                          ) t)
               -- then the role name is preferred
               WHEN r."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(r."name")]::text[]
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(e."name")]::text[]
               ELSE
                    ARRAY[r."_id"]::text[]
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION person_patient2set_nk("Person", "Patient") IS
'Returns the natural key of a Patient and associated Person. This function must be refined by the user to select a meaningful natural key.';

/* Transform RIM Person Role combination to natural key set. */
CREATE OR REPLACE FUNCTION person_role2set_nk(e "Person", r "Role")
RETURNS text[]
AS
$$
        -- note: do not use a hash function here, because collisions are likely (birthday problem),
        -- and a collision means a false positive person match.

        SELECT CASE
               -- Using the role or entity id's is preferred.
               WHEN e."id" IS NOT NULL OR r."id" IS NOT NULL THEN
               -- make ii[] distinct and ordered for right equal semantics on set_ii
                  (select array_agg(x)::text[] from
                          (select distinct x from
                                  (select unnest(e."id") as x
                                   union all
                                   select unnest(r."id")
                                  ) AS y order by x
                          ) t)
               -- then the role name is preferred
               WHEN r."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(r."name")]::text[]
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(e."name")]::text[]
               ELSE
                    ARRAY[r."_id"]::text[]
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION person_role2set_nk("Person", "Role") IS
'Returns the natural key of a Patient and associated Person. This function must be refined by the user to select a meaningful natural key.';

/* Transform RIM Organization Role combination to natural key set. */
CREATE OR REPLACE FUNCTION organization_role2set_nk(e "Organization", r "Role")
RETURNS text[]
AS
$$
        -- note: do not use a hash function here, because collisions are likely (birthday problem),
        -- and a collision means a false positive person match.

        SELECT CASE
               -- Using the role or entity id's is preferred.
               WHEN e."id" IS NOT NULL OR r."id" IS NOT NULL THEN
               -- make ii[] distinct and ordered for right equal semantics on set_ii
                  (select array_agg(x)::text[] from
                          (select distinct x from
                                  (select unnest(e."id") as x
                                   union all
                                   select unnest(r."id")
                                  ) AS y order by x
                          ) t)
               -- then the role name is preferred
               WHEN r."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(r."name")]::text[]
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(e."name")]::text[]
               ELSE
                    ARRAY[r."_id"]::text[]
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION organization_role2set_nk("Organization", "Role") IS
'Returns the natural key of a Organization and associated Role. This function must be refined by the user to select a meaningful natural key.';

/* Transform RIM Person Role combination to natural key set. */
CREATE OR REPLACE FUNCTION orga_role2set_nk(e "Organization", r "Role")
RETURNS text[]
AS
$$
        -- note: do not use a hash function here, because collisions are likely (birthday problem),
        -- and a collision means a false positive organization match.

        SELECT CASE
               -- Using the role or entity id's is preferred.
               WHEN e."id" IS NOT NULL OR r."id" IS NOT NULL THEN
               -- make ii[] distinct and ordered for right equal semantics on set_ii
                  (select array_agg(x)::text[] from
                          (select distinct x from
                                  (select unnest(e."id") as x
                                   union all
                                   select unnest(r."id")
                                  ) AS y order by x
                          ) t)
               -- then the role name is preferred
               WHEN r."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(r."name")]::text[]
               -- then the entity name
               WHEN e."name" IS NOT NULL THEN
                    ARRAY[bag_en2dimension_name(e."name")]::text[]
               ELSE
                    ARRAY[r."_id"]::text[]
               END;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION orga_role2set_nk("Organization", "Role") IS
'Returns the natural key of a Role and associated Organiation. This function must be refined by the user to select a meaningful natural key.';


CREATE OR REPLACE FUNCTION person2gender(e "Person")
RETURNS text
AS
$$
        SELECT code(e."administrativeGenderCode")
$$
LANGUAGE SQL;
COMMENT ON FUNCTION person2gender("Person") IS
'Returns the gender code for the person to be used in the patient dimension.';


CREATE OR REPLACE FUNCTION assemble_dim_patient(e "Person", r "Patient")
RETURNS dim_patient
AS
$$
        SELECT ROW(
-- id is fixed on insert
               NULL
-- assemble set_nk
        ,      o.dpk
-- assemble gender as text
        ,      m.dpg --code(e."administrativeGenderCode")
-- assemble birthtime
        ,      (e)."birthTime"::ts::timestamptz
-- assemble name parts
        ,      (n.dpn).name_family
        ,      (n.dpn).name_given
        ,      (n.dpn).name_prefix
        ,      (n.dpn).name_suffix
        ,      (n.dpn).name_delimiter
        ,      (n.dpn).name_full
-- assemble type 2 hash
        ,      hashtext(ROW(m.dpg, (n.dpn).name_family, (n.dpn).name_given, (n.dpn).name_prefix, (n.dpn).name_suffix, (n.dpn).name_delimiter)::text)
-- valid time is set on insert/update
        ,      NULL
-- current_flag is set on insert/update
        ,      NULL
        )::dim_patient
 FROM (SELECT person_patient2dimension_name(e, r) as dpn) n
 ,    (SELECT person2gender(e) as dpg) m
 ,    (SELECT person_patient2set_nk(e,r) as dpk) o
;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION assemble_dim_patient(e "Person", r "Patient") IS
'Transforms Patient and Person attributes to dim_patient attributes.';

CREATE OR REPLACE FUNCTION assemble_dim_provider(e "Person", r "Role")
RETURNS dim_provider
AS
$$
        SELECT ROW(
-- id is fixed on insert
               NULL
-- assemble set_nk
        ,      o.dpk
-- assemble gender as text
        ,      m.dpg --code(e."administrativeGenderCode")
-- assemble effectivetime. Note: RIM < 2011 is IVL_TS, GTS otherwise.
        ,      (r)."effectiveTime"
-- assemble name parts
        ,      (n.dpn).name_family
        ,      (n.dpn).name_given
        ,      (n.dpn).name_prefix
        ,      (n.dpn).name_suffix
        ,      (n.dpn).name_delimiter
        ,      (n.dpn).name_full
-- assemble type 2 hash
        ,      hashtext(ROW(m.dpg, (n.dpn).name_family, (n.dpn).name_given, (n.dpn).name_prefix, (n.dpn).name_suffix, (n.dpn).name_delimiter)::text)
-- valid time is set on insert/update
        ,      NULL
-- current_flag is set on insert/update
        ,      NULL
        )::dim_provider
 FROM (SELECT person_role2dimension_name(e, r) as dpn) n
 ,    (SELECT person2gender(e) as dpg) m
 ,    (SELECT person_role2set_nk(e,r) as dpk) o
;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION assemble_dim_provider(e "Person", r "Role") IS
'Transforms Role and Person attributes to dim_provider attributes.';

CREATE OR REPLACE FUNCTION assemble_dim_organization(e "Organization", r "Role")
RETURNS dim_organization
AS
$$
        SELECT ROW(
-- id is fixed on insert
               NULL
-- assemble set_nk
        ,      o.dok
-- assemble effectivetime. Note: RIM < 2011 is IVL_TS, GTS otherwise.
        ,      (r)."effectiveTime"
-- assemble name parts
        ,      n.don
-- assemble address parts
        ,      (m.doa).street
        ,      (m.doa).zipcode
        ,      (m.doa).city
        ,      (m.doa).state
        ,      (m.doa).country
-- assemble type 2 hash
        ,      hashtext(ROW(n.don, (m.doa).street, (m.doa).zipcode, (m.doa).city, (m.doa).state, (m.doa).country)::text)
-- valid time is set on insert/update
        ,      NULL
-- current_flag is set on insert/update
        ,      NULL
        )::dim_organization
 FROM (SELECT organization_role2text(e,r) as don) n
 ,    (SELECT organization_role2dimension_address(e, r) as doa) m
 ,    (SELECT organization_role2set_nk(e,r) as dok) o
 ;
$$
LANGUAGE SQL;
COMMENT ON FUNCTION assemble_dim_organization(e "Organization", r "Role") IS
'Transforms Role and Organization attributes to dim_organization attributes.';



CREATE OR REPLACE FUNCTION update_dim_patient()
RETURNS text
AS $$

/** A good definition of the patients natural key (nk) is important to update
 dim_patient, since nk is used to match dim_patient records with the source
 "Patient" data.  We cannot use Patient._id as that number is local to the
 staging RIM database.  To be flexible in natural key choice, the function
 patient2nk() can be edited to generate a natural key that gives meaningful
 results on the source data.  **/

        WITH
        patient_in_new_source as (
                -- step 2: assemble the dimensional attributes
                select distinct assemble_dim_patient(e, r) as a
                from (
                      -- step 1: select distinct patients related to new acts
                      select distinct e as e, r as r
                      from "Person" e
                      right outer join "Patient" r on (r.player = e._id)
                      join only "Participation" ptcp on (ptcp.role = r._id)
                      join "Observation" n on (ptcp.act = n._id)
/* Use select codesystem('ParticipationType', 'DIR'::cv('ParticipationType'))
 * to inspect the subtree under DIR of the codesystem */
                      where "typeCode" << 'DIR'::cv('ParticipationType')
                      or    "typeCode" << 'IND'::cv('ParticipationType')
                      ) p
                )
        -- step 4: type 2 update: update the old current version and make it historic
        , type_2_update_query as (
                update dim_patient d
                set    valid_time = intervalbefore(d.valid_time, current_timestamp::ts) -- record is valid until now
                       ,      current_flag = false
                -- we also need to update all type 1 attributes, since step 5 will not update
                -- records already updated by this query.
                       ,      birthtime = (n.a).birthtime
                from   patient_in_new_source n
                where  (n.a).set_nk = d.set_nk
                and    d.current_flag = true
                 -- step 3: identify dimension records changed in their type 2 attributes
                and    (n.a).type_2_hash <> d.type_2_hash
                returning d.id, d.set_nk, d.current_flag) --, '2'::text)
        -- step 5: type 1 update: correct current and historic dimension records with the new value for the type 1 attributes
        , type_1_update_query as (
                update dim_patient d
                set    birthtime = (n.a).birthtime
                from   patient_in_new_source n
                where  (n.a).set_nk = d.set_nk
                and    (n.a).birthtime IS DISTINCT FROM d.birthtime
                returning d.id, d.set_nk, d.current_flag) --, '1'::text)
        -- step 6: insert new current version (for new dimensions and type 2 updates)
        , insert_query as (
                insert into dim_patient (set_nk, gender, birthtime,
                                        name_family, name_given, name_prefix, name_suffix, name_delimiter, name_full,
                                        type_2_hash,valid_time, current_flag)
                select   (n.a).set_nk
                       , (n.a).gender
                       , (n.a).birthtime
                       , (n.a).name_family
                       , (n.a).name_given
                       , (n.a).name_prefix
                       , (n.a).name_suffix
                       , (n.a).name_delimiter
                       , (n.a).name_full
                       , (n.a).type_2_hash
                       , ('>=' || now()::ts)::ivl_ts as valid_time
                       , true as current_flag
                from   patient_in_new_source n
                where  (n.a).set_nk not in(select set_nk from type_1_update_query where current_flag)
                and not exists (select *
                                from   dim_patient ex
                                where  ex.set_nk = (n.a).set_nk
                                and    ex.current_flag
                                -- step 3: identify dimension records changed in their type 2 attributes
                                and    ex.type_2_hash = (n.a).type_2_hash)
                returning dim_patient.id
                )
        -- note: order below is important for correct application of simultaneous type 1 and type 2 updates
        select 'type 2 updated: '  || (select count(*) from type_2_update_query) ||
               ' | new: '::text || (select count(*) from insert_query) ||
               ' | type 1 updated: '  || (select count(*) from type_1_update_query)
               as result;
$$ LANGUAGE sql;
COMMENT ON FUNCTION update_dim_patient() IS
'Load and update the patient dimension table.';

CREATE OR REPLACE FUNCTION update_dim_provider()
RETURNS text
AS $$
        WITH
        provider_in_new_source as (
                -- step 2: assemble the dimensional attributes
                select distinct assemble_dim_provider(e, r) as a
                from (
                      -- step 1: select distinct providers related to new acts
                      select distinct e as e, r as r
                      from "Person" e
                      right outer join "Role" r on (r.player = e._id)
                      join only "Participation" ptcp on (ptcp.role = r._id)
                      join "Observation" n on (ptcp.act = n._id)
                      where "typeCode" << '_ParticipationAncillary'::cv('ParticipationType')
                      or    "typeCode" << '_ParticipationInformationGenerator'::cv('ParticipationType')
                      ) p
                )
        -- step 4: type 2 update: update the old current version and make it historic
        , type_2_update_query as (
                update dim_provider d
                set    valid_time = intervalbefore(d.valid_time, current_timestamp::ts) -- record is valid until now
                       ,      current_flag = false
                -- we also need to update all type 1 attributes, since step 5 will not update
                -- records already updated by this query.
                       ,      effective_time = (n.a).effective_time
                from   provider_in_new_source n
                where  (n.a).set_nk = d.set_nk
                and    d.current_flag = true
                 -- step 3: identify dimension records changed in their type 2 attributes
                and    (n.a).type_2_hash <> d.type_2_hash
                returning d.id, d.set_nk, d.current_flag) --, '2'::text)
        -- step 5: type 1 update: correct current and historic dimension records with the new value for the type 1 attributes
        , type_1_update_query as (
                update dim_provider d
                set    effective_time = (n.a).effective_time
                from   provider_in_new_source n
                where  (n.a).set_nk = d.set_nk
                and    (n.a).effective_time IS DISTINCT FROM d.effective_time
                returning d.id, d.set_nk, d.current_flag) --, '1'::text)
        -- step 6: insert new current version (for new dimensions and type 2 updates)
        , insert_query as (
                insert into dim_provider (set_nk, gender, effective_time,
                                        name_family, name_given, name_prefix, name_suffix, name_delimiter, name_full,
                                        type_2_hash,valid_time, current_flag)
                select   (n.a).set_nk
                       , (n.a).gender
                       , (n.a).effective_time
                       , (n.a).name_family
                       , (n.a).name_given
                       , (n.a).name_prefix
                       , (n.a).name_suffix
                       , (n.a).name_delimiter
                       , (n.a).name_full
                       , (n.a).type_2_hash
                       , ('>=' || now()::ts)::ivl_ts as valid_time
                       , true as current_flag
                from   provider_in_new_source n
                where  (n.a).set_nk not in(select set_nk from type_1_update_query where current_flag)
                and not exists (select *
                                from   dim_provider ex
                                where  ex.set_nk = (n.a).set_nk
                                and    ex.current_flag
                                -- step 3: identify dimension records changed in their type 2 attributes
                                and    ex.type_2_hash = (n.a).type_2_hash)
                returning dim_provider.id
                )
        -- note: order below is important for correct application of simultaneous type 1 and type 2 updates
        select 'type 2 updated: '  || (select count(*) from type_2_update_query) ||
               ' | new: '::text || (select count(*) from insert_query) ||
               ' | type 1 updated: '  || (select count(*) from type_1_update_query)
               as result;
$$ LANGUAGE sql;
COMMENT ON FUNCTION update_dim_provider() IS
'Load and update the provider dimension table.';


CREATE OR REPLACE FUNCTION update_dim_organization()
RETURNS text
AS $$
        WITH
        organization_in_new_source as (
                -- step 2: assemble the dimensional attributes
                select distinct assemble_dim_organization(e, r) as a
                from (
                      -- step 1: select distinct organizations related to new acts
                      select distinct e as e, r as r
                      from "Organization" e
                      join "Role" r on (r.scoper = e._id)
                      join only "Participation" ptcp on (ptcp.role = r._id)
                      join "Observation" n on (ptcp.act = n._id)
                      where "typeCode" << '_ParticipationAncillary'::cv('ParticipationType')
                      or    "typeCode" << '_ParticipationInformationGenerator'::cv('ParticipationType')
                      ) p
                )
        -- step 4: type 2 update: update the old current version and make it historic
        , type_2_update_query as (
                update dim_organization d
                set    valid_time = intervalbefore(d.valid_time, current_timestamp::ts) -- record is valid until now
                       ,      current_flag = false
                -- we also need to update all type 1 attributes, since step 5 will not update
                -- records already updated by this query.
                       ,      effective_time = (n.a).effective_time
                from   organization_in_new_source n
                where  (n.a).set_nk = d.set_nk
                and    d.current_flag = true
                 -- step 3: identify dimension records changed in their type 2 attributes
                and    (n.a).type_2_hash <> d.type_2_hash
                returning d.id, d.set_nk, d.current_flag) --, '2'::text)
        -- step 5: type 1 update: correct current and historic dimension records with the new value for the type 1 attributes
        , type_1_update_query as (
                update dim_organization d
                set    effective_time = (n.a).effective_time
                from   organization_in_new_source n
                where  (n.a).set_nk = d.set_nk
                and    (n.a).effective_time IS DISTINCT FROM d.effective_time
                returning d.id, d.set_nk, d.current_flag) --, '1'::text)
        -- step 6: insert new current version (for new dimensions and type 2 updates)
        , insert_query as (
                insert into dim_organization (set_nk, effective_time,
                                        name, street, zipcode, city, state, country,
                                        type_2_hash, valid_time, current_flag)
                select   (n.a).set_nk
                       , (n.a).effective_time
                       , (n.a).name
                       , (n.a).street
                       , (n.a).zipcode
                       , (n.a).city
                       , (n.a).state
                       , (n.a).country
                       , (n.a).type_2_hash
                       , ('>=' || now()::ts)::ivl_ts as valid_time
                       , true as current_flag
                from   organization_in_new_source n
                where  (n.a).set_nk not in(select set_nk from type_1_update_query where current_flag)
                and not exists (select *
                                from   dim_organization ex
                                where  ex.set_nk = (n.a).set_nk
                                and    ex.current_flag
                                -- step 3: identify dimension records changed in their type 2 attributes
                                and    ex.type_2_hash = (n.a).type_2_hash)
                returning dim_organization.id
                )
        -- note: order below is important for correct application of simultaneous type 1 and type 2 updates
        select 'type 2 updated: '  || (select count(*) from type_2_update_query) ||
               ' | new: '::text || (select count(*) from insert_query) ||
               ' | type 1 updated: '  || (select count(*) from type_1_update_query)
               as result;
$$ LANGUAGE sql;
COMMENT ON FUNCTION update_dim_organization() IS
'Load and update the organization dimension table.';

CREATE OR REPLACE FUNCTION get_patient_sk("Person", "Patient")
RETURNS dim_patient.id%TYPE
AS $$
   SELECT id FROM dim_patient
   WHERE person_patient2set_nk($1,$2) = dim_patient.set_nk;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_patient_sk("Person", "Patient") IS
'Lookup the patients surrogate key.';

CREATE OR REPLACE FUNCTION get_provider_sk("Person","Role")
RETURNS dim_provider.id%TYPE
AS $$
    SELECT id FROM dim_provider
    WHERE person_role2set_nk($1,$2) = dim_provider.set_nk;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_provider_sk("Person","Role") IS
'Lookup the healthcare providers surrogate key.';

CREATE OR REPLACE FUNCTION get_organization_sk("Organization","Role")
RETURNS dim_organization.id%TYPE
AS $$
    SELECT id FROM dim_organization
    WHERE orga_role2set_nk($1,$2) = dim_organization.set_nk;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_organization_sk("Organization","Role") IS
'Lookup the organizations surrogate key.';


CREATE OR REPLACE FUNCTION get_time_sk(ts)
RETURNS dim_time.id%TYPE
AS $$
   WITH existing_time AS (
        SELECT id FROM dim_time
        WHERE (    isnull(orig_timestamp,'NINF') AND isnull($1,'NINF')
               OR  isnull(orig_timestamp,'PINF') AND isnull($1,'PINF')
              )
        OR (isnull(COALESCE($1,'NullFlavor.UNK'::ts),'UNK') AND isnull(orig_timestamp,'UNK'))
        OR date_trunc('minute', dim_time.orig_timestamp) = date_trunc('minute', $1)
        )
   , new_time AS (
        INSERT INTO dim_time ( day
                             , month
                             , year
                             , dow
                             , quarter
                             , hour
                             , minutes
                             , orig_timestamp
                             )
        SELECT   date_part('day', $1)
               , date_part('month', $1)
               , date_part('year', $1)
               , date_part('isodow', $1)
               , date_part('quarter', $1)
               , date_part('hour', $1)
               , date_part('minute', $1)
               , $1
        WHERE NOT EXISTS (SELECT * FROM existing_time)
        RETURNING id
        )
   select id from existing_time
   UNION ALL
   select id from new_time
;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_time_sk(ts) IS
'Lookup the time surrogate key. A new time dimension record will be created if it does not already exists.';

CREATE OR REPLACE FUNCTION get_template_id_sk(ii[])
RETURNS dim_template.id%TYPE
AS $$
   WITH existing_template_id AS (
        SELECT id FROM dim_template
        WHERE template_id = $1::text[]
   )
   , new_template_id AS (
        INSERT INTO dim_template(template_id, id_1, id_2, id_3, id_4, id_5, id_6, id_7, id_8, id_9)
        SELECT $1, $1[1], $1[2], $1[3], $1[4], $1[5], $1[6], $1[7], $1[8], $1[9]
        WHERE NOT EXISTS (SELECT * FROM existing_template_id)
        RETURNING id
   )
   SELECT id FROM existing_template_id
   UNION ALL
   SELECT id FROM new_template_id
;
$$ LANGUAGE SQL;
COMMENT ON FUNCTION get_template_id_sk(ii[]) IS 'Gets the surrogate key for and existing template_id, or inserts a row to the dim_template dimension table and returns the newly created surrogate key for this row';

-- TODO handle qualifiers
CREATE OR REPLACE FUNCTION get_concept_sk(cv)
RETURNS dim_concept.id%TYPE
AS $$
   WITH existing_concept AS (
        SELECT id FROM dim_concept
        WHERE code = code($1)
        AND   codesystem = codesystem($1)
        )
   , new_concept AS (
        INSERT INTO dim_concept (code, codesystem, codesystemname, codesystemversion, displayname, translation, qualifier)
        SELECT code($1), codesystem($1), codesystemname($1), codesystemversion($1), displayname($1), NULL, NULL
        WHERE NOT EXISTS (SELECT * FROM existing_concept)
        RETURNING id)
   select id from existing_concept
   UNION ALL
   select id from new_concept;
$$ LANGUAGE SQL
RETURNS NULL ON NULL INPUT;
COMMENT ON FUNCTION get_concept_sk(cv) IS
'Returns the id of the matching concept. If the concept is not yet present, a new one is made.';

CREATE OR REPLACE FUNCTION get_concept_sk(CD)
RETURNS dim_concept.id%TYPE
AS $$
   SELECT get_concept_sk(($1).value);
$$ LANGUAGE SQL
RETURNS NULL ON NULL INPUT;
COMMENT ON FUNCTION get_concept_sk(CD) IS
'Returns the id of the matching concept. If the concept is not yet present, a new one is made.';

CREATE OR REPLACE FUNCTION update_fact_observation_evn_pq()
RETURNS bigint
AS $$
   WITH insert_query AS (
    INSERT INTO fact_observation_evn_pq (
      act_id
    , patient_sk
    , provider_sk
    , organization_sk
    , from_time_sk
    , to_time_sk
    , effective_time
    , concept_sk
    , concept_originaltext_reference
    , concept_originaltext_value
    , template_id_sk
    , product_sk
    , code_cv
    , value_pq
    , value_pq_unit
    , value_pq_value
    , value_pq_canonical_unit
    , value_pq_canonical_value
    , timestamp
    )
    SELECT  obs.id                                                    as id
        , get_patient_sk(p,r)                                             as pat_sk
        , get_provider_sk(e_prov, r_prov)                                 as prov_sk
        , get_organization_sk(e_orga, r_prov)                             as orga_sk
        , get_time_sk(lowvalue(convexhull((obs."effectiveTime").ivl)))    as from_sk
        , get_time_sk(highvalue(convexhull((obs."effectiveTime").ivl)))   as to_sk
        , convexhull((obs."effectiveTime").ivl)                           as effectivetime
        , get_concept_sk(obs.code)                                        as concept_sk
        , value(reference(originaltext(obs.code)))                        as concept_originaltext_reference
        , value(originaltext(obs.code))                                   as concept_originaltext_value
        , get_template_id_sk(obs."templateId")                            as template_id_sk
        , get_concept_sk(obs.code)                                        as product_sk
        , value(obs.code)                                                 as code_cv
        , ((_any(value))[1])::text::pq                                    as pqval   -- value in PQ
        , unit(((_any(value))[1])::text::pq)                              as pqunit  -- unit of the PQ (text)
        , value(((_any(value))[1])::text::pq)                             as numval  -- value of the PQ (numeric)
        , unit(canonical(((_any(value))[1])::text::pq))                   as canunit -- canonical unit of the PQ (text)
        , value(canonical(((_any(value))[1])::text::pq))                  as canval-- canonical value of the PQ
        , obs._timestamp                                                  as timestamp
        FROM new_observation_evn_pq      obs
        LEFT JOIN ONLY "Participation" ptcp_pati
                ON ptcp_pati.act = obs._id
                AND ptcp_pati."typeCode" = 'RCT'::CV('ParticipationType')
                AND COALESCE(ptcp_pati."sequenceNumber", 1) = 1       -- we want the first participation of the RCT type  
        LEFT JOIN "Patient" r               ON ptcp_pati.role = r._id
        LEFT JOIN "Person" p                ON r.player = p._id
        LEFT JOIN ONLY "Participation" ptcp_prov ON ptcp_prov.act = obs._id
                 AND COALESCE(ptcp_prov."sequenceNumber", 1) = 1
                 AND (ptcp_prov."typeCode" << '_ParticipationAncillary'::cv('ParticipationType')
                     OR  ptcp_prov."typeCode" << '_ParticipationInformationGenerator'::cv('ParticipationType')
                     OR  ptcp_prov."typeCode" << '_ParticipationInformationGenerator'::cv('ParticipationType'))
        LEFT JOIN "Role"          r_prov    ON r_prov._id = ptcp_prov.role
        LEFT JOIN "Person"        e_prov    ON e_prov._id = r_prov.player
        LEFT JOIN "Organization"  e_orga    ON e_orga._id = r_prov.scoper
   returning id
  )
  SELECT count(*) from insert_query;
$$ LANGUAGE SQL
VOLATILE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION update_fact_observation_evn_pq() IS
   'Load and update the observation fact table.';

CREATE OR REPLACE FUNCTION update_fact_observation_evn_cv()
RETURNS bigint
AS $$
   WITH insert_query AS (
    INSERT INTO fact_observation_evn_cv (
      act_id
    , patient_sk
    , provider_sk
    , organization_sk
    , from_time_sk
    , to_time_sk
    , effective_time
    , concept_sk
    , concept_originaltext_reference
    , concept_originaltext_value
    , template_id_sk
    , product_sk
    , code_cv
    , value_cv
    , value_concept_sk
    , timestamp
    )
    SELECT  obs.id                                                    as id
        , get_patient_sk(p,r)                                             as pat_sk
        , get_provider_sk(e_prov, r_prov)                                 as prov_sk
        , get_organization_sk(e_orga, r_prov)                             as orga_sk
        , get_time_sk(lowvalue(convexhull((obs."effectiveTime").ivl)))    as from_sk
        , get_time_sk(highvalue(convexhull((obs."effectiveTime").ivl)))   as to_sk
        , convexhull((obs."effectiveTime").ivl)                           as effectivetime
        , get_concept_sk(obs.code)                                        as concept_sk
        , value(reference(originaltext(obs.code)))                        as concept_originaltext_reference
        , value(originaltext(obs.code))                                   as concept_originaltext_value
        , get_template_id_sk(obs."templateId")                            as template_id_sk
        , get_concept_sk(e_prod.code)                                     as product_sk
        , value(obs.code)                                                 as code_cv
        , ((_cany(value))::cd[])[1]::CV                                   as value_cv
        , get_concept_sk(((_cany(value))::cd[])[1]::CV)                   as value_concept_sk
        , obs._timestamp                                                  as timestamp
        FROM new_observation_evn_cd      obs
        LEFT JOIN ONLY "Participation" ptcp_pati
                ON ptcp_pati.act = obs._id
                AND ptcp_pati."typeCode" = 'RCT'::CV('ParticipationType')
                AND COALESCE(ptcp_pati."sequenceNumber", 1) = 1       -- we want the first participation of the RCT type  
        LEFT JOIN "Patient" r               ON ptcp_pati.role = r._id
        LEFT JOIN "Person" p                ON r.player = p._id
        LEFT JOIN ONLY "Participation" ptcp_prov ON ptcp_prov.act = obs._id
                 AND COALESCE(ptcp_prov."sequenceNumber", 1) = 1
                 AND (ptcp_prov."typeCode" << '_ParticipationAncillary'::cv('ParticipationType')
                     OR  ptcp_prov."typeCode" << '_ParticipationInformationGenerator'::cv('ParticipationType')
                     OR  ptcp_prov."typeCode" << '_ParticipationInformationGenerator'::cv('ParticipationType'))
        LEFT JOIN "Role"          r_prov    ON r_prov._id = ptcp_prov.role
        LEFT JOIN "Person"        e_prov    ON e_prov._id = r_prov.player
        LEFT JOIN "Organization"  e_orga    ON e_orga._id = r_prov.scoper
        LEFT JOIN ONLY "Participation" ptcp_prod ON ptcp_prod.act = obs._id
                  AND ptcp_prod."typeCode" = 'CSM'::CV('ParticipationType')
                  AND COALESCE(ptcp_prod."sequenceNumber",1) = 1
        LEFT JOIN "Role"          r_prod    ON r_prod._id = ptcp_prod.role
        LEFT JOIN "Entity"        e_prod    ON e_prod._id = r_prod.player
   returning id
  )
  SELECT count(*) from insert_query;
$$ LANGUAGE SQL
VOLATILE
RETURNS NULL ON NULL INPUT;

COMMENT ON FUNCTION update_fact_observation_evn_cv() IS
   'Load and update the observation fact table.';


--select a[1] from (SELECT distinct_ancestors('2.16.840.1.113883.6.96')) as a(a) order by a[1];

CREATE OR REPLACE FUNCTION setup_view_snomed_tree()
RETURNS void
AS $$
DECLARE
   concepts RECORD;
BEGIN
   EXECUTE 'DROP SCHEMA IF EXISTS view_snomed_tree CASCADE';
   EXECUTE 'CREATE SCHEMA view_snomed_tree';

   FOR concepts IN (
       WITH ans AS (
            SELECT a.*, row_number()
            OVER (ORDER BY a.cd1)
            FROM (  SELECT DISTINCT a.*
                    FROM pg_code a
                    JOIN pg_code c ON a.cdid = ANY(c.cdancestors)
                    JOIN pg_oid cs ON cs.oiid = c.cdcsid
                    WHERE ROW(c.cdcode, cs.oioid) IN
                       (SELECT code, codesystem from dim_concept d
                        JOIN fact_observation_evn o
                        ON d.id = o.concept_sk
                        OR d.id = o.value_concept_sk
                       )
                    AND  cs.oioid = '2.16.840.1.113883.6.96'
                    ) a
       )
       SELECT rtrim(overlay('000000'
                  placing row_number::text
                  from 7 - length(row_number::text)
                  for length(row_number::text)))
                  || ' ' || cdcode::text as name
            ,  rtrim(overlay('------------------------------'
                     placing cddescription
                     from array_length(cdancestors, 1)
                     for 30))
                  || CASE WHEN length(cddescription) > 0 THEN ' ' ELSE '' END
                  as comment
            ,  cdcode
       FROM ans
   )
   LOOP
       EXECUTE format('CREATE VIEW view_snomed_tree.%I AS '
                   || 'SELECT * FROM fact_observation_evn o '
                   || 'WHERE o.code_cv << ''%s''::cv(''SNOMED-CT'') '
                   || 'OR o.value_cv << ''%s''::cv(''SNOMED-CT'')',
                     concepts.name, concepts.cdcode, concepts.cdcode);
       EXECUTE format('COMMENT ON VIEW view_snomed_tree.%I IS %L',
                     concepts.name, concepts.comment);
   END LOOP;
END;
$$ LANGUAGE plpgsql
VOLATILE;
COMMENT ON FUNCTION setup_view_snomed_tree() IS
   'Creates views on the fact_observation_evn_pq table per snomed code that exist in the dim_concept plus each ancestor code. Each view contains the records in the fact_observation_evn_pq that belong to the snomed code (including child codes).'
;

--select setup_view_snomed_tree();


CREATE OR REPLACE FUNCTION setup_view_templates()
RETURNS VOID AS $$
DECLARE
    rec RECORD;
BEGIN
   EXECUTE 'DROP SCHEMA IF EXISTS view_templates CASCADE';
   EXECUTE 'CREATE SCHEMA view_templates';

    FOR rec IN SELECT template_id, template_title, tt.source FROM
                  (SELECT DISTINCT(unnest(d.template_id)) AS id
                   FROM fact_observation_evn f
                   JOIN dim_template d on f.template_id_sk = d.id
                  ) distinct_ids
                  JOIN template tt on distinct_ids.id = tt.template_id
    LOOP
        EXECUTE 'CREATE OR REPLACE VIEW view_templates."'
                        || replace(rec.template_id,'.','_') || '" AS ' ||
                'SELECT f.* FROM fact_observation_evn f
                 JOIN dim_template t ON t.id = f.template_id_sk
                 WHERE t.template_id @> ARRAY[''' || rec.template_id || ''']';
        EXECUTE format('COMMENT ON VIEW view_templates."'
                        || replace(rec.template_id,'.','_') || '" IS ''%s''',
                     rec.template_title);
        END LOOP;
END; $$ LANGUAGE plpgsql
;
COMMENT ON FUNCTION setup_view_templates() IS
   'Creates a view for each template_id used in the fact_observation_evn_pq table. Each view contains the records in the fact_observation_evn_pq that refer to this template'
   ;

CREATE OR REPLACE FUNCTION stream_etl_observation_evn()
RETURNS VOID
AS $$
DECLARE
        messages TEXT;
BEGIN
        -- first update dimensions that support type-2 changes
        messages :=  update_dim_patient();
        RAISE NOTICE 'update_dim_patient: %', messages;
        messages := update_dim_provider();
        RAISE NOTICE'update_dim_provider: %', messages;
        messages := update_dim_organization();
        RAISE NOTICE'update_dim_organizations: %', messages;
        -- next update fact tables
        messages := update_fact_observation_evn_pq();
        RAISE NOTICE'update_fact_observation_evn_pq: %', messages;
        messages := update_fact_observation_evn_cv();
        RAISE NOTICE'update_fact_observation_evn_cv: %', messages;
        -- not implemented:
        -- messages := update_fact_observation_evn_text();
        -- RAISE NOTICE'update_fact_observation_evn_text: %', messages;
        RAISE NOTICE 'setting up snomed tree & views';
        PERFORM  setup_view_snomed_tree();
        RAISE NOTICE 'setting up template views';
        PERFORM setup_view_templates();
        RAISE NOTICE 'adding view_snomed_tree and view_templates schemas to search_path';
        EXECUTE 'alter database ' || current_database() || ' set search_path = rdw, view_snomed_tree, view_templates, public, staging_rim2011, hl7_composites, pg_hl7, hl7, "$user"';
        EXECUTE 'set search_path to rdw, view_snomed_tree, view_templates, public, staging_rim2011, hl7_composites, pg_hl7, hl7, "$user"';
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION stream_etl_observation_evn() IS 'Update patient, provider, organization dimensions. Update fact observation evn tables. Recreate view schemas.';

