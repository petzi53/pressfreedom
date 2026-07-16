## inst/app/R/mod_country.R
## Country profile module.
##
## The previous standalone "Dimensions Overview" chart (all 5
## explanatory factors + score, 2022-present, for one country) has been
## removed here: it's superseded by the redesigned Country view — a
## rank/score stat block plus a differently-scoped Explanatory Factors
## chart (2022-2025 only) and an embedded compact Trends chart — which is
## still to be built. This module is a placeholder in the meantime so
## the app keeps running with 3 working nav panels.

countrySidebarUI <- function(id, rwb) {
    ns <- shiny::NS(id)
    shiny::tagList(
        shiny::selectInput(
            ns("country"),
            label = "Select country",
            choices = c("Select a country..." = "", sort(unique(rwb$country_en))),
            selected = ""
        ),
        shiny::actionButton(
            ns("clear"),
            "Clear",
            icon  = shiny::icon("times"),
            class = "btn-sm btn-outline-secondary w-100 mt-1"
        )
    )
}

countryMainUI <- function(id) {
    ns <- shiny::NS(id)
    shiny::tagList(
        shiny::uiOutput(ns("country_header")),
        bslib::card(
            height = "calc(100vh - 155px)",
            shiny::uiOutput(ns("placeholder"))
        )
    )
}

countryServer <- function(id, rwb) {
    shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$clear, {
            shiny::updateSelectInput(session, "country", selected = "")
        })

        output$country_header <- shiny::renderUI({
            shiny::req(input$country != "")
            shiny::tags$h3(
                card_title("score", input$country),
                class = "mb-0"
            )
        })

        output$placeholder <- shiny::renderUI({
            msg <- if (is.null(input$country) || input$country == "") {
                "Select a country to view its profile."
            } else {
                "Country profile redesign in progress."
            }
            shiny::div(
                style = "display: flex; align-items: center; justify-content: center; height: 100%; color: #6c757d;",
                shiny::p(msg)
            )
        })
    })
}
