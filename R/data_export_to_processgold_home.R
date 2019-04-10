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
query_claims_process <- "select distinct * from t_claims_home_pa_output"
t_claims_home <- dbGetQuery(jdbcConnection, query_claims_process)

# Close db connection: kontakt
dbDisconnect(jdbcConnection)


# Alter names in original
names(t_claims_home) <- c("Case ID", "Activity", "Event end")


# Save
write.table(t_claims_home,
  here::here("Data", "t_claims_pa_PG_export_home.csv"),
  row.names = FALSE, sep = ";", quote = FALSE
)



