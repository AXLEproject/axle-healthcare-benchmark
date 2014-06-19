WITH patientMetaData AS (
  SELECT ptnt._id                        AS ptnt_id
  ,      ptnt.scoper                     AS orga_enti_id
  ,      ptnt.player                     AS peso_id
  FROM   ONLY "Act"                         pcpr

  -- Get the patient
  JOIN    "Participation"                   sbj_ptcp
  ON       sbj_ptcp.act                   = pcpr._id
  AND      sbj_ptcp."typeCode"->>'code'   = 'RCT'
  JOIN    "Patient"                         ptnt
  ON       ptnt._id                       = sbj_ptcp.role

  WHERE  pcpr."classCode"->>'code'        = 'PCPR'
  AND    pcpr."moodCode"->>'code'         = 'EVN' -- there are also 'INT' pcpr moodcodes for treatment plans.
),
patientCountPerOrga AS (
 SELECT   orga_enti_id
 ,        count(*)::numeric AS total
 FROM     patientMetaData
 GROUP BY orga_enti_id
),
totalAvgObseLastYear as (
  select   oh.code
  ,        oh.codesystem
  ,        avg(oh.pq_value)          as average
  from     observation_history          oh
  where    oh.effective_time_low     >= current_date - interval '1 year' -- of last year
  and      oh.pq_value                IS NOT NULL
  and    (
              (oh.code = '103232008'    and oh.codesystem = '2.16.840.1.113883.6.96')
           or (oh.code = '8480-6'       and oh.codesystem = '2.16.840.1.113883.6.1')
           or (oh.code = '8462-4'       and oh.codesystem = '2.16.840.1.113883.6.1')
           or (oh.code = 'Portavita175' and oh.codesystem = '2.16.840.1.113883.2.4.3.31.2.1')
  )
  group by oh.code, oh.codesystem
),
avgObseLastYear as (
  select   pmd.orga_enti_id
  ,        oh.code
  ,        oh.codesystem
  ,        avg(oh.pq_value)          as average
  ,        stddev(oh.pq_value)       as std
  from     observation_history          oh
  join     patientMetaData              pmd
  on       pmd.peso_id                = oh.peso_id
  where    oh.effective_time_low     >= current_date - interval '1 year' -- of last year
  and      oh.pq_value                IS NOT NULL
  and    (
              (oh.code = '103232008'    and oh.codesystem = '2.16.840.1.113883.6.96')
           or (oh.code = '8480-6'       and oh.codesystem = '2.16.840.1.113883.6.1')
           or (oh.code = '8462-4'       and oh.codesystem = '2.16.840.1.113883.6.1')
           or (oh.code = 'Portavita175' and oh.codesystem = '2.16.840.1.113883.2.4.3.31.2.1')
  )
  group by pmd.orga_enti_id, oh.code, oh.codesystem
)
select    pcpo.orga_enti_id                                  as orgaEntiId
,         pcpo.total                                         as nrOfPatients
,         round(hba1cAvgTotal.average, 2)                    as hba1cAvgTotal
,         round(hba1cAvg.average, 2)                         as hba1cAvg
,         round(hba1cAvg.average - hba1cAvgTotal.average, 2) as hba1cDeviation
,         round(sysRrAvgTotal.average, 2)                    as sysRrAvgTotal
,         round(sysRrAvg.average, 2)                         as sysRrAvg
,         round(sysRrAvg.average - sysRrAvgTotal.average, 2) as sysRrDeviation
,         round(diaRrAvgTotal.average, 2)                    as diaRrAvgTotal
,         round(diaRrAvg.average, 2)                         as diaRrAvg
,         round(diaRrAvg.average - diaRrAvgTotal.average, 2) as diaRrDeviation
,         round(blGlucSobAvgTotal.average, 2)                as blGlucSobAvgTotal
,         round(blGlucSobAvg.average, 2)                     as blGlucSobAvg
,         round(blGlucSobAvg.average - blGlucSobAvgTotal.average, 2) as blGlucSobDeviation
from      patientCountPerOrga pcpo
--HbA1c
left join totalAvgObseLastYear hba1cAvgTotal on hba1cAvgTotal.code = '103232008' and hba1cAvgTotal.codesystem = '2.16.840.1.113883.6.96'
left join avgObseLastYear hba1cAvg on hba1cAvg.orga_enti_id = pcpo.orga_enti_id and hba1cAvg.code = '103232008' and hba1cAvg.codesystem = '2.16.840.1.113883.6.96'

 --systolic blood pressure
left join totalAvgObseLastYear sysRrAvgTotal on sysRrAvgTotal.code = '8480-6' and sysRrAvgTotal.codesystem = '2.16.840.1.113883.6.1'
left join avgObseLastYear sysRrAvg on sysRrAvg.orga_enti_id = pcpo.orga_enti_id and sysRrAvg.code = '8480-6' and sysRrAvg.codesystem = '2.16.840.1.113883.6.1'

--diatolic blood pressure
left join totalAvgObseLastYear diaRrAvgTotal on diaRrAvgTotal.code = '8462-4' and diaRrAvgTotal.codesystem = '2.16.840.1.113883.6.1'
left join avgObseLastYear diaRrAvg on diaRrAvg.orga_enti_id = pcpo.orga_enti_id and diaRrAvg.code = '8462-4' and diaRrAvg.codesystem = '2.16.840.1.113883.6.1'

--blood glucose fasting
left join totalAvgObseLastYear blGlucSobAvgTotal on blGlucSobAvgTotal.code = 'Portavita175' and blGlucSobAvgTotal.codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
left join avgObseLastYear blGlucSobAvg on blGlucSobAvg.orga_enti_id = pcpo.orga_enti_id and blGlucSobAvg.code = 'Portavita175' and blGlucSobAvg.codesystem = '2.16.840.1.113883.2.4.3.31.2.1'
;
