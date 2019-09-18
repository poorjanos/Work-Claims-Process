/*********************************************************************************************************/
/* Gen Casco claims table with FAIRKAR, CCC KONTAKT and OKK KONTAKT activities ***************************/
/*********************************************************************************************************/

DROP TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch;
COMMIT;

CREATE TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch
AS
   SELECT   DISTINCT
            f_paid AS case_id,
            f_idopont AS event_end,
            wflog_user AS user_id,
            CASE
               WHEN REGEXP_LIKE (hun1, '->')
               THEN
                  REGEXP_SUBSTR (hun1, '^T\w*')
               ELSE
                  hun1
            END
               AS activity_hu,
            CASE
               WHEN REGEXP_LIKE (hun1eng, '->')
               THEN
                  REGEXP_SUBSTR (hun1eng, '^T\w*')
               ELSE
                  hun1
            END
               AS activity_en,
            CASE
               WHEN attrib2 = 'Call Center' THEN 'CALL'
               WHEN attrib2 = 'Mail' THEN 'MAIL'
               WHEN attrib2 = 'Fax' THEN 'FAX'
               WHEN attrib2 = 'PubWeb' THEN 'PWEB'
               ELSE 'DOC'
            END
               AS activity_channel,
            CASE
               WHEN hun1 LIKE 'FKR %'
               THEN
                  'FAIRKAR'
               WHEN hun1 NOT LIKE 'FKR %' AND wflog_user LIKE 'CCC/%'
               THEN
                  'KONTAKT CCC'
               WHEN hun1 NOT LIKE 'FKR %' AND wflog_user LIKE 'OKK/%'
               THEN
                  'KONTAKT OKK'
            END
               AS activity_type,
            -- Determine process flow (happy, exception)
            CASE
               WHEN claim_alternative = 1
               THEN
                  'ALTERNATIVE'
               WHEN claim_alternative IS NULL
                    AND EXISTS
                          (SELECT   1
                             FROM   mesterr.export_pa_wflog3 b
                            WHERE   REGEXP_LIKE (f_paid, 'K-201[789]/.*')
                                    AND to_number(regexp_substr(hun1, '\d{2}')) in
                                        (14, 15, 16, 18, 19, 25, 27, 34, 35, 36, 38, 39, 40, 53, 57, 58, 59, 60)
                                    AND a.f_paid = b.f_paid)
               THEN
                  'EXCEPTION'
               ELSE
                  'STANDARD'
            END
               AS case_type,
            attrib0eng AS ccc_contact_type
     FROM   mesterr.export_pa_wflog3_0917 a
    WHERE   REGEXP_LIKE (f_paid, 'K-201[789]/.*') AND hun1 IS NOT NULL
    and product_code like '218%';

COMMIT;

CREATE INDEX nb_idx
   ON T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch (case_id);


/* Drop cases with no activities*/
DELETE FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch
      WHERE   activity_type IS NULL;

COMMIT;



/*********************************************************************************************************/
/* Compute case milestones *******************************************************************************/
/*********************************************************************************************************/

/* Compute case milestones */
DROP TABLE T_CLAIMS_MILESTONES_2019_newbranch;
COMMIT;

CREATE TABLE T_CLAIMS_MILESTONES_2019_newbranch
AS
     SELECT   case_id, case_type, MIN (event_end) AS report_date
       FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch
      WHERE   activity_hu like 'FKR 01%'
   GROUP BY   case_id, case_type;

COMMIT;


CREATE INDEX milestones_idx
   ON T_CLAIMS_MILESTONES_2019_newbranch (case_id);


ALTER TABLE T_CLAIMS_MILESTONES_2019_newbranch
ADD
(
lb_check_date date, -- 08
lb_decision_date date, -- 09, 33, 46, 47, 49, 
close_date date --06, 22, 30, 98, 99
);
COMMIT;


/* Add lb_check_date */
UPDATE   T_CLAIMS_MILESTONES_2019_newbranch a
   SET   lb_check_date =
            (SELECT   MIN (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch b
              WHERE   activity_hu like 'FKR 08%'
                      AND a.case_id = b.case_id);
COMMIT;

/* Add lb_decision_date*/
UPDATE   T_CLAIMS_MILESTONES_2019_newbranch a
   SET   lb_decision_date =
            (SELECT   MIN (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch b
              WHERE   (activity_hu like 'FKR 09%' or activity_hu like 'FKR 33%' or activity_hu like 'FKR 46%'
              or activity_hu like 'FKR 47%' or activity_hu like 'FKR 49%')
                      AND a.case_id = b.case_id);

COMMIT;


/* Add close_date */
UPDATE   T_CLAIMS_MILESTONES_2019_newbranch a
   SET   close_date =
            (SELECT   MIN (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019_newbranch b
              WHERE   (activity_hu like 'FKR 06%' or activity_hu like 'FKR 22%' or activity_hu like 'FKR 30%'
              or activity_hu like 'FKR 98%' or activity_hu like 'FKR 99%')
                      AND a.case_id = b.case_id);


/* Delete cases with improper start or end */
DELETE FROM   T_CLAIMS_MILESTONES_2019_newbranch
      WHERE      report_date IS NULL
              OR close_date IS NULL
              OR lb_decision_date IS NULL
              OR lb_check_date IS NULL;

COMMIT;


/* Delete cases with improper event order */
DELETE FROM   T_CLAIMS_MILESTONES_2019_newbranch
      WHERE   lb_decision_date > close_date
              OR report_date > close_date
              or lb_check_date > close_date;

COMMIT;


DELETE FROM T_CLAIMS_MILESTONES_2019_newbranch where report_date >= date '2019-01-01';


ALTER TABLE T_CLAIMS_MILESTONES_2019_newbranch
add
(
full_lead_time number,
report_to_lbcheck number,
lbcheck_to_lbdecision number,
lbdecision_to_close number
);
COMMIT;


UPDATE T_CLAIMS_MILESTONES_2019_newbranch
set full_lead_time = close_date-report_date;

UPDATE T_CLAIMS_MILESTONES_2019_newbranch
set report_to_lbcheck = lb_check_date-report_date;

UPDATE T_CLAIMS_MILESTONES_2019_newbranch
set lbcheck_to_lbdecision = lb_decision_date-lb_check_date;

UPDATE T_CLAIMS_MILESTONES_2019_newbranch
set lbdecision_to_close = close_date-lb_decision_date;

COMMIT;