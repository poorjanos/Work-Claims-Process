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
query_cutpoints <- "SELECT * FROM T_CLAIMS_MILESTONES_CLEANED"
t_cutpoints <- dbGetQuery(jdbcConnection, query_cutpoints)

query_eventlog <-
"SELECT * FROM T_CLAIMS_PA_OUTPUT_CCC_OKK a WHERE milestones IS NOT NULL
AND EXISTS (SELECT 1 FROM T_CLAIMS_MILESTONES_CLEANED b WHERE a.case_id = b.case_id)"
t_eventlog <- dbGetQuery(jdbcConnection, query_eventlog)


# Close db connection: kontakt
dbDisconnect(jdbcConnection)



# Data Transformation ###################################################################

t_cutpoints_long <- t_cutpoints %>%
  mutate_at(vars(REPORT_LOWERBOUND:CLOSE_UPPERBOUND), ymd_hms) %>%
  tidyr::gather(-CASE_ID, -CASE_TYPE, -MILESTONES, key = CUTPOINT, value = CUTDATE) %>%
  arrange(CASE_ID, CUTPOINT) %>% 
  filter(!is.na(CUTDATE))

t_eventlog <- t_eventlog %>% mutate_at(vars(EVENT_END), ymd_hms)

# Org specific event seqs
t_events_ccc <- t_eventlog %>%
  filter(ACTIVITY_TYPE == "KONTAKT CCC" & ACTIVITY_CHANNEL == "CALL") %>%
  select(CASE_ID, CASE_TYPE, MILESTONES, EVENT_END)

# Define Func to Compute Bins
create_bins <- function(df, case_id) {
  t_cutpoints_long_filtered <- t_cutpoints_long[t_cutpoints_long$CASE_ID == case_id, ]
  as.character(cut(df$EVENT_END,
    breaks = c(t_cutpoints_long_filtered$CUTDATE, Inf),
    labels = t_cutpoints_long_filtered$CUTPOINT
  ))
}


# Analyse 3 stage seqs ##################################################################
by_case_id_3stages <- t_events_ccc %>%
  filter(MILESTONES == '3STAGES') %>% 
  select(-MILESTONES) %>% 
  group_by(CASE_ID, CASE_TYPE) %>%
  nest() %>%
  mutate(BINS = map2(data, .$CASE_ID, ~create_bins(df = .x, case_id = .y)))

t_3stages <- by_case_id_3stages %>% select(CASE_ID, CASE_TYPE, BINS) %>% unnest() %>% 
  mutate(PERIOD = case_when(
    is.na(BINS) ~ '1_BEFORE_REPORT',
    BINS == 'REPORT_LOWERBOUND' ~ '2_ON_REPORT',
    BINS == 'REPORT_UPPERBOUND' ~ '3_REPORT_DECISION',
    BINS == 'DECISION_LOWERBOUND' ~ '4_ON_DECISION',
    BINS == 'DECISION_UPPERBOUND' ~ '5_DECISION_CLOSE',
    BINS == 'CLOSE_LOWERBOUND' ~ '6_ON_CLOSE',
    BINS == 'CLOSE_UPPERBOUND' ~ '7_AFTER_CLOSE'
  )) %>% 
  group_by(PERIOD, CASE_TYPE) %>% 
  summarize(N_OF_CALLS = n()) %>% 
  tidyr::spread(key = CASE_TYPE, value = N_OF_CALLS)



# Analyse 2 stage seqs ##################################################################
by_case_id_2stages <- t_events_ccc %>%
  filter(MILESTONES == '2STAGES') %>% 
  select(-MILESTONES) %>% 
  group_by(CASE_ID, CASE_TYPE) %>%
  nest() %>%
  mutate(BINS = map2(data, .$CASE_ID, ~create_bins(df = .x, case_id = .y)))

t_2stages <- by_case_id_2stages %>% select(CASE_ID, CASE_TYPE, BINS) %>% unnest() %>% 
  mutate(PERIOD = case_when(
    is.na(BINS) ~ '1_BEFORE_REPORT',
    BINS == 'REPORT_LOWERBOUND' ~ '2_ON_REPORT',
    BINS == 'REPORT_UPPERBOUND' ~ '3_REPORT_CLOSE',
    BINS == 'CLOSE_LOWERBOUND' ~ '4_ON_CLOSE',
    BINS == 'CLOSE_UPPERBOUND' ~ '5_AFTER_CLOSE'
  )) %>% 
  group_by(PERIOD, CASE_TYPE) %>% 
  summarize(N_OF_CALLS = n()) %>% 
  tidyr::spread(key = CASE_TYPE, value = N_OF_CALLS)



