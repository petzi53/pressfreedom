## inst/app/R/mod_inputs.R
## Module for the sidebar input controls.
##
## inputsUI()     — sidebar widget HTML
## inputsServer() — returns list(var, country) as reactives

inputsUI <- function(id, rwb) {
    ns <- shiny::NS(id)
    shiny::tagList(
        shiny::selectInput(
            inputId = ns("var"),
            label = "Score or Rank Type",
            choices = c(
                "Global Score" = "score",
                "Global Rank" = "rank"
            )
        ),
        shiny::selectInput(
            inputId = ns("country"),
            label = "Countries",
            choices = unique(rwb$country_en),
            multiple = TRUE
        )
    )
}

inputsServer <- function(id) {
    shiny::moduleServer(id, function(input, output, session) {
        # Return both inputs as reactives
        # so parent/sibling modules can consume them
        list(
            var = shiny::reactive(input$var),
            country = shiny::reactive(input$country)
        )
    })
}
