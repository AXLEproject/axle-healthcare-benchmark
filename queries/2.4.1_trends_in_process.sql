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
  ,      ptnt._effective_time_low                    AS ptnt_from_time
  ,      ptnt._effective_time_high                    AS ptnt_to_time
  ,      peso."administrativeGenderCode"->>'code'     AS gender
  ,      peso."birthTime"                             AS birthTime
  FROM  "Patient"                                        ptnt
  JOIN  "Person"                                         peso
  ON     peso._id                                      = ptnt.player
),
patientCountPerOrga as (
  select orga_enti_id
  ,      dr.id               as dateRange
  ,      count(*)            as total
  from   patientMetaData        pmd
  join   dateRanges             dr
  on     pmd.ptnt_to_time IS NULL or pmd.ptnt_to_time < dr.toDate
  group by orga_enti_id, dr.id
),
allExamCds as (
  select distinct code from examinations
),
examsPerPeriod as (
  select   orga_enti_id, code, dr.id dateRange, count(*) as c
  from     examinations exam
  join     dateRanges dr
  on       exam._effective_time_low between dr.fromDate and dr.toDate
  join     patientMetaData pmd
  on       pmd.peso_id = exam.peso_id
  group by orga_enti_id, code, dr.id
)
select    pcpo.orga_enti_id
,         pcpo.total                                            as activePatientsInPeriod
,         examCd.code->>'code'                                  as examCode
,         examCd.code->>'codeSystem'                            as examCodeSystem
,         examCd.code->>'displayName'                           as examDisplayName
,         dr.fromDate
,         dr.toDate
,         round(coalesce(examsPerPeriod.c, 0) / pcpo.total, 2)       as averageExamsPerPatient
from      patientCountPerOrga pcpo
join      dateRanges dr
on        pcpo.dateRange = dr.id
join      allExamCds examCd
on        1=1
left join examsPerPeriod
on        examsPerPeriod.orga_enti_id = pcpo.orga_enti_id
and       examsPerPeriod.dateRange    = pcpo.dateRange
and       examsPerPeriod.code           = examCd.code
order by  pcpo.orga_enti_id, examCd.code, pcpo.dateRange desc
;
