## inst/app/R/mod_country.R
## Country profile module (redesigned per decision #4 and the
## Explanatory-factors resolution in the WHR-redesign plan).
##
## countrySidebarUI() — country selector + clear button (unchanged)
## countryMainUI()    — flag/name header, rank + score stat blocks, a
##                       compact embedded Trends chart, and a small
##                       2022-2025 Explanatory Factors chart
## countryServer()     — computes the stat blocks and factors chart;
##                        embeds chartServer() (mod_chart.R) in compact
##                        mode for the long-run Score view
##
## Rank block: current / highest / lowest / median / biggest climb /
## biggest fall. "Highest"/"Lowest" refer to ranking quality, not raw
## magnitude, so lower numeric rank is "Highest". Score block uses the
## same six-row shape but with the literal numeric max/min for
## "Highest"/"Lowest" and mean (not median) for the central tendency,
## since rank is ordinal and score is a continuous composite (decision
## #4). Both use `rank_evolution`/`score_evolution` for the climb/fall
## rows; both are signed with positive = improved (see R/data.R), so
## "biggest climb"/"biggest gain" is simply the max, no sign-flipping.

# Format a stat value: whole numbers show no decimals, fractional ones
# (e.g. a rank median, or any score) show one. `sign = TRUE` prefixes a
# "+" for positive values, used for the climb/fall/gain/drop rows.
fmt_val <- function(x, sign = FALSE) {
  if (is.na(x)) return("\u2013")
  digits <- if (isTRUE(x == round(x))) 0 else 1
  s <- formatC(round(x, digits), format = "f", digits = digits)
  if (sign && x > 0) s <- paste0("+", s)
  s
}

# One label/value(/year) row for a stat block.
stat_row <- function(label, value, year = NULL, sign = FALSE) {
  shiny::div(
    style = paste(
      "display: flex; justify-content: space-between; align-items: baseline;",
      "padding: 4px 0; border-bottom: 1px solid #f1f1f1; font-size: 0.92rem;"
    ),
    shiny::span(label, style = "color: #6c757d;"),
    shiny::span(
      shiny::strong(fmt_val(value, sign = sign)),
      if (!is.null(year) && !is.na(year)) {
        shiny::span(paste0(" (", year, ")"), style = "color: #adb5bd; font-size: 0.82rem;")
      }
    )
  )
}

# Current / best / worst / climb / fall for one metric column, for a
# single country's data (already filtered to one country; all years).
# `direction` decides which raw extreme counts as "best": for rank,
# numerically lower is better ("lower_better"); for score, numerically
# higher is better ("higher_better").
country_block_stats <- function(df, value_col, evolution_col,
                                 direction = c("higher_better", "lower_better")) {
  direction <- match.arg(direction)
  dv <- df |> dplyr::filter(!is.na(.data[[value_col]]))
  ev <- df |> dplyr::filter(!is.na(.data[[evolution_col]]))

  current <- dv |> dplyr::filter(year_n == max(year_n))

  if (direction == "higher_better") {
    best  <- dv |> dplyr::slice_max(.data[[value_col]], n = 1, with_ties = FALSE)
    worst <- dv |> dplyr::slice_min(.data[[value_col]], n = 1, with_ties = FALSE)
  } else {
    best  <- dv |> dplyr::slice_min(.data[[value_col]], n = 1, with_ties = FALSE)
    worst <- dv |> dplyr::slice_max(.data[[value_col]], n = 1, with_ties = FALSE)
  }

  climb <- if (nrow(ev) > 0) ev |> dplyr::slice_max(.data[[evolution_col]], n = 1, with_ties = FALSE)
  fall  <- if (nrow(ev) > 0) ev |> dplyr::slice_min(.data[[evolution_col]], n = 1, with_ties = FALSE)

  list(
    current      = current[[value_col]][1],
    current_year = current$year_n[1],
    best         = best[[value_col]][1],
    best_year    = best$year_n[1],
    worst        = worst[[value_col]][1],
    worst_year   = worst$year_n[1],
    climb        = if (is.null(climb) || nrow(climb) == 0) NA_real_ else climb[[evolution_col]][1],
    climb_year   = if (is.null(climb) || nrow(climb) == 0) NA_integer_ else climb$year_n[1],
    fall         = if (is.null(fall) || nrow(fall) == 0) NA_real_ else fall[[evolution_col]][1],
    fall_year    = if (is.null(fall) || nrow(fall) == 0) NA_integer_ else fall$year_n[1]
  )
}

no_data_msg <- function(msg) {
  shiny::p(msg, style = "color: #6c757d; font-size: 0.9rem; margin: 0.5rem 0;")
}

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
        shiny::uiOutput(ns("body"))
    )
}

countryServer <- function(id, rwb) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        shiny::observeEvent(input$clear, {
            shiny::updateSelectInput(session, "country", selected = "")
        })

        selected <- shiny::reactive(input$country)

        # This country's full history (all years, every column) — the
        # single source the stat blocks and the factors chart both
        # filter further from.
        country_data <- shiny::reactive({
            shiny::req(selected(), selected() != "")
            rwb |>
                dplyr::filter(country_en == selected()) |>
                dplyr::arrange(year_n)
        })

        output$country_header <- shiny::renderUI({
            shiny::req(selected(), selected() != "")
            row <- country_data()[1, ]
            shiny::tags$h3(
                flag_img_tag(row$iso, alt = selected(), height = "1.1em"),
                selected(),
                class = "mb-0"
            )
        })

        output$body <- shiny::renderUI({
            if (is.null(selected()) || selected() == "") {
                return(shiny::div(
                    style = paste(
                        "display: flex; align-items: center; justify-content: center;",
                        "height: calc(100vh - 155px); color: #6c757d;"
                    ),
                    shiny::p("Select a country to view its profile.")
                ))
            }

            shiny::div(
                style = paste(
                    "height: calc(100vh - 155px); display: flex;",
                    "flex-direction: column; gap: 12px;"
                ),
                shiny::div(
                    style = "flex: 3 1 0; min-height: 0; display: flex; gap: 12px;",
                    shiny::div(
                        style = paste(
                            "flex: 0 0 320px; min-height: 0; display: flex;",
                            "flex-direction: column; gap: 12px;"
                        ),
                        bslib::card(
                            style = "flex: 1;",
                            bslib::card_header("Rank"),
                            shiny::uiOutput(ns("rank_stats"))
                        ),
                        bslib::card(
                            style = "flex: 1;",
                            bslib::card_header("Score"),
                            shiny::uiOutput(ns("score_stats"))
                        )
                    ),
                    shiny::div(
                        style = "flex: 1; min-height: 0;",
                        chartUI(ns("trend"), height = "100%")
                    )
                ),
                shiny::div(
                    style = "flex: 2 1 0; min-height: 0;",
                    bslib::card(
                        height = "100%",
                        bslib::card_header("Explanatory factors, 2022\u20132025"),
                        shiny::uiOutput(ns("factors_plot_or_placeholder"))
                    )
                )
            )
        })

        output$rank_stats <- shiny::renderUI({
            d <- country_data()
            rd <- d |> dplyr::filter(!is.na(rank))
            if (nrow(rd) == 0) return(no_data_msg("No rank data available."))

            st <- country_block_stats(d, "rank", "rank_evolution", direction = "lower_better")
            shiny::tagList(
                stat_row("Current", st$current, st$current_year),
                stat_row("Highest", st$best, st$best_year),
                stat_row("Lowest", st$worst, st$worst_year),
                stat_row("Median", stats::median(rd$rank, na.rm = TRUE)),
                stat_row("Biggest climb", st$climb, st$climb_year, sign = TRUE),
                stat_row("Biggest fall", st$fall, st$fall_year, sign = TRUE)
            )
        })

        output$score_stats <- shiny::renderUI({
            d <- country_data()
            scored_rows <- d |> dplyr::filter(!is.na(score))
            if (nrow(scored_rows) == 0) return(no_data_msg("No score data available."))

            # RSF changed its scoring methodology in 2013, so score_evolution
            # (score - score_n_1) compares two incompatible scales for that
            # one year, producing artifacts as large as +5,763 across the
            # dataset that aren't real year-over-year changes. rank_evolution
            # is unaffected (rank is a same-year relative ordering both
            # years). Excluded here, scoped to this stat block only.
            d_evol <- d |>
                dplyr::mutate(
                    score_evolution = dplyr::if_else(
                        year_n == 2013, NA_real_, score_evolution
                    )
                )
            st <- country_block_stats(d_evol, "score", "score_evolution", direction = "higher_better")
            shiny::tagList(
                stat_row("Current", st$current, st$current_year),
                stat_row("Highest", st$best, st$best_year),
                stat_row("Lowest", st$worst, st$worst_year),
                stat_row("Mean", mean(scored_rows$score, na.rm = TRUE)),
                stat_row("Biggest gain", st$climb, st$climb_year, sign = TRUE),
                stat_row("Biggest drop", st$fall, st$fall_year, sign = TRUE)
            )
        })

        # Compact embedded Trends chart (mod_chart.R), fixed to Score and
        # this one country — literally the same component used for
        # multi-country comparison, just reused with a single country
        # and a smaller height. `show_nav = FALSE` hides the popover's
        # "Go to Country view" button, which would be a no-op here.
        chartServer(
            "trend", rwb,
            var     = shiny::reactive("score"),
            country = shiny::reactive(if (is.null(selected()) || selected() == "") character(0) else selected()),
            show_nav = FALSE
        )

        # Explanatory Factors: one line per dimension, 2022-2025 only —
        # a distinct component from the Trends chart (its own short
        # x-axis, single country), not a reuse of it. See AGENTS.md /
        # the redesign plan for why dimensions are scoped this way
        # rather than sharing the 2002-2025 axis.
        factors_data <- shiny::reactive({
            d <- country_data() |> dplyr::filter(year_n >= 2022)
            dplyr::bind_rows(lapply(map_dimension_vars, function(v) {
                d |>
                    dplyr::transmute(
                        year_n,
                        dimension = map_metric_labels[[v]],
                        value = .data[[v]]
                    )
            })) |>
                dplyr::filter(!is.na(value))
        })

        output$factors_plot_or_placeholder <- shiny::renderUI({
            if (nrow(factors_data()) == 0) {
                return(no_data_msg("No explanatory factor data available (2022\u20132025)."))
            }
            plotly::plotlyOutput(ns("factors_plot"), height = "100%")
        })

        output$factors_plot <- plotly::renderPlotly({
            fd <- factors_data()
            shiny::req(nrow(fd) > 0)

            dims <- unname(map_metric_labels[map_dimension_vars])
            cols <- stats::setNames(RColorBrewer::brewer.pal(5, "Set2"), dims)

            plotly::plot_ly(
                data   = fd,
                x      = ~year_n,
                y      = ~value,
                color  = ~dimension,
                colors = cols,
                type   = "scatter",
                mode   = "lines+markers",
                line   = list(width = 3),
                marker = list(size = 9)
            ) |>
                plotly::layout(
                    xaxis  = list(title = "Year", dtick = 1),
                    yaxis  = list(title = "Score (0\u2013100)", range = c(0, 100)),
                    legend = list(orientation = "h", y = -0.25)
                )
        })
    })
}
