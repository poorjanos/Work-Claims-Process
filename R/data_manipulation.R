#########################################################################################
# DATA MANIPULATION PIPELINE TO CLEAN AND TRANSFORM RAW DATA INTO BUPAR EVENT-LOG #######
#########################################################################################

# Load required libs --------------------------------------------------------------------
library(here)
library(readxl)
library(dplyr)
library(ggplot2)
library(tidyr)
library(lubridate)
library(bupaR)
library(processmapR)
library(processmonitR)


# Load raw data -------------------------------------------------------------------------
t_casco_claims <- read_xlsx(here::here("Data", "FAIR_CASCO_Claims_2017-2018_EN.xlsx"))


# Delete repeated rows of the same event ------------------------------------------------
# (e.g .get rid of events that do not alter state)
t_casco_claims <- t_casco_claims %>%
  arrange(Claim_number, Claim_status_date) %>%
  group_by(Claim_number) %>%
  mutate(previous_status_code = lag(Claim_status_code, default = '999')) %>%
  ungroup() %>%
  filter(Claim_status_code != previous_status_code) %>%
  select(-previous_status_code)


# Add col with maximum of Payment sum for later filtering
t_casco_claims <- t_casco_claims %>% 
  replace_na(list(Payment_sum = 0)) %>% 
  group_by(Claim_number) %>% 
  mutate(Payment_sum_max = max(Payment_sum)) %>% 
  ungroup()


# Add event-log specific fields required by bupaR ---------------------------------------
t_casco_claims <- t_casco_claims %>%
  mutate(
    ACTIVITY_INST_ID = as.numeric(row.names(.)),
    LIFECYCLE_ID = "END"
  )


# Save to local storage -----------------------------------------------------------------
write.csv(t_casco_claims,
  here::here("Data", "t_event_log.csv"),
  row.names = FALSE
)