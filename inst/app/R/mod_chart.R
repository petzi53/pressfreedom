## inst/app/R/mod_chart.R
## Module for the Trends chart card (title + plotly output + click-to-
## navigate).
##
## chartUI()     — card HTML: title + plot output
## chartServer() — renders title text and the plotly chart; wires
##                 hover-dims-others and click-to-navigate
##
## Arguments passed to chartServer():
##   rwb      — the full data frame (non-reactive)
##   var      — reactive string: "score" or "rank" (dimensions dropped
##              from the Trends variable picker — see AGENTS.md for why)
##   country  — reactive character vector of selected country names
##
## Returns: a reactive holding list(country=, nonce=) for the most
## recently clicked chart point (or NULL) — not a bare string; see the
## "Most recently clicked country" comment below for why the nonce is
## needed. Wired at the app level the same way mapServer()'s click
## reactive is — both feed into one shared "selected country"
## reactiveVal in app.R.
##
## Both hover-dimming and click-to-navigate are handled entirely
## client-side via an onRender JS callback (see renderPlotly below).
## Each trace's `name` (set by plot_ly(color=) / ggplot aes(color=))
## is the country name; the JS click handler reads it directly from
## el.data[curveNumber].name, avoiding an R-side lookup.

pal <- RColorBrewer::brewer.pal(12, "Paired")

chartUI <- function(id, height = "calc(100vh - 105px)") {
    ns <- shiny::NS(id)
    bslib::card(
        height = height,
        bslib::card_header(shiny::textOutput(ns("title"))),
        shiny::div(
            style = "position: relative; height: 100%;",
            shiny::uiOutput(ns("plot_or_placeholder"))
        )
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

        # Most recently clicked country (triggers navigation). Stored as
        # list(country=, nonce=) rather than a bare string: reactiveVal()
        # skips invalidating dependents when set to a value identical()
        # to its current one. The nonce (proc.time() elapsed seconds)
        # ensures two clicks are never identical(), even when the country
        # name repeats or when a different module already set the same
        # country into the shared selected_country reactiveVal in app.R.
        clicked_country_nav <- shiny::reactiveVal(NULL)

        output$title <- shiny::renderText({
            shiny::req(length(country()) > 0, data())
            card_title(var(), country(), unique(data()$year_n))
        })

        output$plot_or_placeholder <- shiny::renderUI({
            msg <- if (length(country()) == 0) {
                "Select one or more countries to display the chart."
            } else if (nrow(data()) == 0) {
                # Some entities (e.g. defunct historical states) have rank
                # but no score data, or vice versa; df_chart()'s na.omit()
                # drops such rows entirely, and max(data()$year_n) inside
                # renderPlotly below would otherwise warn/return -Inf on
                # the resulting empty data frame.
                "No data available for the selected country/countries and metric."
            }
            if (!is.null(msg)) {
                shiny::div(
                    style = "display: flex; align-items: center; justify-content: center; height: 100%; color: #6c757d;",
                    shiny::p(msg)
                )
            } else {
                plotly::plotlyOutput(ns("plot"), height = "100%")
            }
        })

        output$plot <- plotly::renderPlotly({
            # nrow(data()) > 0 matters, not just data() being non-NULL:
            # df_chart()'s na.omit() can leave a 0-row tibble for a
            # country with no non-NA values for this metric (e.g. a
            # defunct historical state with rank but no score), and
            # max(data()$year_n) below would warn/return -Inf on that.
            # This render function still runs even when
            # plot_or_placeholder (above) is showing a message instead of
            # plotlyOutput, since Shiny doesn't know to suspend it without
            # a live browser reporting visibility.
            shiny::req(length(country()) > 0, nrow(data()) > 0)

            # Subset palette to the number of selected countries
            n   <- length(country())
            col <- stats::setNames(pal[seq_len(n)], country())

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

                p_final <- plotly::ggplotly(p, source = ns("plot")) |>
                    plotly::layout(
                        font = list(size = 18),
                        dragmode = FALSE
                    )
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

                # Line chart for score
                p_final <- plotly::plot_ly(
                    data   = df_ordered,
                    x      = ~year_n,
                    y      = as.formula(paste0("~", var())),
                    color  = ~country_en,
                    colors = col,
                    type   = "scatter",
                    mode   = "lines+markers",
                    line   = list(width = 4),
                    marker = list(size = 20),
                    source = ns("plot")
                ) |>
                    plotly::layout(
                        font  = list(size = 18),
                        xaxis = list(title = "Year"),
                        yaxis = list(title = "Score"),
                        dragmode = FALSE
                    )
            }

            # All interactive behavior — click-to-navigate AND
            # hover-dims-others — is handled client-side via onRender
            # to avoid plotlyProxy restyle round-trips. The R-side
            # plotlyProxy approach caused a coerceTraceIndices error
            # on the very first hover (traces not yet initialized
            # client-side), and that error killed the same message
            # batch as the nav_select from a simultaneous click,
            # silently swallowing the first click's navigation.
            #
            # Moving everything to JS eliminates the error entirely
            # and makes hover-dimming instant (no server round-trip).
            p_final |>
                htmlwidgets::onRender(sprintf("
                    function(el, x) {
                        var nTraces = el.data.length;

                        // Click-to-navigate — extract the country name
                        // directly from the trace (trace.name is set to the
                        // country by plot_ly(color=) / ggplot aes(color=)),
                        // so we don't need an R-side trace_countries() lookup.
                        el.on('plotly_click', function(data) {
                            var pt = data.points[0];
                            var country = el.data[pt.curveNumber].name || null;
                            if (country) {
                                Shiny.setInputValue('%s',
                                    {country: country},
                                    {priority: 'event'}
                                );
                            }
                        });

                        // Hover: dim all traces except the hovered one
                        el.on('plotly_hover', function(data) {
                            var hovered = data.points[0].curveNumber;
                            var opacities = [];
                            for (var i = 0; i < nTraces; i++) {
                                opacities.push(i === hovered ? 1 : 0.15);
                            }
                            Plotly.restyle(el, 'opacity', opacities);
                        });

                        // Unhover: restore all traces to full opacity
                        el.on('plotly_unhover', function() {
                            var opacities = [];
                            for (var i = 0; i < nTraces; i++) {
                                opacities.push(1);
                            }
                            Plotly.restyle(el, 'opacity', opacities);
                        });
                    }
                ", ns("direct_click")))
        })

        # Click-to-navigate: the country name arrives from JS
        # (el.data[curveNumber].name) as click$country — no R-side
        # trace lookup needed.
        shiny::observe({
            click <- input$direct_click
            shiny::req(click, !is.null(click$country))
            clicked_country_nav(list(
                country = click$country,
                nonce = as.numeric(proc.time()[["elapsed"]])
            ))
        })

        shiny::reactive(clicked_country_nav())
    })
}

compareMainUI <- chartUI
