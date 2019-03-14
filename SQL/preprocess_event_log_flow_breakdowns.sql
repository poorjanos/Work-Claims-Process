/*********************************************************************************************************/
/* Gen Casco claims table with FAIRKAR, CCC KONTAKT and OKK KONTAKT activities ***************************/
/*********************************************************************************************************/

DROP TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK;
COMMIT;

CREATE TABLE T_CLAIMS_PA_OUTPUT_CCC_OKK
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
                            WHERE   REGEXP_LIKE (f_paid, 'K-201[78]/.*')
                                    AND hun1 IN
                                             ('FKR 46 Velemenyezett es fuggo ',
                                              'FKR 25 Fuggo ')
                                    AND a.f_paid = b.f_paid)
               THEN
                  'EXCEPTION'
               ELSE
                  'STANDARD'
            END
               AS case_type,
            attrib0eng AS ccc_contact_type
     FROM   mesterr.export_pa_wflog3 a
    WHERE   REGEXP_LIKE (f_paid, 'K-201[78]/.*') AND hun1 IS NOT NULL;

COMMIT;

CREATE INDEX claims_ccc_okk
   ON T_CLAIMS_PA_OUTPUT_CCC_OKK (case_id);


/* Drop cases with no activities*/

DELETE FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK
      WHERE   activity_type IS NULL;

COMMIT;



/*********************************************************************************************************/
/* Compute case milestones *******************************************************************************/
/*********************************************************************************************************/

/* Compute case milestones */
DROP TABLE T_CLAIMS_MILESTONES;
COMMIT;

CREATE TABLE T_CLAIMS_MILESTONES
AS
     SELECT   case_id, case_type, MIN (event_end) AS claim_report_date
       FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK
      WHERE   activity_hu = 'FKR 01 Elozetesen bejelentett '
   GROUP BY   case_id, case_type;

COMMIT;

CREATE INDEX milestones
   ON T_CLAIMS_MILESTONES (case_id);

ALTER TABLE T_CLAIMS_MILESTONES
ADD
(
claim_decision_date date, -- 49, 47, 25
claim_close_date date -- 22 30 06
);
COMMIT;


/* Add close date */
UPDATE   T_CLAIMS_MILESTONES a
   SET   claim_close_date =
            (SELECT   MAX (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK b
              WHERE   activity_hu IN
                            ('FKR 22 Kifizetes utan lezarhato ',
                             'FKR 30 Harom honapig fuggo ',
                             'FKR 06 Lezart ')
                      AND a.case_id = b.case_id);


/* Add date date of review or put to pending state*/
UPDATE   T_CLAIMS_MILESTONES a
   SET   claim_decision_date =
            (SELECT   MIN (event_end)
               FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK b
              WHERE   activity_hu IN
                            ('FKR 49 Velemenyezett es kifizetheto ',
                             'FKR 46 Velemenyezett es fuggo ',
                             'FKR 25 Fuggo ')
                      AND a.case_id = b.case_id);

COMMIT;


/* Delete cases with improper start or end */
DELETE FROM   T_CLAIMS_MILESTONES
      WHERE   claim_report_date IS NULL OR claim_close_date IS NULL;
COMMIT;

/* Delete cases with improper event order */
DELETE FROM   T_CLAIMS_MILESTONES
      WHERE   claim_decision_date > claim_close_date
              OR claim_report_date > claim_close_date;

COMMIT;