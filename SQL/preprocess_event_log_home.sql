/* Generate event log and main process milestones for HOME CLAIMS from ABLAK system */

DROP TABLE t_claims_home;

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
            AND e.f_modkod LIKE '219%';

COMMIT;


DROP TABLE t_claims_home_distinct;

CREATE TABLE t_claims_home_distinct
AS
     SELECT   DISTINCT f_karszam,
                       f_tszam,
                       f_karszam || '/' || f_tszam as f_azon,
                       f_modkod,
                       f_karido,
                       f_karbeido,
                       MIN (f_utalas) AS f_utalas_first
       FROM   t_claims_home
   GROUP BY   f_karszam, f_tszam, f_karszam || '/' || f_tszam, f_modkod, f_karido, f_karbeido
   ORDER BY   1, 2, 3, 4, 5, 6;

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
CREATE TABLE t_claims_home_distinct_paid
AS
   SELECT   * FROM t_claims_home_distinct_a
   UNION
   SELECT   * FROM t_claims_home_distinct_b;
COMMIT;
      
                      


/* Build event log */
DROP TABLE t_claims_home_eventlog;

CREATE TABLE t_claims_home_eventlog
AS
     SELECT   a.*,
              b.f_mozgtip,
              c.f_mnev,
              d.f_mnev_eng,
              b.f_datum
       FROM   t_claims_home_distinct a,
              (SELECT   DISTINCT f_karszam, f_mozgtip, f_datum
                 FROM   ab_t_kar_osszes_mozgas where f_datum >= date '2016-10-01') b,
              ab_t_mozgas_kodok c,
              t_kar_mozg_en d
      WHERE   a.f_karszam = b.f_karszam AND b.f_mozgtip = c.f_kod
      and b.f_mozgtip = d.f_mozgtip
   ORDER BY   a.f_karszam, b.f_datum;
COMMIT;


DROP TABLE t_claims_home_pa_output;
CREATE TABLE t_claims_home_pa_output
AS
   --Claim event date
   SELECT   f_karszam as case_id, 'Claim event occured' as activity, f_karido as event_end
     FROM   t_claims_home_eventlog
   UNION
   --Report date for those where we have both N% event and f_karbeido
   SELECT   f_karszam,
            'Claim reported' AS f_mnev_eng,
            CASE WHEN f_karbeido < f_datum THEN f_karbeido ELSE f_datum END
               AS f_datum
     FROM   t_claims_home_eventlog
    WHERE   f_mozgtip LIKE 'N1%'
   UNION
   --Report date for those where we do not have N% event
   SELECT   f_karszam, 'Claim reported', f_karbeido
     FROM   t_claims_home_eventlog a
    WHERE   NOT EXISTS
               (SELECT   1
                  FROM   t_claims_home_eventlog b
                 WHERE   f_mozgtip LIKE 'N1%' AND a.f_karszam = b.f_karszam)
   UNION
   --All other events
   SELECT   f_karszam, f_mozgtip || ' ' || f_mnev_eng, f_datum
     FROM   t_claims_home_eventlog
    WHERE   f_mozgtip NOT LIKE 'N1%';
COMMIT;