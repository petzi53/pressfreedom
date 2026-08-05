## inst/app/R/mod_chart.R
## Module for the Trends chart card (title + plotly output + click-to-
## navigate).
##
## chartUI()     — card HTML: title + plot output
## chartServer() — renders title text and the plotly chart; wires
##                 hover-dims-others and click-to-navigate
##
## Arguments passed to chartServer():
##   rwb_standardized      — the full data frame (non-reactive)
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
        bslib::card_header(
            shiny::textOutput(ns("title"))
        ),
        shiny::div(
            style = "position: relative; height: 100%;",
            shiny::uiOutput(ns("plot_or_placeholder"))
        )
    )
}

chartServer <- function(id, rwb_standardized, var, country, inputs_download_data = NULL) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Filtered data reacts to var and country selections
        data <- shiny::reactive({
            shiny::req(length(country()) > 0)
            df_chart(rwb_standardized, var(), country())
        })
        
        # Populate the inputs module's download_data reactive whenever data changes
        # so the download handler in inputs module can access it
        if (!is.null(inputs_download_data)) {
            shiny::observe({
                shiny::req(length(country()) > 0)
                inputs_download_data(list(
                    data = data(),
                    variable = var()
                ))
            })
        }

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
                # Sort countries by ascending rank at the final year (best
                # rank first) so the legend order matches the vertical
                # stacking of curves at the right edge of the chart — the
                # y-axis is reversed (scale_y_reverse below), so "best" sits
                # at the top, mirroring the score branch's descending sort.
                max_year <- max(data()$year_n)
                country_order <- data() |>
                    dplyr::filter(year_n == max_year) |>
                    dplyr::arrange(rank) |>
                    dplyr::pull(country_en)

                df_ordered <- data() |>
                    dplyr::mutate(
                        country_en = factor(country_en, levels = country_order),
                        hover_text = paste0(
                            flag_emoji(iso), " ", country_en,
                            "<br>Year: ", year_n,
                            "<br>Rank: ", rank
                        )
                    )

                # Bump chart for ranks. Tooltip text is mapped only on
                # geom_point() (the real yearly data points) — geom_bump()'s
                # layer data is a smoothed/interpolated curve, not real
                # year/rank pairs, so a hover value there would be
                # misleading. ggplotly() auto-deduplicates legend entries
                # that share a legendgroup (here, country), keeping just one
                # entry per country regardless of each layer's own
                # show.legend — verified empirically; the explicit
                # show.legend = FALSE on geom_bump() is left in as documented
                # intent, but ggplotly() ends up attaching the surviving
                # legend swatch to the line trace either way.
                # geom_point()'s `text` aes isn't a real ggplot2 aesthetic —
                # only ggplotly() reads it later to build the tooltip — so
                # ggplot2 warns "Ignoring unknown aesthetics: text" on
                # construction. Harmless; suppressed here (same pattern as
                # mod_country.R's combined trend charts).
                p <- suppressWarnings(ggplot2::ggplot(
                    df_ordered,
                    ggplot2::aes(x = year_n, y = rank, color = country_en)
                ) +
                    ggbump::geom_bump(linewidth = 1.0, show.legend = FALSE) +
                    ggplot2::geom_point(ggplot2::aes(text = hover_text), size = 5)) +
                    ggplot2::theme_bw() +
                    ggplot2::scale_y_reverse(breaks = ggplot2::waiver(), n.breaks = 25) +
                    ggplot2::scale_x_continuous(
                        breaks = seq(min(df_ordered$year_n), max(df_ordered$year_n), by = 2)
                    ) +
                    ggplot2::scale_colour_manual(values = col) +
                    ggplot2::labs(color = "Country") +
                    ggplot2::xlab("Year") +
                    ggplot2::ylab("Rank")

                p_final <- plotly::ggplotly(p, tooltip = "text", source = ns("plot")) |>
                    plotly::layout(
                        font = list(size = 18),
                        # Legend font size matched to the score chart's
                        # legend (see the score branch below) for visual
                        # consistency between the two Trends chart types.
                        legend = list(font = list(size = 14)),
                        dragmode = FALSE
                    )

                # geom_bump()'s line layer has no `text` aes, so ggplotly()
                # would otherwise show an empty/NA hover box when hovering
                # the connecting curve between two yearly points. Silence
                # hover on line-mode traces entirely; the point traces (with
                # the real tooltip) are unaffected.
                line_traces <- which(vapply(
                    p_final$x$data,
                    function(tr) identical(tr$mode, "lines"),
                    logical(1)
                ))
                if (length(line_traces) > 0) {
                    p_final <- plotly::style(p_final, hoverinfo = "none", traces = line_traces)
                }

                # ggbump()'s smoothed curve and geom_point()'s markers land
                # in two separate traces per country (a "lines"-mode trace
                # and a "markers"-mode trace) — an unavoidable consequence
                # of mapping two different geoms to the same color. Left
                # alone, ggplotly() puts the surviving legend swatch on the
                # "lines" trace (see the block comment above), so the
                # bump chart's legend showed a line only, while the score
                # chart's single "lines+markers" trace shows a combined
                # line+point swatch — an inconsistency, and the two
                # traces per country turned out to have a second effect:
                # our hover-dimming JS (below) was keying off curveNumber,
                # so hovering the marker trace dimmed that same country's
                # line trace (and vice versa), producing a visible flicker
                # whenever the mouse tracked the curve between exact data
                # points.
                #
                # Both are fixed by decoupling the legend from the real
                # traces entirely: hide the legend on the real "lines"/
                # "markers" traces, and add one invisible (empty x/y)
                # "lines+markers" proxy trace per country whose only job is
                # to supply the legend swatch, sized/styled to match the
                # score chart's real marker/line (size = 20, width = 4).
                # The hover-dimming fix (grouping by trace name rather than
                # curveNumber) lives in the shared onRender script below.
                p_final <- plotly::style(
                    p_final,
                    showlegend = FALSE,
                    traces = seq_along(p_final$x$data)
                )
                # A single out-of-range scalar point, not an empty vector:
                # plotly_build() was found (empirically) to silently corrupt
                # add_trace()'s x/y into the literal strings "x"/"y" when
                # given numeric(0) — the resulting trace still built without
                # error, but rendered with no legend entry at all. A scalar
                # NA point has the opposite problem (verified separately):
                # plot_ly()'s trace-building drops it, along with its name/
                # legendgroup, since it looks like "no data was mapped". A
                # real but far-outside-range point avoids both: ggplotly()
                # already fixes this chart's axis ranges explicitly
                # (autorange = FALSE, confirmed via p_final$x$layout), so
                # the sentinel point is simply clipped off-canvas and can't
                # perturb the visible range or autorange.
                for (cn in country_order) {
                    p_final <- plotly::add_trace(
                        p_final,
                        x = -1e6, y = -1e6,
                        type = "scatter", mode = "lines+markers",
                        line = list(color = col[[cn]], width = 4),
                        marker = list(color = col[[cn]], size = 20),
                        name = cn,
                        legendgroup = cn,
                        showlegend = TRUE,
                        hoverinfo = "skip",
                        inherit = FALSE
                    )
                }
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
                        country_en = factor(country_en, levels = country_order),
                        hover_text = paste0(
                            flag_emoji(iso), " ", country_en,
                            "<br>Year: ", year_n,
                            "<br>Score: ", score
                        )
                    )

                # Line chart for score
                p_final <- plotly::plot_ly(
                    data      = df_ordered,
                    x         = ~year_n,
                    y         = as.formula(paste0("~", var())),
                    color     = ~country_en,
                    colors    = col,
                    type      = "scatter",
                    mode      = "lines+markers",
                    line      = list(width = 4),
                    marker    = list(size = 20),
                    text      = ~hover_text,
                    hoverinfo = "text",
                    source    = ns("plot")
                ) |>
                    plotly::layout(
                        font  = list(size = 18),
                        xaxis = list(title = "Year"),
                        yaxis = list(title = "Score"),
                        # plotly.js only auto-shows a legend when there's
                        # more than one trace, so force it on for the
                        # single-country case too. Legend font is set
                        # smaller than the main plot font (18) — matched to
                        # the rank chart's legend for visual consistency
                        # between the two Trends chart types.
                        showlegend = TRUE,
                        legend = list(title = list(text = "Country"), font = list(size = 14)),
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

                        // Hover: dim all traces except the hovered
                        // country's. Grouped by trace *name* (the country),
                        // not curveNumber — the rank/bump chart splits each
                        // country across two real traces (a 'lines' trace
                        // from geom_bump() and a 'markers' trace from
                        // geom_point()) plus one invisible legend-only proxy
                        // trace (see the rank branch above), so dimming by
                        // curveNumber alone would dim a country's line
                        // while its markers stayed highlighted (or vice
                        // versa) depending on which sub-trace the mouse was
                        // nearest to, producing a visible flicker. Matching
                        // by name keeps every trace belonging to the
                        // hovered country at full opacity together.
                        el.on('plotly_hover', function(data) {
                            var hoveredName = el.data[data.points[0].curveNumber].name;
                            var opacities = [];
                            for (var i = 0; i < nTraces; i++) {
                                opacities.push(el.data[i].name === hoveredName ? 1 : 0.15);
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
