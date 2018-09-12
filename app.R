#########################################################################################
# BUILD AND RUN PROCESS MINING SHINY APP ################################################
#########################################################################################

# Load required libs --------------------------------------------------------------------
library(shiny)
library(dplyr)
library(lubridate)
library(bupaR)
library(processmapR)
library(DiagrammeR)


# Load event log ------------------------------------------------------------------------
t_event_log_app <- read.csv(here::here("Data", "t_event_log.csv"),
                            stringsAsFactors = FALSE) %>% 
                    mutate(Peril_type = as.factor(Peril_type),
                           Claim_status_date = ymd_hms(Claim_status_date))


# User interface ------------------------------------------------------------------------
ui <- fluidPage(
  titlePanel("Casco Claims Process: FAIRKAR Status Logs"),
  sidebarLayout(
    sidebarPanel(
      sliderInput("traceFreqInput", strong("Trace Frequency"),
                  min = 0,
                  max = 1,
                  value = 0.25
      ),
      checkboxGroupInput("perilTypeInput", strong("Peril Type"),
                         choices = levels(t_event_log_app$Peril_type),
                         selected = levels(t_event_log_app$Peril_type),
                         inline = TRUE
      ),
      sliderInput("paymentMaxInput", strong("Max Payment"),
                  min = min(t_event_log_app$Payment_sum_max),
                  max = max(t_event_log_app$Payment_sum_max),
                  value = c(min(t_event_log_app$Payment_sum_max),
                            max(t_event_log_app$Payment_sum_max)),
                  pre = "HUF "
      ),
      actionButton("runFilter", "Generate process map!")
    ),
    mainPanel(
      tabsetPanel(type = "tabs",
                  tabPanel("Frequency map", grVizOutput("freqMap",
                                                        width = "100%",
                                                        height = "800px")),
                  tabPanel("Performance map", grVizOutput("perfMap",
                                                          width = "100%", 
                                                          height = "800px")))
    )
  )
)


# Server --------------------------------------------------------------------------------
server <- function(input, output) {
  
  filtered <- eventReactive(input$runFilter, {
    t_event_log_app %>%
      filter(
        Peril_type %in% input$perilTypeInput &
          Payment_sum_max >= input$paymentMaxInput[1] &
          Payment_sum_max <= input$paymentMaxInput[2]
      ) %>%
      eventlog(
        case_id = "Claim_number",
        activity_id = "Claim_status_EN",
        activity_instance_id = "ACTIVITY_INST_ID",
        lifecycle_id = "LIFECYCLE_ID",
        timestamp = "Claim_status_date",
        resource_id = "Claim_adjuster_code"
      ) %>%
      filter_trace_frequency(percentage = input$traceFreqInput, reverse = F) 
  })

  output$freqMap <- renderGrViz({
    filtered() %>%
      process_map(type_nodes = frequency("absolute"),
                  type_edges = frequency("absolute"), rankdir = "TB")
  })

  output$perfMap <- renderGrViz({
    filtered() %>%
      process_map(performance(median, "days"), rankdir = "TB")
  })
}

shinyApp(ui, server)