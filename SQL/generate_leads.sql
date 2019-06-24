/* View tables */
SELECT   * FROM T_CLAIMS_MILESTONES;

SELECT   *
  FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK a
 WHERE   milestones IS NOT NULL
         AND EXISTS (SELECT   1
                       FROM   T_CLAIMS_MILESTONES_CLEANED b
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
              FROM   T_CLAIMS_MILESTONES a,
                     (  SELECT   case_id,
                                 COUNT (activity_hu) AS interaction_count
                          FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK
                         WHERE   activity_hu NOT LIKE 'FKR%'
                      GROUP BY   case_id) b
             WHERE   a.claim_report_date >= DATE '2018-01-01'
                     AND a.case_id = b.case_id)
GROUP BY   case_type;


/* Generate leads - sampling */
SELECT   c.*,
  case when case_type = 'STANDARD' and throughput_time between 40 and 45 then
      'throughput_avg'
   when case_type = 'STANDARD' and throughput_time > 86 then
      'throughput_plus1std'
     when case_type = 'EXCEPTION' and throughput_time between 55 and 60 then
      'throughput_avg'
   when case_type = 'EXCEPTION' and throughput_time > 103 then
      'throughput_plus1std'
     when case_type = 'ALTERNATIVE' and throughput_time between 16 and 20 then
      'throughput_avg'
   when case_type = 'ALTERNATIVE' and throughput_time > 48 then
      'throughput_plus1std'
  end as throughput_cat,
    case when case_type = 'STANDARD' and interaction_count between 10 and 15
      then 'interaction_avg'
   when case_type = 'STANDARD' and interaction_count > 25 then
      'interaction_plus1std'
     when case_type = 'EXCEPTION' and interaction_count between 15 and 20 then
      'interaction_avg'
   when case_type = 'EXCEPTION' and interaction_count > 32 then
      'interaction_plus1std'
     when case_type = 'ALTERNATIVE' and interaction_count between 10 and 15
      then 'interaction_avg'
   when case_type = 'ALTERNATIVE' and interaction_count > 24 then
      'interaction_plus1std'
  end as interaction_cat
      FROM   (SELECT   a.case_id,
                     case_type,
                     claim_close_date,
                     claim_close_date - claim_report_date AS throughput_time,
                     b.interaction_count
              FROM   T_CLAIMS_MILESTONES a,
                     (  SELECT   case_id,
                                 COUNT (activity_hu) AS interaction_count
                          FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK
                         WHERE   activity_hu NOT LIKE 'FKR%'
                      GROUP BY   case_id) b
             WHERE   a.claim_report_date >= DATE '2018-01-01'
             and a.case_id = b.case_id) c;