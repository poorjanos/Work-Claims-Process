/* Formatted on 2019. 02. 27. 11:59:49 (QP5 v5.115.810.9015) */
/* Preprocess CLAIMS logdata */

/* Gen base table and rename cols */
DROP TABLE T_CLAIMS_PA_OUTPUT;
COMMIT;

CREATE TABLE T_CLAIMS_PA_OUTPUT
AS
     SELECT   DISTINCT
              f_paid AS case_id,
              f_idopont AS event_end,
              wflog_user AS user_id,
              REPLACE (hun1, '->', ' ide: ') AS activity_hu,
              REPLACE (hun1eng, '->', ' to ') AS activity_en,
              CASE WHEN hun1 LIKE 'FKR %' THEN 'FAIRKAR' ELSE 'KONTAKT' END
                 AS activity_type
       FROM   mesterr.export_pa_wflog3
      WHERE       (wflog_user LIKE 'OKK/%' OR hun1 LIKE 'FKR %')
              AND (f_paid LIKE 'K-2017%' OR f_paid LIKE 'K-2018%')
              AND hun1 IS NOT NULL
   ORDER BY   F_PAID, F_IDOPONT;

COMMIT;


/* Define then drop cases with first event outside 201701.01. and 2018.12.01.*/

DELETE FROM   T_CLAIMS_PA_OUTPUT
      WHERE   case_id IN
                    (SELECT   case_id
                       FROM   (  SELECT   case_id,
                                          MIN (event_end) first_event_date
                                   FROM   T_CLAIMS_PA_OUTPUT
                               GROUP BY   case_id)
                      WHERE   first_event_date < DATE '2017-01-01'
                              OR first_event_date >= DATE '2019-01-01');

COMMIT;