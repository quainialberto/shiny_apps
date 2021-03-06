time_series_data <- readr::read_csv("data/time_series_data.csv")
tagging_data <- readr::read_csv("data/tagging_data.csv")

#### UI
#' @title Cross-sectional plotting (UI)
#' @description Plot the cross-section of a given parameter in a panel of data. Compare over time.
#' @param module_header_text \code{character}, defines some local module title.
#' @details The module allows the user to look at snapshots of cross-sectional values of variables across time. \cr \cr
#' There are the following static UI elements: \cr
#' - \code{textOutput("site_header")} renders the title of the page \cr
#' - \code{actionButton("validate_and_proceed")} finishes work on the step and forces a move down the workflow \cr
#' - the plotting area. Time series plots.  \cr
#' - \code{plotOutput("cs_plot")} or \code{plotly::plotlyOutput("cs_plot")}. Multiple plots with link-brushing 
#' (see documentation of \code{brush} argument in \code{\link[shiny]{plotOutput}}).\cr
#' - \code{textOutput("brushed_series")} names of series that are covered by the plot brushing \cr
#' \cr
#' There are the following dynamic UI elements, generated in \code{\link{cross_sectional_plotting}}: \cr
#' - A \code{selectInput} (single) box with \code{value_types} which should be put on the x axis, 
#' which are populated from the \code{value_type} column of \code{time_series_data} in the server function 
#' \code{\link{cross_sectional_plotting}}. \cr
#' - A \code{selectInput} (multiple) box with \code{value_types} which should be put on the y axis, populated as above. \cr
#' - A \code{selectInput} (multiple) box with \code{tags} so that various subsets of the data can be highlighted. 
#' Populated with distinct tags from \code{tagging_data}\cr
#' - A \code{selectInput} (multiple) for dates at which plots will be prepared, we need to max it out at some number, say 5.
#' \cr \cr
#' An alternative to generating is using \code{updateSomeElement} functions.
#' @seealso \code{\link{cross_sectional_plotting}}
#' @export


cross_sectional_plotting_ui <- function(id, module_header_text){
  ns <- NS(id)
  
  fluidRow(
    tags$h1(gettext(module_header_text)),

    sidebarLayout(
      sidebarPanel(
        # selectizeInput (single) value type for x
        selectizeInput(ns("value_type_x"), choices = NULL,
                       label = gettext("Value type for x-axis")),

        # selectizeInput (multiple) value type for y
        # selectizeInput(ns("value_types_y"), choices = NULL,
        #              label = gettext("(multiple) value types for y-axis"),
        #              multiple = TRUE),
        uiOutput(ns("value_types_y_selector")),

        # selectizeInput (single) frequency
        selectizeInput(ns("frequency"), choices = NULL,
                       label = gettext("Frequency")),

        # selectizeInput tags
        selectizeInput(ns("tags"), choices = NULL,
                       label = gettext("Tags"),
                       multiple = TRUE),

        # dateInput
        selectizeInput(ns("dates_input"), choices = NULL,
                       label = gettext("(multiple) dates for plots"),
                       multiple = TRUE, options = list(maxItems = 3)),

        tags$br(),

        # textOutput of selected series
        uiOutput(ns("help_brushed_series")),
        verbatimTextOutput(ns("brushed_series"))
      ),

      mainPanel(
        # dataTable of series
        plotOutput(ns("cs_plot_1"), brush = brushOpts(ns("plot_brush"))),
        plotOutput(ns("cs_plot_2")),
        plotOutput(ns("cs_plot_3"))
      )
    )
  )

}

#' @title Cross-sectional plotting (server)
#' @description Plot the cross-section of a given parameter in a panel of data. Compare over time.
#' @param time_series_data tidy \code{data.frame} that is the output of \code{\link{data_presentation_and_selection}}. 
#' The standard tidy dataset has to contain a \code{selection} column for gouping of variables / portoflios in the plots.
#' @param tagging_data \code{data.frame} that contains information about the grouping of data for aggregate/cross-sectional 
#' plotting. This table is formed at the financial instrument level. It has two columns: \code{id} and \code{tag}. 
#' You can have multiple \code{ids} per \code{tag} and vice versa. 
#' @return The function passes a list with the \code{time_series_data} structure and summary tables that were formed for plots.
#' @details The purpose of this module is to visualise the stability of rankings/relationships over time. 
#' The objective is to create graphs in this spirit: \url{http://shiny.rstudio.com/gallery/module-example.html}. \cr\cr 
#' The user selects a number of dates. The number of plot panels filled is 5 at a maximum. \cr\cr
#' For each date, a scatterplot is generated for \code{value_types} chosen by the user on the x and y axis. 
#' Multiple value types can be chosen for the y axis. \cr\cr
#' An extra \code{value_type} called \code{ranking} is added. \code{ranking} is dynamically generated and is simply 
#' the ascending ordering rank of the \code{value_type} which is the first choice of the y axis.
#' Picking the \code{selections} highlights points for entities belonging to that selection in all plots.
#' @export

#### brushing per stat::qq non operativo


ggplot_function <- function(dataframe, input_date, input_tags, id_brushed) {
  data <- dataframe %>%
    dplyr::filter(date %in% base::as.Date(input_date))

    if(!is.null(input_tags)) {
      ggplot2::ggplot(data, ggplot2::aes(x = x, y = y, color = tag)) +
        ggplot2::geom_point() +
        ggplot2::geom_point(data = data %>% dplyr::filter(id %in% id_brushed), size = 4, shape= 2)
    } else {
      ggplot2::ggplot(data, ggplot2::aes(x = x, y = y)) +
        ggplot2::geom_point() +
        ggplot2::geom_point(data = data %>% dplyr::filter(id %in% id_brushed), size = 4, shape = 2)
    }
}



cross_sectional_plotting <- function(input, output, session, time_series_data, tagging_data, value_type_line_type){
  
  ns <- session$ns
  
  # vector to choose values for x from
  value_type_vector <- reactive({
    validate(need(time_series_data(), gettext("Time series data")))
    time_series_data() %>%
      dplyr::select(value_type) %>% dplyr::distinct() %>% .[[1]]
  })
  
  # update selection of value type x
  observeEvent(value_type_vector(), {
    updateSelectizeInput(session, "value_type_x",
                         choices = c(value_type_vector(), "ranking"),
                         selected = value_type_vector()[1],
                         server = TRUE)
  })
  
  # select value type 2 (from all but value type 1)
  value_types_y_vector <- reactive({
    req(input$value_type_x)
    value_type_vector()[value_type_vector() != input$value_type_x]
  })
  
  output$value_types_y_selector <- renderUI({
    req(value_types_y_vector())
    ifelse(input$value_type_x != "ranking", multiple_y <- TRUE, multiple_y <- FALSE)
    
    selectizeInput(ns("value_types_y"), gettext("Value types for y-axis"),
                   choices = value_types_y_vector(),
                   selected = value_types_y_vector()[1],
                   multiple = multiple_y)
  })
  
  observeEvent({
    input$value_type_x
  }, {
    req(input$value_types_y)
    value_types_y_selected <- if(isTruthy(input$value_types_y) & (input$value_types_y %in% value_types_y_vector())) {
                              input$value_types_y
                              } else {
                              value_types_y_vector()[1]
                              }
    
    updateSelectizeInput(session, "value_types_y",
                         selected = value_types_y_selected)
    
  })
  
  # frequency vector responsive to previous choices
  frequency_vector <- reactive({
    req(input$value_types_y)
    
    if(input$value_type_x != "Ranking") {
      time_series_data() %>%
        dplyr::filter(value_type %in% c(input$value_type_x, input$value_types_y)) %>%
        tidyr::spread(key = value_type, value = value) %>% tidyr::drop_na() %>% 
        dplyr::select(frequency) %>% dplyr::distinct() %>% .[[1]]
    } else { time_series_data() %>%
        dplyr::filter(frequency %in% input$value_types_y) %>% 
        dplyr::select(frequency) %>% dplyr::distinct() %>% .[[1]]
    }
  })
  
  # frequency selected. If there is a selection, keep it except if it is not valid. If there
  # is no selection, take the first element of frequency_vector
  frequency_selected <- reactive({
    req(frequency_vector())
    if(isTruthy(input$frequency) & (input$frequency %in% frequency_vector())) {
      input$frequency
    } else {
      frequency_vector()[1]
    }
  })
  
  # update frequency choice
  observeEvent(frequency_vector(), {
    
    updateSelectizeInput(session, "frequency",
                         choices = frequency_vector(),
                         selected = frequency_selected(),
                         server = TRUE)
  })
  
  dates_vector <- reactive({
    req(input$frequency)
    time_series_data() %>%
      dplyr::filter(frequency %in% input$frequency) %>%
      dplyr::select(date) %>% dplyr::distinct() %>% .[[1]]
  })
  
  dates_selected <- reactive({
    req(input$dates_input)

    if_else(as.Date(input$dates_input) %in% dates_vector(),
           as.Date(input$dates_input),
           dates_vector()[1:3])
  })
  
  # selectize dates
  observeEvent(dates_vector(), {
    req(dates_vector())
    dates_select <- if(isTruthy(input$dates_input)) {
      dates_selected()
    } else {NULL}
    
    updateSelectizeInput(session, "dates_input",
                         choices = dates_vector(),
                         selected = dates_select,
                         server = TRUE)
  })
  
  # selectize tags
  observeEvent(tagging_data(), {
    tag_vector <- tagging_data() %>%
      dplyr::select(tag) %>%
      dplyr::distinct() %>% .[[1]]
    
    updateSelectizeInput(session, "tags",
                         choices = tag_vector,
                         server = TRUE)
  })
  
  # reactive dataframe for plots
  plot_dataframe <- reactive({
    req(input$value_type_x)
    req(input$value_types_y)
    req(input$frequency)
    req(input$dates_input)
    
    intermediate_dataframe <- if(input$value_type_x != "ranking") {
      time_series_data() %>%
        dplyr::filter(value_type %in% c(input$value_type_x, input$value_types_y),
                      frequency %in% input$frequency,
                      date %in% base::as.Date(input$dates_input)) %>%
        tidyr::spread(key = value_type, value = value) %>%
        tidyr::gather_(gather_cols = input$value_type_x, key_col = "useless_x", value_col = "x") %>%
        tidyr::gather_(gather_cols = input$value_types_y, key_col = "useless_y", value_col = "y")
    } else {
      dataf <- time_series_data() %>%
        dplyr::filter(value_type %in% input$value_types_y,
                      frequency %in% input$frequency,
                      date %in% base::as.Date(input$dates_input)) %>% 
        dplyr::group_by(date) %>%
        dplyr::mutate(x = dplyr::percent_rank(value)) %>% ungroup()
      names(dataf)[names(dataf) == "value"] <- "y"
      dataf
    }
    
    if(!is.null(input$tags)) {
      intermediate_dataframe %>%
        dplyr::left_join(tagging_data() %>% dplyr::filter(tag %in% input$tags))
    } else {
      intermediate_dataframe
    }
    
  })
  
  # plot at date 1
  output$cs_plot_1 <- renderPlot({
    req(input$value_type_x)
    validate(need(input$dates_input, gettext("Date 1")))
    
      ggplot_function(plot_dataframe(), input$dates_input[1], input$tags, NULL)
  })
  
  brushed_data <- reactive({
    brushedPoints(plot_dataframe() %>% 
                    dplyr::filter(date %in% base::as.Date(input$dates_input[1])), input$plot_brush)
  })
  
  # vector of brushed ids
  id_brushed <- reactive({
    req(plot_dataframe())
    
    brushed_data() %>%
      dplyr::select(id) %>% dplyr::distinct() %>% .[[1]]
  })
  
  # help text brushed series
  output$help_brushed_series <- renderUI({
    req(input$plot_brush)
    helpText(gettext("Brushed series"))
  })
  
  # text brushed series
  output$brushed_series <- renderText({
    req(input$plot_brush)
    base::paste0(brushed_data() %>% dplyr::select(name) %>% dplyr::distinct() %>% .[[1]])
  })
  
  # plot at date 2
  output$cs_plot_2 <- renderPlot({
    req(plot_dataframe(), input$value_type_x)
    validate(need(input$dates_input[2], gettext("Date 2")))
      ggplot_function(plot_dataframe(), input$dates_input[2], input$tags, id_brushed())
  })
  
  # plot at date 3
  output$cs_plot_3 <- renderPlot({
    req(plot_dataframe(), input$value_type_x)
    validate(need(input$dates_input[3], gettext("Date 3")))
      ggplot_function(plot_dataframe(), input$dates_input[3], input$tags, id_brushed())
  })
  
}