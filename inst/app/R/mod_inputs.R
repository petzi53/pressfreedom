## inst/app/R/mod_inputs.R
## Module for the Trends sidebar input controls.
##
## inputsUI()     — sidebar widget HTML
## inputsServer() — returns list(var, country, last_country) as reactives.
##   `last_country` is `tail(input$country, 1)` (or NA_character_ when
##   empty), recomputed on every change — used by app.R to keep the
##   Country view's single-select synced to whichever country currently
##   sits last in the Trends list (see AGENTS.md's "Trends <-> Country
##   sync" section).
##
## Variable choices are Score/Rank only. Dimension variables
## (political/economic/legal/social context, safety) only span 2022+ and
## are dropped from this multi-country, multi-year picker on purpose —
## see AGENTS.md / the redesign plan for why (they remain available as
## single-year map-coloring options and, per-country, as a short 2022-25
## trend in the Country view).

inputsUI <- function(id, rwb_standardized) {
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
            choices = c("Select countries..." = "", sort(unique(rwb_standardized$country_en))),
            selected = character(0),
            multiple = TRUE
        ),
        shiny::actionButton(
            ns("clear"),
            "Clear",
            icon  = shiny::icon("times"),
            class = "btn-sm btn-outline-secondary w-100 mt-1"
        ),
        shiny::uiOutput(ns("download_ui"))
    )
}

inputsServer <- function(id, selected_country = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns
        
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

        # Derived reactive (not a reactiveVal/event log): recomputes from
        # whatever input$country currently is on every change. app.R
        # resyncs the Country view's selection to this value each time
        # it changes — see AGENTS.md's "Trends <-> Country sync" section
        # for why a plain reactive (no nonce) is enough here, unlike
        # `selected_country`'s nonce elsewhere in the app.
        last_country <- shiny::reactive({
            cnty <- input$country
            if (length(cnty) > 0) utils::tail(cnty, 1) else NA_character_
        })

        # CSV download button: always visible, disabled with message when no countries
        output$download_ui <- shiny::renderUI({
            if (length(input$country) == 0) {
                shiny::tagList(
                    shiny::tags$button(
                        "Download CSV",
                        class = "btn btn-sm btn-outline-secondary w-100 mt-2",
                        disabled = "disabled"
                    ),
                    shiny::div(
                        "No country data available for download.",
                        class = "text-muted small mt-1"
                    )
                )
            } else {
                shiny::downloadButton(ns("download"), "Download CSV", 
                                       class = "btn-sm btn-outline-secondary w-100 mt-2")
            }
        })
        
        # Placeholder for the download handler: will be set by chartServer()
        # This reactive holds the current data to download
        download_data <- shiny::reactiveVal(NULL)
        
        # CSV download handler: wired to the inputs module's download button
        output$download <- shiny::downloadHandler(
            filename = function() {
                shiny::req(download_data())
                n_countries <- length(input$country)
                variable <- download_data()$variable
                if (n_countries == 1) {
                    country_slug <- tolower(gsub("[^a-z0-9]", "", tolower(input$country[1])))
                    sprintf("pressfreedom_trends_%s_%s.csv", variable, country_slug)
                } else {
                    sprintf("pressfreedom_trends_%s_compare_countries.csv", variable)
                }
            },
            content = function(file) {
                shiny::req(download_data())
                write_csv_with_notes(download_data()$data, file, for_trends = TRUE)
            }
        )

        # Return inputs as reactives and the download_data reactive
        # so parent/sibling modules can consume them
        list(
            var = shiny::reactive(input$var),
            country = shiny::reactive(input$country),
            last_country = last_country,
            download_data = download_data
        )
    })
}

compareSidebarUI <- inputsUI
