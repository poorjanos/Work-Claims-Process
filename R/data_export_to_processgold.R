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
query_claims_process <- "select distinct * from T_CLAIMS_PA_OUTPUT"
t_claims_pa <- dbGetQuery(jdbcConnection, query_claims_process)

# Close db connection: kontakt
dbDisconnect(jdbcConnection)




# Check names in original
names(t_claims_pa)

# Concat media and activity -------------------------------------------------------------
# Select cols
t_claims_pa_PG_export <- t_claims_pa %>%
  select(CASE_ID, EVENT_END, ACTIVITY_EN, ACTIVITY_TYPE, USER_ID) %>%
  arrange(CASE_ID, EVENT_END)

# Change colnames to names to fit PG
names(t_claims_pa_PG_export) <- c("Case ID", "Event end", "Activity", "Activity type", "User")

# Save
write.table(t_claims_pa_PG_export,
            here::here("Data", "t_claims_pa_PG_export.csv"),
            row.names = FALSE, sep = ";", quote = FALSE)



