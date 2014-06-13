with relevantMedication as (
  select *
  from ( values
			('Portavita1354'), --  Statins
			('Portavita1342'), --  Antihypertensives
			('Portavita1343'), --  Diuretics
			('Portavita1344'), --  Beta-blockers
			('Portavita1345'), --  Calcium antagonists
			('Portavita1346'), --  Drugs affecting the renin-angiotensin system
			('Portavita1347'), --  Alpha-blockers
			('Portavita1348'), --  Other antihypertensives
			('Portavita1349'), --  Blood-thinning drugs
			('Portavita1350'), --  Platelet aggregate inhibitors
			('Portavita1351'), --  Anticoagulants
			('Portavita1352'), --  Other blood-thinning drugs
			('Portavita648')   --  Diabetes medication
       ) as medication (code)
),
hba1cMeasurements as (
  select peso_id
  ,      pq_value
  ,      effective_time_low
  ,      rocky
  from   observation_history          oh
  where  oh.code = '103232008' and oh.codesystem = '2.16.840.1.113883.6.96' --HbA1c
),
medicationChanges as (
  select
    oh.peso_id
  , oh.act_id
  , orig_med.coded_value         as "original medication"
  , oh.coded_value               as "new medication"
  , oh.effective_time_low        as "time of change"
  , orig_med.effective_time_low  as "time of orig med"

  from   observation_history       oh
  join   relevantMedication        rm
  on     rm.code                 = oh.code
  join   observation_history       orig_med
  on     orig_med.peso_id        = oh.peso_id
  and    orig_med.code           = oh.code
  and    orig_med.rocky          = oh.rocky + 1
  and    orig_med.coded_value   <> oh.coded_value
  where  oh.codesystem           = '2.16.840.1.113883.2.4.3.31.2.1'
),
avgBetween as (
  select   mc.peso_id, mc.act_id, avg(hb.pq_value) as average
  from     medicationChanges mc
  join     hba1cMeasurements hb
  on       hb.peso_id = mc.peso_id
  and      hb.effective_time_low between mc."time of orig med" and mc."time of change"
  group by mc.peso_id, mc.act_id
),
hb_avg_after as (
  select hb.peso_id, mc.act_id
  ,      avg(hb.pq_value) as average
  from   hba1cMeasurements hb
  join   medicationChanges mc
  on     mc.peso_id =hb.peso_id
  where  hb.effective_time_low between mc."time of change" and (mc."time of change" + interval '1 year')
  group by hb.peso_id, mc.act_id
),
hb_avg_before as (
  select hb.peso_id, mc.act_id
  ,      avg(hb.pq_value) as average
  from   hba1cMeasurements hb
  join   medicationChanges mc
  on     mc.peso_id =hb.peso_id
  where  hb.effective_time_low between (mc."time of orig med" - interval '1 year') and mc."time of orig med"
  group by hb.peso_id, mc.act_id
)
select
  mc.peso_id
, mc."time of orig med"       as "time of orig med"
, mc."original medication"    as "original medication"
, mc."time of change"         as "time of change"
, mc."new medication"         as "new medication"
, round(hab.average,2)        as "avg hba1c 1 year before"
, ab.average                  as "avg hba1c between med change"
, round(haa.average,2)        as "avg hba1c 1 year after"

from   medicationChanges         mc
left join   avgBetween                ab
on     ab.peso_id              = mc.peso_id
and    ab.act_id               = mc.act_id

left join hb_avg_after haa
on        haa.peso_id = mc.peso_id
and       haa.act_id = mc.act_id

left join hb_avg_before hab
on        hab.peso_id = mc.peso_id
and       hab.act_id = mc.act_id

order by mc.peso_id
;
