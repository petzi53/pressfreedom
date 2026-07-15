## inst/app/R/mod_chart.R
## Module for the chart card (title + plotly output).
##
## chartUI()     — card HTML containing title and plot output
## chartServer() — renders title text and the plotly chart
##
## Arguments passed to chartServer():
##   rwb      — the full data frame (non-reactive)
##   var      — reactive string: "score" or "rank"
##   country  — reactive character vector of selected country names

pal <- RColorBrewer::brewer.pal(12, "Paired")

chartUI <- function(id) {
    ns <- shiny::NS(id)
    bslib::card(
        height = "calc(100vh - 105px)",
        bslib::card_header(shiny::textOutput(ns("title"))),
        shiny::uiOutput(ns("plot_or_placeholder"))
    )
}

chartServer <- function(id, rwb, var, country) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Filtered data reacts to var and country selections
        data <- shiny::reactive({
            shiny::req(length(country()) > 0)
            df_chart(rwb, var(), country())
        })

        output$title <- shiny::renderText({
            shiny::req(length(country()) > 0, data())
            card_title(var(), country(), unique(data()$year_n))
        })

        output$plot_or_placeholder <- shiny::renderUI({
            if (length(country()) == 0) {
                shiny::div(
                    style = "display: flex; align-items: center; justify-content: center; height: 100%; color: #6c757d;",
                    shiny::p("Select one or more countries to display the chart.")
                )
            } else {
                plotly::plotlyOutput(ns("plot"), height = "100%")
            }
        })

        output$plot <- plotly::renderPlotly({
            shiny::req(length(country()) > 0, data())

            # Subset palette to the number of selected countries
            n   <- length(country())
            col <- stats::setNames(pal[seq_len(n)], country())

            # Determine y-axis title based on selected variable
            y_title <- switch(var(),
                "score" = "Score",
                "rank" = "Rank",
                "political_context" = "Political Context",
                "economic_context" = "Economic Context",
                "legal_context" = "Legal Context",
                "social_context" = "Social Context",
                "safety" = "Safety",
                "Value"
            )

            if (var() == "rank") {
                # Bump chart for ranks
                p <- ggplot2::ggplot(
                    data(),
                    ggplot2::aes(x = year_n, y = rank, color = country_en)
                ) +
                    ggbump::geom_bump(linewidth = 1.0) +
                    ggplot2::geom_point(size = 5) +
                    ggplot2::geom_text(
                        data = data() |> dplyr::filter(year_n == min(year_n)),
                        ggplot2::aes(label = iso),
                        nudge_x = -1, size = 5, color = "black", hjust = 1
                    ) +
                    ggplot2::geom_text(
                        data = data() |> dplyr::filter(year_n == max(year_n)),
                        ggplot2::aes(label = iso),
                        nudge_x = 1, size = 5, color = "black", hjust = 0
                    ) +
                    ggplot2::theme_bw() +
                    ggplot2::theme(legend.position = "none") +
                    ggplot2::scale_y_reverse(breaks = ggplot2::waiver(), n.breaks = 25) +
                    ggplot2::scale_x_continuous(
                        breaks = seq(min(data()$year_n), max(data()$year_n), by = 2)
                    ) +
                    ggplot2::scale_colour_manual(values = col) +
                    ggplot2::xlab("Year") +
                    ggplot2::ylab("Rank")

                plotly::ggplotly(p) |>
                    plotly::layout(font = list(size = 18))
            } else {
                # Sort countries by descending value at max year so the legend
                # order matches the vertical position of the lines
                max_year   <- max(data()$year_n)
                country_order <- data() |>
                    dplyr::filter(year_n == max_year) |>
                    dplyr::arrange(dplyr::desc(.data[[var()]])) |>
                    dplyr::pull(country_en)

                df_ordered <- data() |>
                    dplyr::mutate(
                        country_en = factor(country_en, levels = country_order)
                    )

                # Line chart for score and dimension variables
                plotly::plot_ly(
                    data   = df_ordered,
                    x      = ~year_n,
                    y      = as.formula(paste0("~", var())),
                    color  = ~country_en,
                    colors = col,
                    type   = "scatter",
                    mode   = "lines+markers",
                    line   = list(width = 4),
                    marker = list(size = 20)
                ) |>
                    plotly::layout(
                        font  = list(size = 18),
                        xaxis = list(title = "Year"),
                        yaxis = list(title = y_title)
                    )
            }
        })
    })
}

compareMainUI <- chartUI
