## inst/app/R/mod_chart.R
## Module for the Trends chart card (title + plotly output + click popover).
##
## chartUI()     — card HTML: title, plot output, and a small popover panel
##                 for click-to-inspect
## chartServer() — renders title text and the plotly chart; wires
##                 hover-dims-others and click-to-navigate
##
## Arguments passed to chartServer():
##   rwb      — the full data frame (non-reactive)
##   var      — reactive string: "score" or "rank" (dimensions dropped
##              from the Trends variable picker — see AGENTS.md for why)
##   country  — reactive character vector of selected country names
##
## Returns: a reactive holding the country name most recently confirmed
## via the popover's "Go to Country view" button (or NULL). Wired at the
## app level the same way mapServer()'s click reactive is — full
## consolidation into one shared "selected country" reactive across all
## views is a later step.
##
## Hover-dims-others and click-to-inspect both need a trace -> country
## lookup. Rather than tracking trace order by hand (fragile once the
## bump chart's extra geom_text label traces are involved), each trace's
## `name` is read back from the built widget: plot_ly()'s `color =` and
## ggplot's `aes(color = country_en)` both set trace `name` to the
## country automatically. Only the two geom_text label traces (drawn
## with a fixed color, not mapped to country) come back unnamed — those
## are simply excluded from hover-dimming and click-to-inspect.

pal <- RColorBrewer::brewer.pal(12, "Paired")

# Which country each trace in a built plotly object belongs to (see the
# header comment above for why this is read from `name` rather than
# tracked by construction order). NA for unnamed traces.
chart_trace_countries <- function(p) {
    traces <- plotly::plotly_build(p)$x$data
    vapply(traces, function(tr) {
        nm <- tr[["name"]]
        if (is.null(nm)) NA_character_ else nm
    }, character(1))
}

chartUI <- function(id) {
    ns <- shiny::NS(id)
    bslib::card(
        height = "calc(100vh - 105px)",
        bslib::card_header(shiny::textOutput(ns("title"))),
        shiny::div(
            style = "position: relative; height: 100%;",
            shiny::uiOutput(ns("plot_or_placeholder")),
            shiny::uiOutput(ns("popover"))
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

        # Populated as a side effect of renderPlotly (below): both the
        # hover and click handlers need this same trace -> country
        # lookup, and it depends on the plot that was just built, not on
        # reactive inputs they could recompute independently.
        trace_countries <- shiny::reactiveVal(character(0))

        # Currently-inspected point, shown in the popover (NULL = hidden)
        click_info <- shiny::reactiveVal(NULL)

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
            click_info(NULL) # new chart -> any open popover no longer applies

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
                        yaxis = list(title = "Score")
                    )
            }

            trace_countries(chart_trace_countries(p_final))

            p_final |>
                plotly::event_register("plotly_hover") |>
                plotly::event_register("plotly_unhover") |>
                plotly::event_register("plotly_click")
        })

        # Hover-dims-others: fade every trace except the hovered country's
        # via a restyle, so the whole plot doesn't have to re-render.
        #
        # event_data() is called from a plain observe() (not
        # observeEvent()) so it's never evaluated before a chart has
        # actually rendered: calling event_data() at all schedules a
        # session$onFlushed() check of whether its `source` was ever
        # registered via event_register(), and that registration only
        # happens once renderPlotly() below has run at least once. With
        # observeEvent() the event_data() call is the trigger expression
        # itself, so it fires unconditionally the moment the module
        # server starts — before any countries are selected and thus
        # before there is a chart to register against — producing a
        # one-time, but harmless-looking, "source ... is not registered"
        # warning at startup. Gating on trace_countries() (populated only
        # once renderPlotly() has actually built a plot) avoids that.
        shiny::observe({
            shiny::req(length(trace_countries()) > 0)
            ed <- plotly::event_data("plotly_hover", source = ns("plot"))
            countries_ <- trace_countries()
            shiny::req(
                !is.null(ed$curveNumber),
                length(countries_) >= ed$curveNumber + 1
            )
            hovered <- countries_[ed$curveNumber + 1]
            shiny::req(!is.na(hovered))

            opacities <- ifelse(countries_ == hovered, 1, 0.15)
            opacities[is.na(opacities)] <- 0.15
            plotly::plotlyProxy("plot", session) |>
                plotly::plotlyProxyInvoke(
                    "restyle",
                    list(opacity = as.list(opacities)),
                    as.list(seq_along(opacities) - 1)
                )
        })

        shiny::observe({
            shiny::req(length(trace_countries()) > 0)
            plotly::event_data("plotly_unhover", source = ns("plot"))
            n <- length(trace_countries())
            plotly::plotlyProxy("plot", session) |>
                plotly::plotlyProxyInvoke(
                    "restyle",
                    list(opacity = as.list(rep(1, n))),
                    as.list(seq_len(n) - 1)
                )
        })

        # Click-to-inspect: clicking a point opens a small popover (flag,
        # country, year, score/rank) with a "Go to Country view" button —
        # the same underlying navigation mechanic as the map's
        # click-to-navigate (mapServer()'s clicked-country reactive). See
        # the hover observer above for why event_data() is only called
        # once a chart (and thus trace_countries()) actually exists.
        shiny::observe({
            shiny::req(length(trace_countries()) > 0)
            ed <- plotly::event_data("plotly_click", source = ns("plot"))
            countries_ <- trace_countries()
            shiny::req(
                !is.null(ed$curveNumber),
                length(countries_) >= ed$curveNumber + 1
            )
            clicked_country <- countries_[ed$curveNumber + 1]
            shiny::req(!is.na(clicked_country))

            row <- data() |>
                dplyr::filter(country_en == clicked_country, year_n == round(ed$x))
            shiny::req(nrow(row) > 0)
            row <- row[1, ]

            click_info(list(
                country = clicked_country,
                iso     = row$iso,
                year    = row$year_n,
                value   = row[[var()]]
            ))
        })

        output$popover <- shiny::renderUI({
            info <- click_info()
            if (is.null(info)) return(NULL)

            metric_label  <- if (var() == "rank") "Rank" else "Score"
            value_display <- if (var() == "rank") info$value else round(info$value, 1)

            shiny::div(
                style = paste(
                    "position: absolute; top: 12px; right: 12px; z-index: 10;",
                    "background: white; border: 1px solid #dee2e6; border-radius: 6px;",
                    "box-shadow: 0 2px 8px rgba(0,0,0,0.15); padding: 10px 12px;",
                    "min-width: 190px;"
                ),
                shiny::div(
                    style = "display: flex; justify-content: space-between; align-items: center; gap: 0.5em;",
                    shiny::span(
                        flag_img_tag(info$iso, alt = info$country, height = "1.1em"),
                        shiny::strong(info$country)
                    ),
                    shiny::actionLink(
                        ns("close_popover"), shiny::icon("times"),
                        style = "color: #6c757d;"
                    )
                ),
                shiny::div(
                    style = "font-size: 0.9rem; margin-top: 4px;",
                    paste0(info$year, " \u00b7 ", metric_label, ": ", value_display)
                ),
                shiny::actionButton(
                    ns("go_to_country"), "Go to Country view \u2192",
                    class = "btn-sm btn-outline-primary w-100 mt-2"
                )
            )
        })

        shiny::observeEvent(input$close_popover, click_info(NULL))

        go_to_country <- shiny::reactiveVal(NULL)
        shiny::observeEvent(input$go_to_country, {
            shiny::req(click_info())
            go_to_country(click_info()$country)
            click_info(NULL)
        })

        shiny::reactive(go_to_country())
    })
}

compareMainUI <- chartUI
