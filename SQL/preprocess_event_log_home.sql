/************************************************************************************/
/* Generate event log and main process milestones for HOME CLAIMS from ABLAK system */
DROP TABLE t_claims_home;
COMMIT;

CREATE TABLE t_claims_home
AS
   SELECT   e.f_szerz_azon,
            e.f_karszam,
            b.f_tszam,
            e.f_karszam || '/' || f_tszam as f_azon,
            e.f_karido,
            e.f_karbeido,
            e.f_modkod,
            k.f_rosszeg,
            k.f_utalas
     FROM   ab_t_kar_bejegyzes b, ab_t_kar_esemeny e, ab_t_kar_kifiz k
    WHERE       e.f_karszam = b.f_karszam
            AND b.f_sorszam = k.f_sorszam
            AND k.f_allapot = '29'                                --kifezetett
            AND e.f_karbeido BETWEEN DATE '2017-01-01' AND DATE '2019-01-01'
            AND e.f_modkod LIKE '219%'
            AND b.f_vnem not in ('1', '2', '30', '31', '32', '42', '55'); --clean off unrelevant dangers (pet, accident and life)

COMMIT;


DROP TABLE t_claims_home_distinct;
COMMIT;

CREATE TABLE t_claims_home_distinct
AS
     SELECT   DISTINCT
              f_karszam,
              f_tszam,
              f_karszam || '/' || f_tszam AS f_azon,
              f_modkod,
              CASE
                 WHEN EXISTS
                         (SELECT   1
                            FROM   ab_t_kar_osszes_mozgas b
                           WHERE       f_datum >= DATE '2016-10-01'
                                   AND f_mozgtip = 'N289'
                                   AND a.f_karszam = b.f_karszam
                                   AND a.f_tszam = b.f_tszam)
                 THEN
                    'Exception'
                 WHEN EXISTS
                         (SELECT   1
                            FROM   ab_t_kar_osszes_mozgas b
                           WHERE       f_datum >= DATE '2016-10-01'
                                   AND f_mozgtip = 'N312'
                                   AND a.f_karszam = b.f_karszam
                                   AND a.f_tszam = b.f_tszam)
                 THEN
                    'Simple'
                 ELSE
                    'Standard'
              END
                 AS case_type,
              f_karido,
              f_karbeido,
              MIN (f_utalas) AS f_utalas_first
       FROM   t_claims_home a
   GROUP BY   f_karszam,
              f_tszam,
              f_karszam || '/' || f_tszam,
              f_modkod,
              f_karido,
              f_karbeido
   ORDER BY   1,
              2,
              3,
              4,
              5,
              6;

COMMIT;


/* Get paid from mesterr: first for exact matches */
DROP TABLE t_claims_home_distinct_a;
CREATE TABLE t_claims_home_distinct_a
AS
   SELECT   a.*, b.f_paid
     FROM   t_claims_home_distinct a, (SELECT   DISTINCT f_paid, f_azon
                                         FROM   mesterr.pa_ivk_paid
                                        WHERE   f_azon_tip = 'K') b
    WHERE   a.f_azon = b.f_azon;
COMMIT;


/* Get paid from mesterr: second for f_karszam having only one f_tszam */
DROP TABLE t_claims_home_distinct_b;
CREATE TABLE t_claims_home_distinct_b
AS
   SELECT   c.*, d.f_paid
     FROM   (SELECT   *
               FROM   t_claims_home_distinct a
              WHERE   NOT EXISTS
                         (SELECT   1
                            FROM   t_claims_home_distinct b
                           WHERE   f_tszam > 1 AND a.f_azon = b.f_azon)
                      AND f_azon NOT IN
                               (SELECT   f_azon FROM t_claims_home_distinct_a))
            c,
            (SELECT   DISTINCT f_paid, f_azon
               FROM   mesterr.pa_ivk_paid
              WHERE   f_azon_tip = 'K') d
    WHERE   TO_CHAR (c.f_karszam) = d.f_azon;
COMMIT;
                      


/* Join tables with f_paid */
DROP TABLE t_claims_home_distinct_paid;

CREATE TABLE t_claims_home_distinct_paid
AS
   SELECT   * FROM t_claims_home_distinct_a
   UNION
   SELECT   * FROM t_claims_home_distinct_b;
COMMIT;

      
/************************************************************************************/
/* Build milestones for cutpoint analysis */
DROP TABLE ;
COMMIT;


CREATE TABLE T_CLAIMS_HOME_MILESTONES
AS
   SELECT   f_paid AS case_id,
            case_type,
            f_modkod as product_code,
            TRUNC (f_karbeido) + 1 / (24 * 60 * 60) AS report_lowerbound,
            TRUNC (f_karbeido + 1) - 1 / (24 * 60 * 60) AS report_upperbound,
            TRUNC (f_utalas_first) + 1 / (24 * 60 * 60) AS close_lowerbound,
            TRUNC (f_utalas_first + 1) - 1 / (24 * 60 * 60)
               AS close_upperbound
     FROM   t_claims_home_distinct_paid
    WHERE   f_karbeido IS NOT NULL AND f_utalas_first IS NOT NULL;
--            AND TRUNC(f_karbeido + 1) - 1 / (24 * 60 * 60) <
--                  (f_utalas_first) + 1 / (24 * 60 * 60);--report upper less than close lower
COMMIT;



/* Quick test for CCC activitiy freqs */
SELECT   COUNT (DISTINCT f_paid)
  FROM   mesterr.export_pa_wflog3 a
 WHERE       EXISTS (SELECT   1
                       FROM   T_CLAIMS_HOME_MILESTONES b
                      WHERE   a.f_paid = b.case_id)
         AND a.wflog_user LIKE 'CCC/%'
         AND attrib3 = 'CALL';
--120K CCC interactions for 2017-2018
--of which 73K CCC CALLS


/************************************************************************************/
/* Build event log for cutpoint analysis */
DROP TABLE t_claims_home_kontakt_eventlog;
COMMIT;

CREATE TABLE t_claims_home_kontakt_eventlog
AS
     SELECT   f_paid AS case_id,
              CASE
                 WHEN hun1eng = 'Provide information'
                 THEN
                    hun1eng || attrib1eng
                 ELSE
                    hun1eng
              END
                 AS activity_en,
              f_idopont AS event_end,
              CASE
                 WHEN wflog_user LIKE 'CCC/%' THEN 'KONTAKT CCC'
                 WHEN wflog_user LIKE 'OKK/%' THEN 'KONTAKT OKK'
              END
                 AS activity_type,
              CASE
                 WHEN attrib2 = 'Call Center' THEN 'CALL'
                 WHEN attrib2 = 'Mail' THEN 'MAIL'
                 WHEN attrib2 = 'Fax' THEN 'FAX'
                 WHEN attrib2 = 'PubWeb' THEN 'PWEB'
                 ELSE 'DOC'
              END
                 AS activity_channel,
              wflog_user as user_id
       FROM   mesterr.export_pa_wflog3 a
      WHERE       hun1 IS NOT NULL
              AND EXISTS (SELECT   1
                            FROM   T_CLAIMS_HOME_MILESTONES b
                           WHERE   a.f_paid = b.case_id)
              AND (a.wflog_user LIKE 'CCC/%' OR a.wflog_user LIKE 'OKK/%')
   ORDER BY   f_paid, f_idopont;

COMMIT;


/* Add process branch type to eventlog */ 
CREATE INDEX idx_mile
   ON T_CLAIMS_HOME_MILESTONES (case_id);

CREATE INDEX idx_event
   ON t_claims_home_kontakt_eventlog (case_id);
COMMIT;


ALTER TABLE t_claims_home_kontakt_eventlog
ADD
(case_type varchar2(20)
);
COMMIT;

UPDATE   t_claims_home_kontakt_eventlog a
   SET   case_type =
            (SELECT   case_type
               FROM   T_CLAIMS_HOME_MILESTONES b
              WHERE   a.case_id = b.case_id);

COMMIT;

          
/************************************************************************************/
/* Build ABLAK event log to load into ProcessGold */
--DROP TABLE t_claims_home_eventlog;

--CREATE TABLE t_claims_home_eventlog
--AS
--     SELECT   a.*,
--              b.f_mozgtip,
--              c.f_mnev,
--              d.f_mnev_eng,
--              b.f_datum
--       FROM   t_claims_home_distinct a,
--              (SELECT   DISTINCT f_karszam, f_mozgtip, f_datum
--                 FROM   ab_t_kar_osszes_mozgas where f_datum >= date '2016-10-01') b,
--              ab_t_mozgas_kodok c,
--              t_kar_mozg_en d
--      WHERE   a.f_karszam = b.f_karszam AND b.f_mozgtip = c.f_kod
--      and b.f_mozgtip = d.f_mozgtip
--   ORDER BY   a.f_karszam, b.f_datum;
--COMMIT;


--DROP TABLE t_claims_home_pa_output;
--CREATE TABLE t_claims_home_pa_output
--AS
--   --Claim event date
--   SELECT   f_karszam as case_id, 'Claim event occured' as activity, f_karido as event_end
--     FROM   t_claims_home_eventlog
--   UNION
--   --Report date for those where we have both N% event and f_karbeido
--   SELECT   f_karszam,
--            'Claim reported' AS f_mnev_eng,
--            CASE WHEN f_karbeido < f_datum THEN f_karbeido ELSE f_datum END
--               AS f_datum
--     FROM   t_claims_home_eventlog
--    WHERE   f_mozgtip LIKE 'N1%'
--   UNION
--   --Report date for those where we do not have N% event
--   SELECT   f_karszam, 'Claim reported', f_karbeido
--     FROM   t_claims_home_eventlog a
--    WHERE   NOT EXISTS
--               (SELECT   1
--                  FROM   t_claims_home_eventlog b
--                 WHERE   f_mozgtip LIKE 'N1%' AND a.f_karszam = b.f_karszam)
--   UNION
--   --All other events
--   SELECT   f_karszam, f_mozgtip || ' ' || f_mnev_eng, f_datum
--     FROM   t_claims_home_eventlog
--    WHERE   f_mozgtip NOT LIKE 'N1%';
--COMMIT;


