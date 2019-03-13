/* Gen Casco claims table with FAIRKAR, CCC KONTAKT and OKK KONTAKT activities*/
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


DELETE FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK
      WHERE   activity_type IS NULL;

COMMIT;