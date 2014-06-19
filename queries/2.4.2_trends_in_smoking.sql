with dateRanges as (
        select 0 as id, ('20140501'::ts - interval '6 month')  fromDate, ('20140501'::ts - interval '0 month')  toDate
  UNION select 1 as id, ('20140501'::ts - interval '12 month') fromDate, ('20140501'::ts - interval '6 month')  toDate
  UNION select 2 as id, ('20140501'::ts - interval '18 month') fromDate, ('20140501'::ts - interval '12 month') toDate
  UNION select 3 as id, ('20140501'::ts - interval '24 month') fromDate, ('20140501'::ts - interval '18 month') toDate
  UNION select 4 as id, ('20140501'::ts - interval '30 month') fromDate, ('20140501'::ts - interval '24 month') toDate
  UNION select 5 as id, ('20140501'::ts - interval '36 month') fromDate, ('20140501'::ts - interval '30 month') toDate
),
patientMetaData as (
  SELECT ptnt._id                                     AS ptnt_role_id
  ,      ptnt.scoper                                  AS orga_enti_id
  ,      ptnt.player                                  AS peso_id
  ,      ptnt._effective_time_low                     AS ptnt_from_time
  ,      ptnt._effective_time_high                    AS ptnt_to_time
  ,      peso."administrativeGenderCode"->>'code'     AS gender
  ,      peso."birthTime"                             AS birthTime
  FROM  "Patient"                                        ptnt
  JOIN  "Person"                                         peso
  ON     peso._id                                      = ptnt.player
),
/**
activePatients as (
  select dr.id                  as dateRange
  ,      pmd.*
  from   patientMetaData        pmd
  join   dateRanges             dr
  -- care provision was active during this period
  on     pmd.pcpr_from_time <= dr.toDate
  and    coalesce(pmd.pcpr_to_time, dr.fromDate) >= dr.fromDate
),
*/
patientCountPerOrga as (
  select orga_enti_id
  ,      dr.id               as dateRange
  ,      count(*)            as total
  from   patientMetaData        pmd
  join   dateRanges             dr
  on     pmd.ptnt_to_time IS NULL or pmd.ptnt_to_time < dr.toDate
  group by orga_enti_id, dr.id
),
smokingObservations as (
  select pmd.orga_enti_id, lo.peso_id, lo.effective_time_low, coded_value, lo.rocky
  from   observation_history lo
  join   patientMetaData pmd
  on     pmd.peso_id = lo.peso_id
  where  code = '365980008' and codesystem = '2.16.840.1.113883.6.96'
),
mostRecentSmokingObs as (
  select  mostRecent.id as dateRange
  ,       pmd.orga_enti_id
  ,       mostRecent.peso_id
  ,       lo.coded_value
  ,       lo.effective_time_low
  ,       mostRecent.minRocky as rocky
  from (
    select  dr.id, lo.peso_id as peso_id, min(lo.rocky) as minRocky
    from    smokingObservations lo
    join    dateRanges dr
    on      1=1
    where   lo.effective_time_low < dr.toDate
    group by dr.id, lo.peso_id
  ) mostRecent
  join  smokingObservations lo
  on    lo.peso_id = mostRecent.peso_id
  and   lo.rocky = mostRecent.minRocky
  join  patientMetaData pmd
  on    pmd.peso_id = mostRecent.peso_id
),
smokedInThisPeriod as (
  select   orga_enti_id, dateRange, count(*) as c
  from     mostRecentSmokingObs mrso
  where    coded_value = '77176002'
  group by orga_enti_id, dateRange
),
ceasedSmokingInPeriod as (
  select   mrso.orga_enti_id, mrso.dateRange, count(*) as c
  from     mostRecentSmokingObs mrso -- most recent smoking observation was 'formerly'
  join     dateRanges dr
  on       dr.id = mrso.dateRange
  join     smokingObservations so
  on       so.peso_id = mrso.peso_id
  and      so.rocky = mrso.rocky + 1 -- second most recent smoking observation was 'yes'
  and      so.coded_value = '77176002'
  where    mrso.coded_value = '8517006'
  and      mrso.effective_time_low between dr.fromDate and dr.toDate
  group by mrso.orga_enti_id, mrso.dateRange
)
select    pcpo.orga_enti_id
,         dr.fromDate
,         dr.toDate
,         pcpo.total                                                 as nrOfActivePatients
,         coalesce(sitp.c, 0)                                        as smoking
,         round(coalesce(sitp.c, 0) / pcpo.total * 100, 2)           as smokingPerc
,         coalesce(csip.c, 0)                                        as ceasedSmoking
,         round(coalesce(csip.c, 0) / pcpo.total * 100, 2)           as ceasedSmokingPercOfTotal
,         round(coalesce(csip.c, 0) / sitp.c * 100, 2)               as ceasedSmokingPercOfSmokers
from      patientCountPerOrga pcpo
join      dateRanges dr
on        dr.id = pcpo.dateRange
left join smokedInThisPeriod sitp
on        sitp.orga_enti_id = pcpo.orga_enti_id
and       sitp.dateRange = pcpo.dateRange
left join ceasedSmokingInPeriod csip
on        csip.orga_enti_id = pcpo.orga_enti_id
and       csip.dateRange = pcpo.dateRange
order by  pcpo.orga_enti_id, pcpo.daterange desc
;

