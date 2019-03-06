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
            CASE
               WHEN attrib2 = 'Call Center' THEN 'CALL'
               WHEN attrib2 = 'Mail' THEN 'MAIL'
               WHEN attrib2 = 'Fax' THEN 'FAX'
               WHEN attrib2 = 'PubWeb' THEN 'PWEB'
               ELSE 'DOC'
            END
               AS event_channel,
            CASE WHEN hun1 LIKE 'FKR %' THEN 'FAIRKAR' ELSE 'KONTAKT' END
               AS activity_type,
            attrib0eng as case_type
     FROM   mesterr.export_pa_wflog3 
    WHERE   REGEXP_LIKE (f_paid, 'K-201[78]/.*');


/* Keep OKK/CCC and delete and empty rows */

DELETE FROM   T_CLAIMS_PA_OUTPUT
      WHERE   (user_id NOT LIKE 'OKK/%' AND user_id NOT LIKE 'CCC/%' AND activity_hu NOT LIKE 'FKR %')
              OR activity_hu IS NULL;
COMMIT;


DELETE FROM   T_CLAIMS_PA_OUTPUT
      WHERE   user_id  LIKE 'CCC/%' AND lower(case_type) not like '%claim%';
COMMIT;


DELETE FROM   T_CLAIMS_PA_OUTPUT
      WHERE   user_id  LIKE 'OKK/%' AND activity_type = 'KONTAKT';
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


UPDATE T_CLAIMS_PA_OUTPUT
set activity_hu = case when user_id like 'CCC/%' then event_channel || ' ' || activity_hu else activity_hu end;

UPDATE T_CLAIMS_PA_OUTPUT
set activity_en = case when user_id like 'CCC/%' then event_channel || ' ' || activity_en else activity_en end;

COMMIT;