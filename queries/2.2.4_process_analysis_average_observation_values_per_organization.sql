/*
 * query      : 2.2.4
 * description: average observation values
 * user       : care group employees and quality employees
 *
 * Copyright (c) 2014, Portavita B.V.
 */
WITH patientMetaData AS (
  SELECT ptnt._id                        AS ptnt_id
  ,      ptnt.scoper                     AS orga_enti_id
  ,      ptnt.player                     AS peso_id
  FROM   ONLY "Act"                         pcpr

  -- Get the patient
  JOIN    "Participation"                  sbj_ptcp
  ON       sbj_ptcp.act                   = pcpr._id
  AND      sbj_ptcp."typeCode"->>'code'   = 'RCT'
  JOIN    "Patient"                         ptnt
  ON       ptnt._id                       = sbj_ptcp.role

  WHERE  pcpr."classCode"->>'code'        = 'PCPR'
  AND    pcpr."moodCode"->>'code'         = 'EVN'
),
patientCountPerOrga AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric AS total
 FROM     patientMetaData
 GROUP BY orga_enti_id
),
avgObseLastYear as (
  select   pmd.orga_enti_id
  ,        oh.code
  ,        oh.codesystem
  ,        avg(oh.pq_value)          as average
  ,        stddev(oh.pq_value)       as std
  from     observation_history          oh
  join     patientMetaData              pmd
  on       pmd.ptnt_id                = oh.ptnt_id
  where    oh.effective_time_low     >= '20130501'
  and      oh.pq_value                IS NOT NULL
  and    (
              (oh.code = '103232008'    and oh.codesystem = '2.16.840.1.113883.6.96')
           or (oh.code = '8480-6'       and oh.codesystem = '2.16.840.1.113883.6.1')
           or (oh.code = '8462-4'       and oh.codesystem = '2.16.840.1.113883.6.1')
           or (oh.code = 'Portavita175' and oh.codesystem = '2.16.840.1.113883.2.4.3.31.2.1')
  )
  group by pmd.orga_enti_id, oh.code, oh.codesystem
),
hba1cAvg as (
  select   orga_enti_id, average, std from avgObseLastYear
  where    code = '103232008' and codesystem = '2.16.840.1.113883.6.96' --HbA1c
),
sysRrAvg as (
  select   orga_enti_id, average, std from avgObseLastYear
  where    code = '8480-6' and codesystem = '2.16.840.1.113883.6.1' --systolic blood pressure
),
diaRrAvg as (
  select   orga_enti_id, average, std from avgObseLastYear
  where    code = '8462-4' and codesystem = '2.16.840.1.113883.6.1' --systolic blood pressure
),
blGlucSobAvg as (
  select   orga_enti_id, average, std from avgObseLastYear
  where    code = 'Portavita175' and codesystem = '2.16.840.1.113883.2.4.3.31.2.1' --blood glucose fasting
)
select    pcpo.orga_enti_id                            as orgaEntiId
,         pcpo.total                                   as nrOfPatients
,         round(hba1cAvg.average, 2)                   as hba1cAvg
,         round(hba1cAvg.std, 2)                       as hba1cStd
,         round(sysRrAvg.average, 2)                   as sysRrAvg
,         round(sysRrAvg.std, 2)                       as sysRrStd
,         round(diaRrAvg.average, 2)                   as diaRrAvg
,         round(diaRrAvg.std, 2)                       as diaRrStd
,         round(blGlucSobAvg.average, 2)               as blGlucSobAvg
,         round(blGlucSobAvg.std, 2)                   as blGlucSobStd
from      patientCountPerOrga pcpo
left join hba1cAvg on hba1cAvg.orga_enti_id = pcpo.orga_enti_id
left join sysRrAvg on sysRrAvg.orga_enti_id = pcpo.orga_enti_id
left join diaRrAvg on diaRrAvg.orga_enti_id = pcpo.orga_enti_id
left join blGlucSobAvg on blGlucSobAvg.orga_enti_id = pcpo.orga_enti_id
;
