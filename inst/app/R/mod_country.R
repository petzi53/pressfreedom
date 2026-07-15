## inst/app/R/mod_country.R
## Country profile module: time-series charts for a single country across all dimensions

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
            bslib::card_header("Dimensions Overview (2022–Present)"),
            shiny::uiOutput(ns("plot_or_placeholder"))
        )
    )
}

countryServer <- function(id, rwb) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Define the dimensions we care about
        dim_cols <- c("score", "political_context", "economic_context",
                      "legal_context", "social_context", "safety")

        # Clean names for display in annotations and hover
        dim_labels <- c(
            "score"             = "Global Score",
            "political_context" = "Politics",
            "economic_context"  = "Economy",
            "legal_context"     = "Law",
            "social_context"    = "Society",
            "safety"            = "Safety"
        )

        # Okabe-Ito colorblind-safe palette; Global Score is black
        color_map <- c(
            "score"             = "#000000",
            "political_context" = "#0072B2",
            "economic_context"  = "#D55E00",
            "legal_context"     = "#009E73",
            "social_context"    = "#CC79A7",
            "safety"            = "#56B4E9"
        )

        shiny::observeEvent(input$clear, {
            shiny::updateSelectInput(session, "country", selected = "")
        })

        # Dynamic header
        output$country_header <- shiny::renderUI({
            shiny::req(input$country != "")
            shiny::tags$h3(
                card_title("score", input$country),
                class = "mb-0"
            )
        })

        output$plot_or_placeholder <- shiny::renderUI({
            if (is.null(input$country) || input$country == "") {
                shiny::div(
                    style = "display: flex; align-items: center; justify-content: center; height: 100%; color: #6c757d;",
                    shiny::p("Select a country to display the chart.")
                )
            } else {
                plotly::plotlyOutput(ns("plot_overview"), height = "100%")
            }
        })

        # Overview Plot: All dimensions in one (2022 onwards)
        output$plot_overview <- plotly::renderPlotly({

            # Get all data for this country, filtering to 2022+
            data_long <- rwb |>
                dplyr::filter(country_en == input$country, year_n >= 2022) |>
                tidyr::pivot_longer(
                    cols      = dplyr::all_of(dim_cols),
                    names_to  = "dimension",
                    values_to = "value"
                ) |>
                dplyr::mutate(dimension = factor(dimension, levels = dim_cols))

            if (nrow(data_long) == 0) {
                return(plotly::plot_ly() |>
                         plotly::layout(title = "No data available"))
            }

            max_year <- max(data_long$year_n)

            # Sort dimensions by their value at max_year (descending) so the
            # legend order matches the vertical position of lines in the chart
            end_vals <- data_long |>
                dplyr::filter(year_n == max_year) |>
                dplyr::group_by(dimension) |>
                dplyr::summarise(value = dplyr::first(value), .groups = "drop") |>
                dplyr::arrange(dplyr::desc(value))

            dims_ordered <- as.character(end_vals$dimension)

            # Start with an empty plot, then add one trace per dimension
            p <- plotly::plot_ly()

            for (dim in dims_ordered) {
                df_dim <- data_long |> dplyr::filter(dimension == dim)

                p <- p |>
                    plotly::add_trace(
                        data       = df_dim,
                        x          = ~year_n,
                        y          = ~value,
                        type       = "scatter",
                        mode       = "lines+markers",
                        name       = dim_labels[dim],
                        line       = list(color = color_map[dim], width = 4),
                        marker     = list(color = color_map[dim], size = 20),
                        hovertemplate = paste0(
                            "<b>", dim_labels[dim], "</b><br>",
                            "Year: %{x}<br>",
                            "Value: %{y:.1f}<extra></extra>"
                        )
                    )
            }

            p |>
                plotly::layout(
                    font       = list(size = 16),
                    showlegend = TRUE,
                    legend     = list(
                        orientation = "v",
                        x           = 1.02,
                        xanchor     = "left",
                        y           = 1,
                        yanchor     = "top"
                    ),
                    xaxis  = list(title = "Year", dtick = 1),
                    yaxis  = list(title = "Index Value"),
                    margin = list(r = 120)
                )
        })
    })
}
