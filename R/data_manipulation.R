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
library(stringr)


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


# Add flag for cases pending (excluding pending for 3 months)
t_casco_claims <- t_casco_claims %>%
  group_by(Claim_number) %>% 
  mutate(helper = case_when(stringr::str_detect(stringr::str_to_lower(Claim_status_EN), "pending") & 
                              Claim_status_EN != "Pending for 3 months" ~ 1,
                          TRUE ~ 0
                          )) %>%
  mutate(Pending = max(helper)) %>% 
  ungroup() %>% 
  select(-helper)


# Add month date of first event as categ var
t_casco_claims <- t_casco_claims %>%
  group_by(Claim_number) %>% 
  mutate(Case_start_date = as.character(min(lubridate::floor_date(Claim_status_date, unit = "month")))) %>% 
  ungroup() %>% 
  mutate(Case_start_month = paste0(substr(Case_start_date, 1, 4), "/", substr((Case_start_date), 6, 7))) %>% 
  select(-Case_start_date)


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