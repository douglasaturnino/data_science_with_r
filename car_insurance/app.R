# Imports --------------------------
library(shiny)
library(shinydashboard)
library(tidyverse)
library(tidymodels)
library(kknn)
library(DT)
library(openxlsx)

# Model ----------------------------
model <- readRDS("final_model.rds")

# Dashboard elements ---------------

## HEADER --------------------------
header <- dashboardHeader(title="Car Insurance")

## SIDEBAR -------------------------

sidebar <- dashboardSidebar(
  sidebarMenu(
    menuItem("Single Client", tabName = "single_client_tab", icon= icon("hospital")),
    menuItem("Group of Client", tabName = "group_tab", icon = icon("th")),
    menuItem("About", tabName = "about_tab", icon = icon("fa fa-sticky-note"))
  )
)

## BODY ----------------------------

body <- dashboardBody(
  # Add a CSS class to the dashboardBody
  tags$style(HTML(".content-wrapper, .right-side { overflow-y: auto; }")),
  tabItems(
    # single Client -----------------
    tabItem(
      tabName = "single_client_tab",
      h1("Single Client"),
      box(
        title = "Probability to accept the car insurance",
        width = 8, solidHeader = TRUE, status = "primary",
        valueBoxOutput("prediction")
      ),
      box(sliderInput("day_associated", label = h3("Days Associated"), min = 10, max = 299, value = 154)),
      box(sliderInput("health_annual_paid", label = h3("Health Annual Paid"), min = 2630, max = 540165, value = 31669)),
      box(selectInput("previously_insured", label = h3("Previously Insured"), choices = , c("yes", "no"), selected = "yes")),
      box(sliderInput("age", label = h3("Age"), min = 20, max = 85, value = 35)),
      box(selectInput("vehicle_damage", label = h3("Vehicle Damage"), choices = , c("yes", "no"), selected = "yes")),
      box(sliderInput("region_code", label = h3("Region Code"), min = 0, max = 52, value = 28)),
      box(sliderInput("policy_sales_channel", label = h3("Policy Sales Channel"), min = 1, max = 163, value = 133)),
    ),
    
    # Group of Clients----------------
    tabItem(
      tabName = "group_tab",
      h1("Group of Clients"),
      dashboardBody(
        fileInput("file", label = h3("Choose CSV File "), accept = c(".csv")),
        numericInput("numRows", label = h3("Number of Clients to Call:"), value = 5),
        tags$hr(),
        downloadButton("download_csv", "Download CSV"),
        downloadButton("download_excel", "Download Excel"),
        tags$hr(),
        DTOutput("table")
        
      )
    ),
    # About --------------------------
    tabItem(
      tabName = "about_tab",
      h1("About"),
      p("This dashboard offers three tabs where you can find out if a user is a potential car insurance customer."),
      p("In the first tab you can define information about a customer and the output will be the probability of purchasing insurance."),
      p("In the second tab you can upload a csv file, and you will have an ordered list of potential customers to call and offer car insurance. You can download the output as csv or excel file."),
      p("You can find more information about the project on" , a(href = "https://github.com/douglasaturnino/data_science_with_r", "GitHub", target="_blank"), ".")
    )
  )
)

# User Interface--------------------
ui <- dashboardPage(
  header,
  sidebar,
  body
)

# Serve ----------------------------- 
server <- function(input, output) {
  
  output$prediction <- renderValueBox({
    # Create user table -------------
    clients <- tibble(
      "age" = input$age,                  
      "day_associated" = input$day_associated,      
      "health_annual_paid" = input$health_annual_paid,   
      "region_code" = input$region_code,           
      "policy_sales_channel" = input$policy_sales_channel, 
      "vehicle_damage" = input$vehicle_damage,     
      "previously_insured" = input$previously_insured
    )
    # Make predicttion ---------------
    prediction <- predict(model, clients, type= "prob")
    
    pred_yes <- prediction %>% 
      select(.pred_yes) %>% 
      pull()
    
    prediction_color <- case_when(
      pred_yes < 0.25 ~ "red",
      pred_yes >= 0.25 & pred_yes < 0.50 ~ "orange",
      pred_yes >= 0.5 & pred_yes < 0.75 ~ "green",
      pred_yes > 0.75 ~ "blue"
    )
    
    valueBox(
      value = paste0(round(100*pred_yes, 2), " %"),
      subtitle = "Yes probability",
      color = prediction_color,
      icon = icon("car")
    )
    
  })
  
  # Save the .csv file
  data <- reactive({
    req(input$file)
    read.csv(input$file$datapath)
  })
  
  # Run the model
  output$table <- renderDT({
    predict_clients <- predict_clients()
  })
  
  # Predict customers
  result <- function(){ 
    return (predict(model, data() %>% select(-id), type= "prob"))
  }
  
  # returns the table with predictions
  predict_clients <- function(){
    return (
    data() %>% 
    select(id) %>% 
    bind_cols(result()) %>% 
    arrange(desc(.pred_yes))
    )
  }
  
  output$download_csv <- downloadHandler(
    filename = function() {
      "car insurannce.csv"
    },
    content = function(file) {
      # Write all predict_clients data to the csv file
      write.csv(predict_clients(), file, row.names = FALSE)
    }
  )
  
  output$download_excel <- downloadHandler(
    filename = function() {
      "car insurannce.xlsx"
    },
    content = function(file) {
      # Write all predict_clients data to the Excel file
      openxlsx::write.xlsx(predict_clients(), file, rownames = FALSE)
    }
  )
  
}

# App -------------------------------
shinyApp(ui, server)