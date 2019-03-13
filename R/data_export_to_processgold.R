library(config)
library(here)
library(dplyr)


#########################################################################################
# Data Extraction #######################################################################
#########################################################################################

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

# Open connection: kontakt---------------------------------------------------------------
jdbcConnection <-
  dbConnect(
    jdbcDriver,
    url = datamnr$server,
    user = datamnr$uid,
    password = datamnr$pwd
  )

# Fetch data
query_claims_process <- "select distinct * from T_CLAIMS_PA_OUTPUT_CCC_OKK"
t_claims_pa <- dbGetQuery(jdbcConnection, query_claims_process)

query_claims_process_fair <- "select distinct * from T_CLAIMS_PA_OUTPUT_CCC_OKK where ACTIVITY_TYPE =  'FAIRKAR'"
t_claims_pa_fair <- dbGetQuery(jdbcConnection, query_claims_process_fair)

query_claims_process_kontaktokk <- "select distinct * from T_CLAIMS_PA_OUTPUT_CCC_OKK where ACTIVITY_TYPE =  'KONTAKT OKK'"
t_claims_pa_kontaktokk <- dbGetQuery(jdbcConnection, query_claims_process_kontaktokk)

query_claims_process_kontaktccc <- "select distinct * from T_CLAIMS_PA_OUTPUT_CCC_OKK where ACTIVITY_TYPE =  'KONTAKT OKK'"
t_claims_pa_kontaktccc <- dbGetQuery(jdbcConnection, query_claims_process_kontaktccc)

# Close db connection: kontakt
dbDisconnect(jdbcConnection)


# Check names in original
names(t_claims_pa)

# Concat media and activity -------------------------------------------------------------

# Define func for data export
create_export <- function(df, suffix = "") {
  # Select cols
  df_export <- df %>%
    select(CASE_ID, EVENT_END, ACTIVITY_EN, ACTIVITY_TYPE, ACTIVITY_CHANNEL, CASE_TYPE, USER_ID) %>%
    arrange(CASE_ID, EVENT_END)

  # Change colnames to names to fit PG
  names(df_export) <- c("Case ID", "Event end", "Activity",
                        "Activity type", "Activity channel","Case type", "User")

  # Save
  write.table(df_export,
    here::here("Data", paste0("t_claims_pa_PG_export", suffix, ".csv")),
    row.names = FALSE, sep = ";", quote = FALSE
  )
}

# Export
create_export(t_claims_pa)
create_export(t_claims_pa_fair, suffix = 'fairkar')
create_export(t_claims_pa_kontaktokk, suffix = 'kontaktokk')
create_export(t_claims_pa_kontaktccc, suffix = 'kontaktccc')


