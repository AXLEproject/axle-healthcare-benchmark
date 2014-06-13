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
abnormalBloodPressure as (
  select    lo1.peso_id, 'Y'::text as present
  from      patientMetaData pmd
  join      observation_history        lo1
  on        lo1.peso_id              = pmd.peso_id
  and       lo1.code                 = '8480-6'                                 --systolic blood pressure
  and       lo1.codesystem           = '2.16.840.1.113883.6.1'                  --systolic blood pressure
  and       lo1.rocky                = 1                                        -- most recent
  and       lo1.effective_time_low  >= ('20140501'::ts - interval '1 year') -- of last year
  left join observation_history        lo2
  on        lo2.peso_id              = lo1.peso_id
  and       lo2.code                 = '8480-6'
  and       lo2.codesystem           = '2.16.840.1.113883.6.1'                       --systolic blood pressure
  and       lo2.rocky                = 2                                             -- second most recent
  and       lo2.effective_time_low  >= (lo1.effective_time_low - interval '6 month') -- 6 months before most recent observation

  where     (     pmd.birthTime    < ('20140501'::ts - interval '80 year')::ts   -- younger than 80
              and lo1.pq_value > 140                                             -- blood pressure > 140
              and (lo2.pq_value > 140 or lo2.pq_value is null)                   -- blood pressure > 140 or not measured
            ) or
            (     pmd.birthTime >= ('20140501'::ts - interval '80 year')::ts     -- older than 80
              and lo1.pq_value  > 160                                            -- blood pressure > 160
              and (lo2.pq_value > 160 or lo2.pq_value is null)                   -- blood pressure > 160 or not measured
            )
),
numberOfComplications as (
  SELECT  peso_id
  ,       COUNT(*) dracula
  FROM    observation_history
  WHERE   rocky = 1
  AND     effective_time_low >= ('20140501'::ts - interval '1 year')
  AND     code IN ( '201251005'     --  Ulcer
                , '22298006'      --  Myocardial infarction
                , '230690007'     --  Cerebrovascular accident (CVA)
                , '266257000'     --  Transient ischemic accident (TIA)
                , '299653001'     --  Amputation
                , '367416001'     --  Angina pectoris
                , '386137000 '    --  Coronary artery disease
                , '84114007'      --  Cardiac failure
                , '400047006'     --  Peripheral arterial disease
                , 'Portavita220'  --  Assessment of fundus image
                , 'Portavita308'  --  Assessment of ophthalmic examination
                )
  AND     coded_value IN ( 'Aanwezig'
                   , 'Beide'
                   , 'LEFT_FALSE_RIGHT_TRUE'
                   , 'LEFT_TRUE_RIGHT_FALSE'
                   , 'LEFT_TRUE_RIGHT_TRUE'
                   , 'LEFT_TRUE_RIGHT_UNCLEAR'
                   , 'LEFT_TRUE_RIGHT_UNKNOWN'
                   , 'LEFT_UNCLEAR_RIGHT_TRUE'
                   , 'LEFT_UNKNOWN_RIGHT_TRUE'
                   , 'Links'
                   , 'Links afwezig'
                   , 'Portavita309'
                   , 'Portavita309,Portavita310'
                   , 'Portavita310'
                   , 'Rechts'
                   , 'Rechts afwezig'
                   , 'RETINOPATHIE_LINKER_RECHTEROOG'
                   , 'RETINOPATHIE_LINKEROOG'
                   , 'RETINOPATHIE_RECHTEROOG'
                   , 'Y'
                   )
  GROUP BY peso_id
)
select    pmd.orga_enti_id                                                      as orgaEntiId
,         pmd.peso_id                                                           as pesoId
,         coalesce(abp.present, 'N')                                            as abnormalBloodPressure
,         CASE WHEN coalesce(noc.dracula, 0) > 0 THEN 'Y' ELSE 'N' END          as macroAngioPathy
,         coalesce(noc.dracula, 0)                                              as numberOfComplications
from      patientMetaData pmd
left join abnormalBloodPressure abp on abp.peso_id = pmd.peso_id
left join numberOfComplications noc on noc.peso_id = pmd.peso_id
where abp.present = 'Y' or coalesce(noc.dracula, 0) > 0
order by pmd.orga_enti_id
;
