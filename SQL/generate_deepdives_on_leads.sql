/*********************************************************************************************************/
/* Question1: samples *******************************************************************************/
/*********************************************************************************************************/



/* Provide information calls 5-10 days after report on the phone */
SELECT   a.case_id, case_type, claim_report_date, regexp_substr(activity_en, 'Provide information') as call_type, event_end as call_date, event_end-claim_report_date as report_to_call
  FROM   T_CLAIMS_LEADTIME a, t_call_times_2018_cor b
 WHERE   a.case_id = b.case_id
         AND a.claim_report_date BETWEEN DATE '2018-07-01'
                                     AND  DATE '2018-12-31'
         AND b.case_type_en = 'Claim report'
         AND b.activity_hu = 'Tajekoztatas'
         AND event_end-claim_report_date between 5 and 10
         AND EXISTS -- filter for those that were reported on the phone
               (SELECT   1
                  FROM   (SELECT   *
                            FROM   t_call_times_2018_cor
                           WHERE   case_type_en = 'Claim report'
                                   AND event_end BETWEEN DATE '2018-07-01'
                                                     AND  DATE '2018-12-31'
                                   AND product_code = '21850'
                                   AND activity_hu =
                                         'Karbejelentes szemlere kiadva'));
                                         


/* Complaint calls 15-20 after report of the claim on the phone */
SELECT   a.case_id, case_type, claim_report_date, activity_en as call_type, event_end as call_date, event_end-claim_report_date as report_to_call
  FROM   T_CLAIMS_LEADTIME a, t_call_times_2018_cor b
 WHERE   a.case_id = b.case_id
         AND a.claim_report_date BETWEEN DATE '2018-07-01'
                                     AND  DATE '2018-12-31'
         AND b.case_type_en = 'Claim report'
         AND b.activity_hu = 'Reklamacio OKK-ba tovabbitas'
         AND event_end-claim_report_date between 15 and 20
         AND EXISTS -- filter for those that were reported on the phone
               (SELECT   1
                  FROM   (SELECT   *
                            FROM   t_call_times_2018_cor
                           WHERE   case_type_en = 'Claim report'
                                   AND event_end BETWEEN DATE '2018-07-01'
                                                     AND  DATE '2018-12-31'
                                   AND product_code = '21850'
                                   AND activity_hu =
                                         'Karbejelentes szemlere kiadva'));
                                         
                                         
                                         
/*********************************************************************************************************/
/* Question3: New definition for end of process and leadtime ********************************************/
/*********************************************************************************************************/

/* Compute case milestones */
DROP TABLE T_CLAIMS_LEADTIME;
COMMIT;

CREATE TABLE T_CLAIMS_LEADTIME
AS
     SELECT   case_id, case_type, MIN (event_end) AS claim_report_date
       FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
      WHERE   activity_hu like 'FKR 01%'
   GROUP BY   case_id, case_type;

COMMIT;

CREATE INDEX leadtime
   ON T_CLAIMS_LEADTIME (case_id);

ALTER TABLE T_CLAIMS_LEADTIME
ADD
(
report_month date,
claim_settled_date date, -- 49, 22, 6, 98, 99
claim_lastinteraction_date date,
report_to_settled number,
settled_to_lastinteraction number
);
COMMIT;


UPDATE T_CLAIMS_LEADTIME
set report_month = trunc(claim_report_date, 'MM');
COMMIT;

/* Add close date */
UPDATE   T_CLAIMS_LEADTIME a
   SET   claim_settled_date =
            (SELECT   MIN (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 b
              WHERE   (activity_hu like 'FKR 22%' or activity_hu like 'FKR 49%' or activity_hu like 'FKR 06%'
              or activity_hu like 'FKR 98%' or activity_hu like 'FKR 99%')
                      AND a.case_id = b.case_id);


/* Add date date of review or put to pending state*/
UPDATE   T_CLAIMS_LEADTIME a
   SET   claim_lastinteraction_date =
            (SELECT   MAX (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 b
               WHERE a.case_id = b.case_id);

COMMIT;


UPDATE T_CLAIMS_LEADTIME
set report_to_settled = claim_settled_date - claim_report_date;
COMMIT;



UPDATE T_CLAIMS_LEADTIME
set settled_to_lastinteraction = claim_lastinteraction_date - claim_settled_date;
COMMIT;


/* Delete cases with improper start or end */
DELETE FROM   T_CLAIMS_LEADTIME
      WHERE   claim_report_date IS NULL OR claim_settled_date IS NULL;
COMMIT;

/* Delete cases with improper event order */
DELETE FROM   T_CLAIMS_LEADTIME
      WHERE   claim_settled_date > claim_lastinteraction_date
              OR claim_report_date > claim_settled_date;

COMMIT;
