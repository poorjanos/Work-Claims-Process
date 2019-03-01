/* Formatted on 2019. 03. 01. 12:19:50 (QP5 v5.115.810.9015) */
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
               AS activity_type,
            CASE
               WHEN f_paid IN
                          (SELECT   f_paid
                             FROM   mesterr.export_pa_wflog3
                            WHERE   REGEXP_LIKE (f_paid, 'K-201[78]/.*')
                           MINUS
                           SELECT   f_paid
                             FROM   mesterr.export_pa_wflog3
                            WHERE   REGEXP_LIKE (f_paid, 'K-201[78]/.*')
                                    AND hun1 NOT LIKE 'FKR %')
               THEN
                  'FAIR ONLY'
               ELSE
                  'FAIR AND KONTAKT'
            END
               AS case_type
     FROM   mesterr.export_pa_wflog3
    WHERE   REGEXP_LIKE (f_paid, 'K-201[78]/.*');


/* Delete non-OKK and empty rows */

DELETE FROM   T_CLAIMS_PA_OUTPUT
      WHERE   (user_id NOT LIKE 'OKK/%' AND activity_hu NOT LIKE 'FKR %')
              OR activity_hu IS NULL;

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