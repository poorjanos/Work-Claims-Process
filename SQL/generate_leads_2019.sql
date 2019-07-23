/* View tables */
SELECT   * FROM T_CLAIMS_MILESTONES_2019;

SELECT   *
  FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019 a
 WHERE   milestones IS NOT NULL
         AND EXISTS (SELECT   1
                       FROM   T_CLAIMS_MILESTONES_2019_CLEANED b
                      WHERE   a.case_id = b.case_id);
                      
                      
/* Compute central tendency */
  SELECT   case_type,
           MEDIAN (throughput_time),
           AVG (throughput_time),
           STDDEV (throughput_time),
           MEDIAN (interaction_count),
           AVG (interaction_count),
           STDDEV (interaction_count)
    FROM   (SELECT   a.case_id,
                     case_type,
                     claim_close_date,
                     claim_close_date - claim_report_date AS throughput_time,
                     b.interaction_count
              FROM   T_CLAIMS_MILESTONES_2019 a,
                     (  SELECT   case_id,
                                 COUNT (activity_hu) AS interaction_count
                          FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
                         WHERE   activity_type = 'KONTAKT OKK'
                      GROUP BY   case_id) b
             WHERE   a.claim_report_date >= DATE '2017-01-01'
                     AND a.case_id = b.case_id)
GROUP BY   case_type;


/* Generate leads - sampling */
DROP TABLE t_casco_sample_normal_outlier_2019;
COMMIT;

CREATE TABLE t_casco_sample_normal_outlier_2019
as
SELECT   *
  FROM   (SELECT   c.*,
                   CASE
                      WHEN case_type = 'STANDARD'
                           AND throughput_time BETWEEN 18 AND 22
                      THEN
                         'normal'
                      WHEN case_type = 'STANDARD' AND throughput_time > 80
                      THEN
                         'outlier'
                      WHEN case_type = 'EXCEPTION'
                           AND throughput_time BETWEEN 38 AND 42
                      THEN
                         'normal'
                      WHEN case_type = 'EXCEPTION' AND throughput_time > 95
                      THEN
                         'outlier'
                      WHEN case_type = 'ALTERNATIVE'
                           AND throughput_time BETWEEN 4 AND 8
                      THEN
                         'normal'
                      WHEN case_type = 'ALTERNATIVE' AND throughput_time > 28
                      THEN
                         'outlier'
                   END
                      AS throughput_class,
                   CASE
                      WHEN case_type = 'STANDARD'
                           AND interaction_count BETWEEN 8 AND 12
                      THEN
                         'normal'
                      WHEN case_type = 'STANDARD' AND interaction_count > 20
                      THEN
                         'outlier'
                      WHEN case_type = 'EXCEPTION'
                           AND interaction_count BETWEEN 12 AND 16
                      THEN
                         'normal'
                      WHEN case_type = 'EXCEPTION' AND interaction_count > 27
                      THEN
                         'outlier'
                      WHEN case_type = 'ALTERNATIVE'
                           AND interaction_count BETWEEN 6 AND 9
                      THEN
                         'normal'
                      WHEN case_type = 'ALTERNATIVE'
                           AND interaction_count > 15
                      THEN
                         'outlier'
                   END
                      AS interaction_class
            FROM   (SELECT   a.case_id,
                             case_type,
                             claim_close_date,
                             claim_close_date - claim_report_date
                                AS throughput_time,
                             b.interaction_count
                      FROM   T_CLAIMS_MILESTONES_2019 a,
                             (  SELECT   case_id,
                                        COUNT (activity_hu)
                                            AS interaction_count
                                  FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
                                 WHERE   activity_type = 'KONTAKT OKK'
                              GROUP BY   case_id) b
                     WHERE   a.claim_report_date >= DATE '2018-07-01'
                             AND a.case_id = b.case_id) c)
 WHERE   throughput_class IS NOT NULL AND interaction_class IS NOT NULL;
COMMIT;


/* Add flag for info and complaint calls */
ALTER TABLE t_casco_sample_normal_outlier_2019
ADD
(
INFO_CALL char(2),
COMPLAIN_CALL char(2)
);
COMMIT;


UPDATE   t_casco_sample_normal_outlier_2019 a
   SET   info_call = 'Y'
 WHERE   EXISTS
            (SELECT   1
               FROM   t_call_times b
              WHERE   a.case_id = b.case_id
                      AND b.activity_hu = 'Tajekoztatas');
COMMIT;


UPDATE   t_casco_sample_normal_outlier_2019 a
   SET   complain_call = 'Y'
 WHERE   EXISTS
            (SELECT   1
               FROM   t_call_times b
              WHERE   a.case_id = b.case_id
                      AND b.activity_hu = 'Reklamacio OKK-ba tovabbitas');
COMMIT;




/* Generate event log for leads */
SELECT   *
  FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
  where case_id in (select case_id from t_casco_sample_normal_outlier_2019)
  and activity_type <> 'KONTAKT CCC'
  order by case_id, event_end;
  
  
SELECT   *
  FROM   t_casco_sample_normal_outlier_2019
 WHERE   complain_call IS NOT NULL;


/* Generate full population */
DROP TABLE t_casco_sample_normal_outlier_full;
COMMIT;

CREATE TABLE t_casco_sample_normal_outlier_full
as
SELECT   *
  FROM   (SELECT   c.*,
                   CASE
                      WHEN case_type = 'STANDARD'
                           AND throughput_time <= 110
                      THEN
                         'normal'
                      WHEN case_type = 'STANDARD' AND throughput_time > 110
                      THEN
                         'outlier'
                      WHEN case_type = 'EXCEPTION'
                           AND throughput_time <= 134
                      THEN
                         'normal'
                      WHEN case_type = 'EXCEPTION' AND throughput_time > 134
                      THEN
                         'outlier'
                      WHEN case_type = 'ALTERNATIVE'
                           AND throughput_time <= 39
                      THEN
                         'normal'
                      WHEN case_type = 'ALTERNATIVE' AND throughput_time > 39
                      THEN
                         'outlier'
                   END
                      AS throughput_class,
                   CASE
                      WHEN case_type = 'STANDARD'
                           AND interaction_count <= 20
                      THEN
                         'normal'
                      WHEN case_type = 'STANDARD' AND interaction_count > 20
                      THEN
                         'outlier'
                      WHEN case_type = 'EXCEPTION'
                           AND interaction_count <= 34
                      THEN
                         'normal'
                      WHEN case_type = 'EXCEPTION' AND interaction_count > 34
                      THEN
                         'outlier'
                      WHEN case_type = 'ALTERNATIVE'
                           AND interaction_count <= 16
                      THEN
                         'normal'
                      WHEN case_type = 'ALTERNATIVE'
                           AND interaction_count > 16
                      THEN
                         'outlier'
                   END
                      AS interaction_class
            FROM   (SELECT   a.case_id,
                             case_type,
                             claim_close_date,
                             claim_close_date - claim_report_date
                                AS throughput_time,
                             b.interaction_count
                      FROM   T_CLAIMS_MILESTONES_2019 a,
                             (  SELECT   case_id,
                                        COUNT (activity_hu)
                                            AS interaction_count
                                  FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK_2019
                                 WHERE   activity_type = 'KONTAKT OKK'
                              GROUP BY   case_id) b
                     WHERE   a.claim_report_date >= DATE '2017-01-01'
                             AND a.case_id = b.case_id) c);
 --WHERE   throughput_class IS NOT NULL AND interaction_class IS NOT NULL;
COMMIT;