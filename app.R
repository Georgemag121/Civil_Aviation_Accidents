require(shiny)
require(shinythemes)
require(tidyverse)
require(ggmap)
require(wordcloud)
require(tm)
require(RWeka)

df <- read.csv("data/data_for_vis.csv", stringsAsFactors = F)

aircrafts <- unique(df$Type.new)
airlines <- unique(df$Operator)
phases <- unique(df$Phase)
engines <- unique(df$Engine.brand)

tokenizer <- function(x) {
  NGramTokenizer(x, Weka_control(min = 2, max = 2))
}

ui <- fluidPage(theme = shinytheme("cerulean"),
   
   titlePanel("Air Crash Data"),
   
   # Sidebar with a slider input for number of bins 
   sidebarLayout(
      sidebarPanel(
        sliderInput("year", "Year Range", min = 1919, max = 2019, value = c(1919, 2019)),
        
        selectInput("aircraft", "Aircraft Type", choices = c(aircrafts, "all"), selected = "all"),
        
        selectInput("airline", "Airline", choices = c(airlines, "all"), selected = "all"),
        
        selectInput("phase", "Phase", choices = c(phases, "all"), selected = "all"),
        
        selectInput("engine", "Engine Brand", choices = c(engines, "all"), selected = "all"),
        
        hr(),
        
        actionButton("runButton", "Run Text Analysis")
        
      ),
      
      mainPanel(
        h4("Accidents and Death Toll over year"),
        plotOutput("accidents"),
        uiOutput("summary"),
        hr(),
        plotOutput("map"),
        h4("Wordcloud bi-gram"),
        plotOutput("wordcloud2"),
        h4("Common terms"),
        tableOutput("common.terms")
      )
   )
)

server <- function(input, output, session) {
   
  theme1 <- list(theme(panel.grid.minor = element_blank(),
                        plot.background = element_blank()))
  
  my_data <- reactive({
    req(input$year, input$aircraft, input$airline, input$phase, input$engine)
    df1 <- df %>% filter(Date >= input$year[1], Date <= input$year[2] + 1)
    if (input$aircraft != "all") {
      df1 <- df1 %>% filter(Type.new == input$aircraft)
    }
  
    if (input$airline != "all") {
      df1 <- df1 %>% filter(Operator == input$airline)
    }
    
    if (input$phase != "all") {
      df1 <- df1 %>% filter(Phase == input$phase)
    }
  
    if (input$engine != "all") {
      df1 <- df1 %>% filter(Engine.brand == input$engine)
    }
  
    df1
  })
   
  output$accidents <- renderPlot({
    req(my_data())
     my_data() %>% group_by(Year) %>% summarise(Accidents = n(), Death = sum(Total.fatalities, na.rm = T)) %>% 
       ggplot(aes(x = Year)) + 
       geom_line(aes(y = Accidents, col = "Accidents")) + 
       geom_line(aes(y = Death/13, col = "Death Toll")) + 
       scale_y_continuous(name = "Accidents", sec.axis = sec_axis(~.*13, name = "Death Toll")) + 
       scale_color_manual(values = c("blue", "red")) + 
       theme1 + 
       theme(legend.position = c(0.1, 0.9))
   })
  
  data_geo <- reactive({
    req(my_data())
    df1 <- my_data() %>% mutate(geocheck = abs(dep.lon - lon) >= 0.00001 & abs(dep.lat - lat) >= 0.00001 
                                & abs(des.lon - lon) >= 0.00001 & abs(des.lat - lat) >= 0.00001 
                                & abs(des.lon - dep.lon) >= 0.00001 & abs(des.lat - dep.lat) >= 0.00001)
    
    df2 <- df1 %>% filter(geocheck == T)
    
    df2
  })
  
  output$map <- renderPlot({
    req(data_geo(), my_data())
    
    worldmap <- borders("world", color = "#f2ffe6", fill = "#f2ffe6")
    
    ggplot() + worldmap + 
      geom_curve(data = data_geo(), aes(x = dep.lon, y = dep.lat, xend = lon, yend = lat), size = 0.3, col = "#ff9999", curvature = 0.1) + 
      geom_curve(data = data_geo(), aes(x = lon, y = lat, xend = des.lon, yend = des.lat), size = 0.3, linetype = "dashed", col = "#ff9999", curvature = 0.1) + 
      #geom_point(data = data_geo(), aes(x = dep.lon, y = dep.lat), col = "#000d1a", size = 0.1) + 
      #geom_point(data = data_geo(), aes(x = des.lon, y = des.lat), col = "#000d1a", size = 0.1) + 
      geom_point(data = my_data(), aes(x = lon, y = lat), shape = 4, col = "#ff0000", size = 1.2) + 
      theme(panel.background = element_rect(fill = "white"), 
            axis.line = element_blank(),
            axis.text.x = element_blank(),
            axis.text.y = element_blank(),
            axis.ticks = element_blank(),
            axis.title.x = element_blank(),
            axis.title.y = element_blank()
      )
  })
  
  bigram_dtm_matrix <- eventReactive(input$runButton, {
    req(my_data())
    
    progress <- Progress$new(session, min = 1, max = 20)
    on.exit(progress$close())
    
    progress$set(message = 'Generating wordcloud')
    
    for (i in 1:20) {
      progress$set(value = i)
      Sys.sleep(0.5)
    }
    
    corp <- VCorpus(VectorSource(tolower(my_data()$Probable.Cause[!is.na(my_data()$Probable.Cause)])))
    corp <- corp %>% tm_map(PlainTextDocument) %>% tm_map(removeNumbers) %>% tm_map(removePunctuation) %>% 
      tm_map(removeWords, c(stopwords("en"), stopwords("french"), stopwords("spanish"), 
                            "flight", "plane", "aircraft", "probable", "cause", "accident", 
                            "airplane", "account", "according", "causes", "findings", "contributing", 
                            "factors", "factor"))
    
    dtm <- DocumentTermMatrix(corp)
    dtm <- removeSparseTerms(dtm, 0.99)
    
    bigram_dtm <- DocumentTermMatrix(corp, control = list(tokenize = tokenizer))
    bigram_dtm_m <- as.matrix(bigram_dtm)
    
    bigram_dtm_m
  })
  
  output$wordcloud2 <- renderPlot({
    req(my_data(), bigram_dtm_matrix())
    
    freq <- colSums(bigram_dtm_matrix())
    bi_words <- names(freq)
    
    wordcloud(bi_words, freq, colors = "red", max.words = 25)
  })
  
  output$common.terms <- renderTable({
    req(my_data(), bigram_dtm_matrix())
    
    freq <- colSums(bigram_dtm_matrix())
    freq.terms <- sort(freq, decreasing = T)[1:10]
    
    data.frame("Terms" = as.character(names(freq.terms)), "Frequency" = as.integer(freq.terms))
  })
  
  ###### Text output
  keystats <- reactive({
    req(my_data())
    st <- rep(0, 14)
    
    # Total accidents
    st[1] <- nrow(df)
    st[2] <- nrow(my_data())
    
    # Total fatalities
    df.surv <- df %>% filter(!is.na(Total.fatalities), !is.na(Occupants.total))
    mydf.surv <- my_data() %>% filter(!is.na(Total.fatalities), !is.na(Occupants.total))
    
    st[3] <- sum(df.surv$Total.fatalities)
    st[4] <- sum(mydf.surv$Total.fatalities)
    
    # Average fatalities for fatal accidents
    st[5] <- round(st[3]/st[1], 1)
    st[6] <- round(st[4]/st[2], 1)
    
    # Overall survival rate
    st[7] <- round(sum(df.surv$Total.fatalities)/sum(df.surv$Occupants.total), 4) *100
    st[8] <- round(sum(mydf.surv$Total.fatalities)/sum(mydf.surv$Occupants.total), 4) *100
    
    # Non-fatal accidents
    st[9] <- round(sum(df.surv$Total.fatalities == 0)/nrow(df.surv), 4) *100
    st[10] <- round(sum(mydf.surv$Total.fatalities == 0)/nrow(mydf.surv), 4) *100
    
    # Average fatalities for fatal accidents
    st[11] <- round(sum(df.surv$Total.fatalities[which(df.surv$Total.fatalities > 0)])/
                      sum(df.surv$Total.fatalities > 0), 1)
    st[12] <- round(sum(mydf.surv$Total.fatalities[which(mydf.surv$Total.fatalities > 0)])/
                      sum(mydf.surv$Total.fatalities > 0), 1)
    
    # Survivable accidents
    st[13] <- round(sum(df.surv$Survivable)/nrow(df.surv), 4) *100
    st[14] <- round(sum(mydf.surv$Survivable)/nrow(mydf.surv), 4) *100
    
    # AirFrame hours
    st[15] <- round(mean(df$Total.airframe.hrs, na.rm = T), 0)
    st[16] <- round(mean(my_data()$Total.airframe.hrs, na.rm = T), 0)
    
    # Aircraft age
    st[17] <- round(mean(df$Age, na.rm = T), 1)
    st[18] <- round(mean(my_data()$Age, na.rm = T), 1)
    
    st
  })
  
  output$summary <- renderUI({
    req(keystats())
    tag1 <- tagList(
      tags$h4("Here are some numbers"),
      tags$div(HTML(paste0("For the selected group, there were a total of ", 
                           tags$span(style = "color:red", keystats()[2]), " accidents (out of ", 
                           keystats()[1], " accidents) resulting in ", 
                           tags$span(style = "color:red", keystats()[4]), " fatalities (out of ",
                           keystats()[3], " deaths in all accidents), with an average of ",
                           tags$span(style = "color:red", keystats()[6]), " fatalities per accident (",
                           keystats()[5], " for all accidents)."))),
      tags$div(HTML(paste0("The overall survival rate of accidents of the selected group is ", 
                           tags$span(style = "color:red", paste0(keystats()[8]), "%"), " (", keystats()[7], 
                           "% for all accidents)."))),
      tags$div(HTML(paste0("The percentage of non-fatal accidents of the selected group is ", 
                           tags$span(style = "color:red", paste0(keystats()[10]), "%"), " (", keystats()[9], 
                           "% for all accidents)."))),
      tags$div(HTML(paste0("The average fatalities for fatal accidents of the selected group is ", 
                           tags$span(style = "color:red", keystats()[12]), " (", keystats()[11], 
                           " for all accidents)."))),
      tags$div(HTML(paste0("The percentage of survivable accidents of the selected group is ", 
                           tags$span(style = "color:red", paste0(keystats()[14]), "%"), " (", keystats()[13], 
                           "% for all accidents)."))),
      tags$div(HTML(paste0("The average airframe hour for selected group is ", 
                           tags$span(style = "color:red", paste0(keystats()[16]), "hrs"), " (", keystats()[15], 
                           " hrs for all accidents)."))),
      tags$div(HTML(paste0("The average aircraft age for selected group is ", 
                           tags$span(style = "color:red", paste0(keystats()[18]), "yrs"), " (", keystats()[17], 
                           " yrs for all accidents).")))
      )
    tag1
  })
}

shinyApp(ui = ui, server = server)

