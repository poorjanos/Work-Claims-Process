#########################################################################################
# EDA pipeline to explore log ###########################################################
#########################################################################################

# Load required libs --------------------------------------------------------------------
library(dplyr)
library(lubridate)
library(bupaR)
library(edeaR)
library(ggplot2)


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

#Filter for specific end activity
t_event_log_cleaned <- t_event_log %>%
  filter_endpoints(end_activities = "Closed", reverse = F)


# Gen desriptive stats ------------------------------------------------------------------
# Number of traces
t_event_log %>%
  number_of_traces()


# Throughput time
t_event_log %>%
  throughput_time(level = "log", units = "day") %>%
  plot()

  # Throughput time histogram
  t_throughput_case <- t_event_log_cleaned %>% throughput_time(level = "case", units = "day")
  ggplot(t_throughput_case, aes(x = throughput_time)) +
    geom_histogram(bins = 30) +
    theme_minimal()


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
  plot()


# End activities
t_event_log %>%
  end_activities("activity") %>% 
  plot()


# Trace coverage
t_event_log_cleaned %>%
  trace_coverage("trace") %>%
  plot()


# Trace length
t_event_log_cleaned %>%
  trace_length()


# Categorical analysis ------------------------------------------------------------------

# Breakdown by happy flow
t_event_log_cleaned %>% 
  group_by(Pending) %>% 
  trace_length()

t_event_log_cleaned %>% 
  group_by(Pending) %>% 
  throughput_time(level = "log", units = "day") %>%
  plot()

# Breakdown by month of case start
t_event_log_cleaned %>% 
  group_by(Case_start_month) %>% 
  trace_length() %>% 
  plot()

t_event_log_cleaned %>% 
  group_by(Case_start_month) %>% 
  throughput_time(level = "log", units = "day") %>%
  plot()

  # Box plot for month
  t_month_throughput <- t_event_log_cleaned %>% 
    filter(!Case_start_month %in% c("2018/06", "2018/07", "2018/08", "2018/09")) %>% 
    group_by(Case_start_month) %>% 
    throughput_time(level = "case", units = "day") %>%
    ungroup()
  
  ggplot(t_month_throughput, aes(x = Case_start_month, y = throughput_time)) +
    geom_boxplot() + 
    coord_cartesian(ylim = c(0, 120)) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 90))
  
  
  
  