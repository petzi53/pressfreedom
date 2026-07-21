## inst/app/R/mod_inputs.R
## Module for the Trends sidebar input controls.
##
## inputsUI()     — sidebar widget HTML
## inputsServer() — returns list(var, country) as reactives
##
## Variable choices are Score/Rank only. Dimension variables
## (political/economic/legal/social context, safety) only span 2022+ and
## are dropped from this multi-country, multi-year picker on purpose —
## see AGENTS.md / the redesign plan for why (they remain available as
## single-year map-coloring options and, per-country, as a short 2022-25
## trend in the Country view).

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
            choices = c("Select countries..." = "", sort(unique(rwb$country_en))),
            selected = character(0),
            multiple = TRUE
        ),
        shiny::actionButton(
            ns("clear"),
            "Clear all",
            icon  = shiny::icon("times"),
            class = "btn-sm btn-outline-secondary w-100 mt-1"
        )
    )
}

inputsServer <- function(id, selected_country = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        shiny::observeEvent(input$clear, {
            shiny::updateSelectInput(session, "country", selected = character(0))
        })

        # When selected_country changes (from a click in another view),
        # add it to the Trends country selection if not already present
        shiny::observeEvent(selected_country(), {
            shiny::req(selected_country())
            current_selection <- input$country
            new_country <- selected_country()
            if (!new_country %in% current_selection) {
                updated_selection <- c(current_selection, new_country)
                shiny::updateSelectInput(session, "country", selected = updated_selection)
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
