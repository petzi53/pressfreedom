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
                "Global Rank" = "rank",
                "Political Context" = "political_context",
                "Economic Context" = "economic_context",
                "Legal Context" = "legal_context",
                "Social Context" = "social_context",
                "Safety" = "safety"
            )
        ),
        shiny::selectInput(
            inputId = ns("country"),
            label = "Countries",
            choices = unique(rwb$country_en),
            multiple = TRUE
        ),
        # Conditional warning note for dimension variables (2022+ only)
        shiny::uiOutput(ns("dimension_note"))
    )
}

inputsServer <- function(id) {
    shiny::moduleServer(id, function(input, output, session) {
        # Show warning note when a dimension variable is selected
        output$dimension_note <- shiny::renderUI({
            if (input$var %in% c("political_context", "economic_context", "legal_context", "social_context", "safety")) {
                shiny::div(
                    class = "alert alert-warning alert-sm",
                    shiny::icon("exclamation-triangle"),
                    "Data available for 2022 onwards only."
                )
            }
        })

        # Return inputs as reactives
        # so parent/sibling modules can consume them
        list(
            var = shiny::reactive(input$var),
            country = shiny::reactive(input$country)
        )
    })
}

compareSidebarUI <- inputsUI
