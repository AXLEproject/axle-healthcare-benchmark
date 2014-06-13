/*
 * Observation history per patient
 */
CREATE OR REPLACE VIEW observation_history_view AS
SELECT   ptnt.player                    AS peso_id
,        ptnt._id                       AS ptnt_role_id
-- TODO: care provision for which this observation was made would be nice to have
,        obs._id                        AS act_id
,        obs."code"->>'code'            AS code
,        obs."code"->>'codeSystem'      AS codesystem
,        obs._value_code_code           AS coded_value
,        obs._value_code_codesystem     AS coded_value_codesystem
,        obs._value_pq_value            AS pq_value
,        obs._effective_time_low        AS effective_time_low
,        RANK() OVER (
           PARTITION BY ptnt.player, obs."code"->>'code', obs."code"->>'codeSystem'
           ORDER BY obs._effective_time_low DESC, obs._id DESC)
                                        AS rocky
,        RANK() OVER (
           PARTITION BY ptnt.player, obs."code"->>'code', obs."code"->>'codeSystem'
           ORDER BY obs._effective_time_low ASC, obs._id ASC)
                                        AS drago
FROM    "Observation"                      obs

JOIN    "Participation"                    sbj_ptcp
ON       sbj_ptcp.act                    = obs._id
AND      sbj_ptcp."typeCode"->>'code'    = 'RCT'
JOIN    "Patient"                          ptnt
ON       ptnt._id                        = sbj_ptcp.role
;

DROP TABLE observation_history;
CREATE TABLE observation_history AS
  SELECT *
  FROM   observation_history_view
;
