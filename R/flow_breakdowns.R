library(config)
library(here)
library(dplyr)
library(lubridate)
library(tidyr)
library(purrr)


# Data Extraction #######################################################################

# Set JAVA_HOME, set max. memory, and load rJava library
Sys.setenv(JAVA_HOME = "C:\\Program Files\\Java\\jre1.8.0_171")
options(java.parameters = "-Xmx2g")
library(rJava)

# Output Java version
.jinit()
print(.jcall("java/lang/System", "S", "getProperty", "java.version"))

# Load RJDBC library
library(RJDBC)

# Get credentials
datamnr <-
  config::get("datamnr", file = "C:\\Users\\PoorJ\\Projects\\config.yml")

# Create connection driver
jdbcDriver <-
  JDBC(driverClass = "oracle.jdbc.OracleDriver", classPath = "C:\\Users\\PoorJ\\Desktop\\ojdbc7.jar")

# Open connection: kontakt
jdbcConnection <-
  dbConnect(
    jdbcDriver,
    url = datamnr$server,
    user = datamnr$uid,
    password = datamnr$pwd
  )

# Fetch data
query_cutpoints <- "SELECT   case_id,
TRUNC (claim_report_date) + 1 / (24 * 60 * 60) AS report_lowerbound,
TRUNC (claim_report_date + 1) - 1 / (24 * 60 * 60)
AS report_upperbound,
TRUNC (claim_decision_date) + 1 / (24 * 60 * 60)
AS decision_lowerbound,
TRUNC (claim_decision_date + 1) - 1 / (24 * 60 * 60)
AS decision_upperbound,
TRUNC (claim_close_date) + 1 / (24 * 60 * 60) AS close_lowerbound,
TRUNC (claim_close_date + 1) - 1 / (24 * 60 * 60)
AS close_upperbound
FROM   T_CLAIMS_MILESTONES
WHERE   claim_report_date is not null and claim_decision_date is not null
AND claim_close_date is not null"
t_cutpoints <- dbGetQuery(jdbcConnection, query_cutpoints)

query_eventlog <- "SELECT   *
  FROM   T_CLAIMS_PA_OUTPUT_CCC_OKK a
 WHERE   exists (select 1  FROM T_CLAIMS_MILESTONES b
WHERE   claim_report_date is not null and claim_decision_date is not null
AND claim_close_date is not null and a.case_id = b.case_id)"
t_eventlog <- dbGetQuery(jdbcConnection, query_eventlog)


# Close db connection: kontakt
dbDisconnect(jdbcConnection)



# Data Transformation ###################################################################

t_cutpoints_long <- t_cutpoints %>% mutate_at(vars(REPORT_LOWERBOUND:CLOSE_UPPERBOUND), ymd_hms) %>% 
                  tidyr::gather(-CASE_ID, key = CUTPOINT, value = CUTDATE)
t_eventlog <- t_eventlog %>% mutate_at(vars(EVENT_END), ymd_hms)

t_events_ccc <- t_eventlog %>% filter(ACTIVITY_TYPE == "KONTAKT CCC") %>% select(CASE_ID, CASE_TYPE, EVENT_END)




# Compute Bins ##########################################################################
create_bins <- function(df, case_id) {
  t_cutpoints_long_filtered <- t_cutpoints_long[t_cutpoints_long$CASE_ID == case_id, ]
  as.character(cut(df$EVENT_END,
    breaks = c(t_cutpoints_long_filtered$CUTDATE, Inf),
    labels = t_cutpoints_long_filtered$CUTPOINT
  ))
}

by_case_id <- t_events_ccc %>% group_by(CASE_ID, CASE_TYPE) %>% nest() %>% 
  mutate(BINS = map(data, create_bins, .$CASE_ID))


by_case_id %>% select(CASE_ID, CASE_TYPE, BINS) %>% unnest()
