#########################################################################################
# EDA pipeline to explore log ###########################################################
#########################################################################################

# Load required libs --------------------------------------------------------------------
library(dplyr)
library(lubridate)
library(bupaR)
library(edeaR)


# Run data manipulation pipeline --------------------------------------------------------
source(here::here("R", "data_manipulation.R"))


# Gen event log ------------------------------------------------------------------------
t_event_log <- read.csv(here::here("Data", "t_event_log.csv"),
  stringsAsFactors = FALSE
) %>%
  mutate(
    Peril_type = as.factor(Peril_type),
    Claim_status_date = ymd_hms(Claim_status_date)
  ) %>%
  eventlog(
    case_id = "Claim_number",
    activity_id = "Claim_status_EN",
    activity_instance_id = "ACTIVITY_INST_ID",
    lifecycle_id = "LIFECYCLE_ID",
    timestamp = "Claim_status_date",
    resource_id = "Claim_adjuster_code"
  )


# Number of traces
t_event_log %>%
  number_of_traces()


# Throughput time
t_event_log %>%
  throughput_time(level = "log", units = "day") %>%
  plot()


# Activity presence and frequency
t_event_log %>% activity_presence() %>% # as of cases
  plot()


t_event_log %>%
  activity_frequency("activity") %>% # as of activities
  plot()


# Activity frequency
t_event_log %>%
  activity_frequency("log") %>% # number of steps
  plot()


# Start activities
t_event_log %>%
  start_activities("activity") %>% 


# End activities
t_event_log %>%
  end_activities("activity") %>% 
  plot()


# Trace coverage
t_event_log %>%
  trace_coverage("trace") %>%
  plot()


# Trace length
t_event_log %>%
  trace_length()
