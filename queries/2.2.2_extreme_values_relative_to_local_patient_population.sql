WITH patientMetaData AS (
  SELECT ptnt._id                                     AS ptnt_role_id
  ,      ptnt.scoper                                  AS orga_enti_id
  ,      ptnt.player                                  AS peso_id
  ,      peso."administrativeGenderCode"->>'code'     AS gender
  ,      peso."birthTime"                             AS birthTime
  FROM  "Patient"                                        ptnt
  JOIN  "Person"                                         peso
  ON     peso._id                                      = ptnt.player
),
relevantObse as (
    select   pmd.peso_id
    ,        pmd.orga_enti_id
    ,        oh.code
    ,        oh.codesystem
    ,        oh.pq_value
    ,        oh.rocky
    ,        oh.effective_time_low
    from     observation_history          oh
    join     patientMetaData              pmd
    on       pmd.ptnt_role_id           = oh.ptnt_role_id
    where    oh.pq_value               IS NOT NULL
    and    (
                (oh.code = '103232008'    and oh.codesystem = '2.16.840.1.113883.6.96')  --HbA1c
             or (oh.code = '85600001'     and oh.codesystem = '2.16.840.1.113883.6.96')  --Triglyceride
             or (oh.code = '8480-6'       and oh.codesystem = '2.16.840.1.113883.6.1')   --systolic blood pressure
    )
),
orgaAvg as (
    select   orga_enti_id
    ,        code                                                         AS code
    ,        codesystem                                                   AS codesystem
    ,        avg(pq_value)::numeric                                       AS average
    ,        stddev(pq_value)::numeric                                    AS stddev
    ,        percentile_cont(0.05) within group (order by pq_value asc)   AS percentile_5
    ,        percentile_cont(0.95) within group (order by pq_value asc)   AS percentile_95
    from     relevantObse                 ro
    group by orga_enti_id, code, codesystem
),
lastObseLastYear as (
  select   peso_id
  ,        code
  ,        codesystem
  ,        pq_value
  from     relevantObse
  where    rocky = 1 -- most recent
),
avgObseLastYear as (
  select   peso_id
  ,        code
  ,        codesystem
  ,        avg(pq_value)::numeric AS average
  from     relevantObse
  where    effective_time_low >= current_date - interval '1 year' -- of last year
  group by peso_id, code, codesystem
),
hba1cHigh as (
  select   loly.peso_id, loly.pq_value, 'Y'::text as present from lastObseLastYear loly
  join     patientMetaData pmd on pmd.peso_id = loly.peso_id
  join     orgaAvg on orgaAvg.code = loly.code and orgaAvg.orga_enti_id = pmd.orga_enti_id
  where    loly.code     = '103232008' --HbA1c
  and      loly.pq_value > orgaAvg.percentile_95
),
hba1cLow as (
  select   loly.peso_id, loly.pq_value, 'Y'::text as present from lastObseLastYear loly
  join     patientMetaData pmd on pmd.peso_id = loly.peso_id
  join     orgaAvg on orgaAvg.code = loly.code and orgaAvg.orga_enti_id = pmd.orga_enti_id
  where    loly.code     = '103232008' --HbA1c
  and      loly.pq_value < orgaAvg.percentile_5
),
triglycHigh as (
  select   loly.peso_id, loly.pq_value, 'Y'::text as present from lastObseLastYear loly
  join     patientMetaData pmd on pmd.peso_id = loly.peso_id
  join     orgaAvg on orgaAvg.code = loly.code and orgaAvg.orga_enti_id = pmd.orga_enti_id
  where    loly.code     = '85600001' --Triglyceride
  and      loly.pq_value > orgaAvg.percentile_95
),
lowMeanSysRr as (
  select   loly.peso_id, loly.average, 'Y'::text as present from avgObseLastYear loly
  join     patientMetaData pmd on pmd.peso_id = loly.peso_id
  join     orgaAvg on orgaAvg.code = loly.code and orgaAvg.orga_enti_id = pmd.orga_enti_id
  where    loly.code     = '8480-6' --systolic blood pressure
  and      loly.average < orgaAvg.percentile_5
),
highMeanSysRr as (
  select   loly.peso_id, loly.average, 'Y'::text as present from avgObseLastYear loly
  join     patientMetaData pmd on pmd.peso_id = loly.peso_id
  join     orgaAvg on orgaAvg.code = loly.code and orgaAvg.orga_enti_id = pmd.orga_enti_id
  where    loly.code     = '8480-6' --systolic blood pressure
  and      loly.average > orgaAvg.percentile_95
)
select    pmd.orga_enti_id                                                      as orgaEntiId
,         pmd.peso_id                                                           as pesoId
,         pmd.gender                                                            as gender
,         pmd.birthTime                                                         as birthTime
,         (now()::ts - "birthTime")                                             as ageInSeconds
,         round(orgaAvgHba1c.percentile_5::numeric, 2)                          as orgaHba1cLow
,         round(orgaAvgHba1c.percentile_95::numeric, 2)                         as orgaHba1cHigh
,         hba1cHigh.present                                                     as hasHba1cHigh
,         round(hba1cHigh.pq_value::numeric, 2)                                 as hba1cValue
,         hba1cLow.present                                                      as hasHba1cLow
,         round(hba1cLow.pq_value, 2)                                           as hba1cLow
,         round(orgaAvgTriglyc.percentile_5::numeric, 2)                        as orgaTriglycHigh
,         round(orgaAvgTriglyc.percentile_95::numeric, 2)                       as orgaTriglycLow
,         triglycHigh.present                                                   as hasTriglycHigh
,         triglycHigh.pq_value                                                  as triglycHigh
,         round(orgaAvgSysRr.percentile_5::numeric, 2)                          as orgaSysRrLow
,         round(orgaAvgSysRr.percentile_95::numeric, 2)                         as orgaSysRrHigh
,         lowMeanSysRr.present                                                  as hasLowMeanSysRr
,         lowMeanSysRr.average                                                  as lowMeanSysRr
,         highMeanSysRr.present                                                 as hasHighMeanSysRr
,         highMeanSysRr.average                                                 as highMeanSysRr
from      patientMetaData pmd
left join orgaAvg orgaAvgHba1c
on        orgaAvgHba1c.orga_enti_id = pmd.orga_enti_id and orgaAvgHba1c.code = '103232008' --HbA1c
left join hba1cHigh on hba1cHigh.peso_id = pmd.peso_id
left join hba1cLow on hba1cLow.peso_id = pmd.peso_id
left join orgaAvg orgaAvgTriglyc
on        orgaAvgTriglyc.orga_enti_id = pmd.orga_enti_id and orgaAvgTriglyc.code = '85600001' --Triglyceride
left join triglycHigh on triglycHigh.peso_id = pmd.peso_id
left join orgaAvg orgaAvgSysRr
on        orgaAvgSysRr.orga_enti_id = pmd.orga_enti_id and orgaAvgSysRr.code = '8480-6' --systolic blood pressure
left join lowMeanSysRr on lowMeanSysRr.peso_id = pmd.peso_id
left join highMeanSysRr on highMeanSysRr.peso_id = pmd.peso_id
-- Show only those patients that have an extreme value
where hba1cHigh.present = 'Y' or hba1cLow.present = 'Y' or triglycHigh.present = 'Y' or lowMeanSysRr.present = 'Y' or highMeanSysRr.present = 'Y'
;
