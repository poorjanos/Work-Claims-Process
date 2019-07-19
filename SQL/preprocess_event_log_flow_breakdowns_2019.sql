/*********************************************************************************************************/
/* Gen Casco claims table with FAIRKAR, CCC KONTAKT and OKK KONTAKT activities ***************************/
/*********************************************************************************************************/

DROP TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK_2019;
COMMIT;

CREATE TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
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
                                    AND (hun1 like 'FKR 46%' or hun1 like 'FKR 25%')
                                    AND a.f_paid = b.f_paid)
               THEN
                  'EXCEPTION'
               ELSE
                  'STANDARD'
            END
               AS case_type,
            attrib0eng AS ccc_contact_type
     FROM   mesterr.export_pa_wflog3 a
    WHERE   REGEXP_LIKE (f_paid, 'K-201[789]/.*') AND hun1 IS NOT NULL
    and product_code like '218%';

COMMIT;

CREATE INDEX claims_ccc_okk
   ON T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 (case_id);


/* Drop cases with no activities*/

DELETE FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
      WHERE   activity_type IS NULL;

COMMIT;



/*********************************************************************************************************/
/* Compute case milestones *******************************************************************************/
/*********************************************************************************************************/

/* Compute case milestones */
DROP TABLE T_CLAIMS_MILESTONES_2019;
COMMIT;

CREATE TABLE T_CLAIMS_MILESTONES_2019
AS
     SELECT   case_id, case_type, MIN (event_end) AS claim_report_date
       FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
      WHERE   activity_hu like 'FKR 01%'
   GROUP BY   case_id, case_type;

COMMIT;

CREATE INDEX milestones
   ON T_CLAIMS_MILESTONES_2019 (case_id);

ALTER TABLE T_CLAIMS_MILESTONES_2019
ADD
(
claim_decision_date date, -- 49, 47, 25
claim_close_date date -- 22 30 06
);
COMMIT;


/* Add close date */
UPDATE   T_CLAIMS_MILESTONES_2019 a
   SET   claim_close_date =
            (SELECT   MAX (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 b
              WHERE   (activity_hu like 'FKR 22%' or activity_hu like 'FKR 30%' or activity_hu like 'FKR 06%')
                      AND a.case_id = b.case_id);


/* Add date date of review or put to pending state*/
UPDATE   T_CLAIMS_MILESTONES_2019 a
   SET   claim_decision_date =
            (SELECT   MIN (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 b
              WHERE   (activity_hu like 'FKR 49%' or activity_hu like 'FKR 46%' or activity_hu like 'FKR 25%')
                      AND a.case_id = b.case_id);

COMMIT;


/* Delete cases with improper start or end */
DELETE FROM   T_CLAIMS_MILESTONES_2019
      WHERE   claim_report_date IS NULL OR claim_close_date IS NULL;
COMMIT;

/* Delete cases with improper event order */
DELETE FROM   T_CLAIMS_MILESTONES_2019
      WHERE   claim_decision_date > claim_close_date
              OR claim_report_date > claim_close_date;

COMMIT;



/* Create clean 3 stages table */
DROP TABLE T_CLAIMS_MILESTONES_2019_3STAGES;

CREATE TABLE T_CLAIMS_MILESTONES_2019_3STAGES
AS
   SELECT   case_id, case_type, '3STAGES' as milestones,
            TRUNC (claim_report_date) + 1 / (24 * 60 * 60)
               AS report_lowerbound,
            TRUNC (claim_report_date + 1) - 1 / (24 * 60 * 60)
               AS report_upperbound,
            TRUNC (claim_decision_date) + 1 / (24 * 60 * 60)
               AS decision_lowerbound,
            TRUNC (claim_decision_date + 1) - 1 / (24 * 60 * 60)
               AS decision_upperbound,
            TRUNC (claim_close_date) + 1 / (24 * 60 * 60) AS close_lowerbound,
            TRUNC (claim_close_date + 1) - 1 / (24 * 60 * 60)
               AS close_upperbound
     FROM   T_CLAIMS_MILESTONES_2019
    WHERE       claim_report_date IS NOT NULL
            AND claim_decision_date IS NOT NULL
            AND claim_close_date IS NOT NULL;


DELETE FROM T_CLAIMS_MILESTONES_2019_3STAGES
where report_lowerbound = decision_lowerbound
or  decision_lowerbound = close_lowerbound;
COMMIT;


/* Create clean 2 stages table */
DROP TABLE T_CLAIMS_MILESTONES_2019_2STAGES;

CREATE TABLE T_CLAIMS_MILESTONES_2019_2STAGES
AS
   SELECT   case_id,
            case_type,
            '2STAGES' AS milestones,
            report_lowerbound,
            report_upperbound,
            decision_lowerbound,
            decision_upperbound,
            close_lowerbound,
            close_upperbound
     FROM   (SELECT   case_id,
                      case_type,
                      TRUNC (claim_report_date) + 1 / (24 * 60 * 60)
                         AS report_lowerbound,
                      TRUNC (claim_report_date + 1) - 1 / (24 * 60 * 60)
                         AS report_upperbound,
                      TRUNC (claim_decision_date) + 1 / (24 * 60 * 60)
                         AS decision_lowerbound,
                      TRUNC (claim_decision_date + 1) - 1 / (24 * 60 * 60)
                         AS decision_upperbound,
                      TRUNC (claim_close_date) + 1 / (24 * 60 * 60)
                         AS close_lowerbound,
                      TRUNC (claim_close_date + 1) - 1 / (24 * 60 * 60)
                         AS close_upperbound
               FROM   T_CLAIMS_MILESTONES_2019
              WHERE       claim_report_date IS NOT NULL
                      AND claim_decision_date IS NOT NULL
                      AND claim_close_date IS NOT NULL)
    WHERE   report_lowerbound = decision_lowerbound
            OR decision_lowerbound = close_lowerbound
   UNION
   SELECT   case_id,
            case_type,
            '2STAGES' AS milestones,
            TRUNC (claim_report_date) + 1 / (24 * 60 * 60)
               AS report_lowerbound,
            TRUNC (claim_report_date + 1) - 1 / (24 * 60 * 60)
               AS report_upperbound,
            TRUNC (claim_decision_date) + 1 / (24 * 60 * 60)
               AS decision_lowerbound,
            TRUNC (claim_decision_date + 1) - 1 / (24 * 60 * 60)
               AS decision_upperbound,
            TRUNC (claim_close_date) + 1 / (24 * 60 * 60) AS close_lowerbound,
            TRUNC (claim_close_date + 1) - 1 / (24 * 60 * 60)
               AS close_upperbound
     FROM   T_CLAIMS_MILESTONES_2019
    WHERE       claim_report_date IS NOT NULL
            AND claim_decision_date IS NULL
            AND claim_close_date IS NOT NULL;
            
DELETE FROM T_CLAIMS_MILESTONES_2019_2STAGES
where report_lowerbound =  close_lowerbound;
            

UPDATE   T_CLAIMS_MILESTONES_2019_2STAGES
   SET   decision_lowerbound = NULL
 WHERE   decision_lowerbound IS NOT NULL;

UPDATE   T_CLAIMS_MILESTONES_2019_2STAGES
   SET   decision_upperbound = NULL
 WHERE   decision_upperbound IS NOT NULL;

COMMIT;


/* Merge stages and create cleaned output */
DROP TABLE T_CLAIMS_MILESTONES_2019_CLEANED;
COMMIT;

CREATE TABLE T_CLAIMS_MILESTONES_2019_CLEANED
AS
   SELECT   * FROM T_CLAIMS_MILESTONES_2019_3STAGES
   UNION
   SELECT   * FROM T_CLAIMS_MILESTONES_2019_2STAGES;

COMMIT;


CREATE INDEX milestones_c
   ON T_CLAIMS_MILESTONES_2019_CLEANED (case_id);

/* Add milestone flag to event sequence */
ALTER TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
ADD
(milestones varchar2 (10));
COMMIT;

UPDATE   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 a
   SET   milestones =
            (SELECT   milestones
               FROM   T_CLAIMS_MILESTONES_2019_cleaned b
              WHERE   a.case_id = b.case_id);

COMMIT;