## inst/app/R/mod_country.R
## Country profile module (redesigned per
## .posit/assistant/plans/2026-07-16-1923-country-page-redesign.md).
##
## countrySidebarUI() — country selector + clear button (unchanged)
## countryMainUI()    — flag/name header; an overview card (horizontal
##                       Rank/Score stat table + score-band/rank-tier
##                       count bar charts); and a trend row with two
##                       combined charts — Score (+ dimensions) and
##                       Rank (+ dimension ranks) — sharing one
##                       deduplicated floating legend
## countryServer()     — computes the stat table, the band/tier bar
##                        charts, and the two combined trend charts
##                        (bespoke plot_ly()/ggbump code, not a reuse
##                        of chartServer() — see mod_country.R's trend
##                        section and AGENTS.md for why)
##
## Stat table: one row per metric (Rank, Score), columns = Current /
## Best / Worst / Median-or-Mean / Biggest improvement / Biggest
## decline. "Best"/"Worst" mean ranking quality for Rank (lower is
## better) and literal numeric max/min for Score (higher is better).
## Median is used for Rank (ordinal), mean for Score (continuous
## composite) — see decision #4. Both use `rank_evolution`/
## `score_evolution` for the improvement/decline columns; both are
## signed with positive = improved (see R/data.R), so "biggest
## improvement" is simply the max, no sign-flipping.

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

# One <td> cell: a formatted stat value plus an optional small "(year)"
# annotation, matching the old stat_row()'s value styling but laid out
# horizontally in a table instead of stacked rows.
stat_cell <- function(value, year = NULL, sign = FALSE) {
  shiny::tags$td(
    shiny::strong(fmt_val(value, sign = sign)),
    if (!is.null(year) && !is.na(year)) {
      shiny::span(paste0(" (", year, ")"), style = "color: #adb5bd; font-size: 0.78em;")
    }
  )
}

# Combined Rank/Score stat table: one row per metric, columns = Current /
# Best / Worst / Median-or-Mean / Biggest improvement / Biggest decline.
# `rank_st`/`score_st` are `country_block_stats()` lists, or NULL if that
# metric has no data at all for this country (e.g. a defunct historical
# state with rank-only history) — in which case the row falls back to an
# all-NA stats list so every cell renders as "\u2013" rather than erroring.
stat_table <- function(rank_st, score_st, rank_central, score_central) {
  empty_st <- list(
    current = NA, current_year = NA, best = NA, best_year = NA,
    worst = NA, worst_year = NA, climb = NA, climb_year = NA,
    fall = NA, fall_year = NA
  )
  if (is.null(rank_st))  rank_st  <- empty_st
  if (is.null(score_st)) score_st <- empty_st

  stat_row_tr <- function(label, st, central) {
    shiny::tags$tr(
      shiny::tags$td(shiny::strong(label)),
      stat_cell(st$current, st$current_year),
      stat_cell(st$best, st$best_year),
      stat_cell(st$worst, st$worst_year),
      stat_cell(central),
      stat_cell(st$climb, st$climb_year, sign = TRUE),
      stat_cell(st$fall, st$fall_year, sign = TRUE)
    )
  }

  shiny::tags$table(
    class = "table table-sm mb-1",
    # table-layout: fixed makes `width: 100%` a hard cap rather than a
    # suggestion — with the default `auto` layout, a browser lets a
    # table's *rendered* width exceed a declared 100% whenever a
    # column's content can't shrink below its natural minimum, which
    # is exactly what let this table bleed out from under the
    # score-band/rank-tier charts to its right at intermediate
    # container widths (roughly 700-990px) before the Overview row's
    # own stacking breakpoint kicked in. But with columns forced to
    # divide evenly regardless of content, shrinking *too* far starts
    # breaking single words mid-character ("Curre-nt") since there's
    # no space to wrap at instead — min-width: 300px keeps every
    # column wide enough to avoid that, and the surrounding div's
    # overflow-x: auto (see the "country-overview-stats" div above)
    # gives the table its own scrollbar rather than overflowing onto
    # its siblings once the container is narrower than that.
    style = "font-size: 0.78rem; width: 100%; min-width: 300px; table-layout: fixed;",
    shiny::tags$thead(
      shiny::tags$tr(
        shiny::tags$th(""),
        shiny::tags$th("Current"),
        shiny::tags$th("Best"),
        shiny::tags$th("Worst"),
        shiny::tags$th(shiny::HTML("Mean/<br>Median<sup>*</sup>")),
        shiny::tags$th(shiny::HTML("Biggest<br>advance")),
        shiny::tags$th(shiny::HTML("Biggest<br>decline"))
      )
    ),
    shiny::tags$tbody(
      stat_row_tr("Score", score_st, score_central),
      stat_row_tr("Rank", rank_st, rank_central)
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
    # This outer div is itself the width probe (a ResizeObserver on it,
    # wired up in app.R's header script, feeds the *actual available
    # width* to countryServer(), which is what the trend chart's
    # subplot layout should react to — deliberately NOT
    # window.innerWidth: that measure is off by however much the
    # sidebar happens to be taking up, so it was reporting "plenty of
    # room" even while the content pane was already squeezed down to
    # sidebar-open width). Doubling as the probe (rather than a
    # separate 1px sibling) also means it's the sole child of bslib's
    # nav_panel content pane, so none of that pane's own inter-child
    # gap (24px, applied twice with a 3-way split) is spent on
    # whitespace the user never asked for — the header/body gap below
    # is instead a deliberate, much smaller 8px we control directly.
    # `flex: 1 1 auto` (rather than a fixed height) lets it fill
    # whatever height the fillable page layout actually gives the tab
    # pane, so there's no separate magic-number height calc to keep in
    # sync with header/padding changes elsewhere.
    shiny::div(
        id = ns("width_probe"),
        style = "flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; gap: 8px;",
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

        # Only the *side of the breakpoint* matters for the trend
        # chart's layout, not the exact width — reactiveVal only
        # invalidates its subscribers when the new value differs from
        # the old one (identical() under the hood), so this collapses
        # every resize tick into a single re-plot at the moment the
        # breakpoint is actually crossed, instead of re-plotting on
        # every tick while dragging a window edge. 700px is the same
        # number used by the matching `@container` CSS rule in app.R
        # (see the "country-body" container there) — keep them in sync
        # if you retune the breakpoint.
        narrow <- shiny::reactiveVal(FALSE)
        shiny::observeEvent(input$width_probe_val, {
            narrow(input$width_probe_val < 700)
        }, ignoreNULL = TRUE)

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
            flag <- flag_img_tag(row$iso, alt = selected(), height = "1.1em")
            shiny::tags$h3(
                flag,
                selected(),
                class = "mb-0"
            )
        })

        output$body <- shiny::renderUI({
            if (is.null(selected()) || selected() == "") {
                return(shiny::div(
                    style = paste(
                        "display: flex; align-items: center; justify-content: center;",
                        "flex: 1 1 auto; min-height: 0; color: #6c757d;"
                    ),
                    shiny::p("Select a country to view its profile.")
                ))
            }

            shiny::div(
                # flex: 1 1 auto (not a fixed height) — this div is the
                # sole other flex child of countryMainUI()'s outer
                # wrapper (alongside the h3 header above it), so it
                # simply claims whatever's left after the header's own
                # height, in whatever the fillable page layout actually
                # gives the tab pane. A small padding gives the cards'
                # box-shadow (their only visible "border" — see the
                # bslib .card CSS, which sets border-color to
                # transparent and relies on box-shadow instead) room to
                # render on all four sides; without it, this div's own
                # edges (flush against the first/last card) clipped the
                # shadow via the overflow-y: auto below, leaving the
                # overview card's top/left and the trend card's
                # bottom/left looking borderless.
                #
                # scrollbar-gutter: stable reserves the scrollbar's width
                # whether or not it's actually showing, so its
                # appearance/disappearance (as content height crosses
                # the container's height) doesn't itself change the
                # available width — without this, that width change fed
                # back into Plotly's responsive resize, which fed back
                # into the content height, producing a slow-oscillating
                # resize loop lasting several seconds.
                # container-type/-name turn this div into a CSS
                # "query container" — the @container rules in app.R's
                # header (rather than @media on the viewport) key off
                # *this* element's own width, so they always agree with
                # the width_probe_val-driven `narrow` reactive above,
                # which measures the same content pane via JS.
                style = paste(
                    "flex: 1 1 auto; min-height: 0; display: flex;",
                    "flex-direction: column; gap: 12px; overflow-y: auto;",
                    "scrollbar-gutter: stable; padding: 6px;",
                    "container-type: inline-size; container-name: country-body;"
                ),
                # Overview row: stat table (left ~50%) + two band/tier count
                # bar charts (right ~50%, split ~25/25), squeezed to line up
                # with the table's footnote row (~1/3 of the earlier height).
                shiny::div(
                    style = "flex: 0 0 auto; min-height: 0;",
                    bslib::card(
                        bslib::card_header("Overview"),
                        # fillable = FALSE: keeps this section in normal
                        # block flow rather than bslib's flexbox "fill"
                        # layout. Not what actually fixes the bar charts'
                        # height (see band_bar_chart() below for that) —
                        # kept because this content is naturally
                        # content-sized (a table + two small charts), not
                        # meant to stretch/shrink with the card.
                        bslib::card_body(
                            fillable = FALSE,
                            padding = c("0.75rem", "1rem", "0.25rem", "1rem"),
                            shiny::div(
                                class = "country-overview-row",
                                style = "display: flex; gap: 12px; align-items: flex-start;",
                                shiny::div(
                                    class = "country-overview-stats",
                                    # min-width: 0 (rather than the
                                    # table's own natural minimum) lets
                                    # this flex item keep shrinking
                                    # past that point; overflow-x: auto
                                    # on *this* box is what actually
                                    # catches the difference once the
                                    # table (min-width: 300px, see
                                    # stat_table()) can't shrink
                                    # further, giving the table its own
                                    # small horizontal scrollbar
                                    # instead of bleeding into the
                                    # score-band/rank-tier charts to
                                    # its right.
                                    style = "flex: 1 1 50%; min-width: 0; overflow-x: auto;",
                                    shiny::uiOutput(ns("stat_table")),
                                    shiny::p(
                                        "* Mean for Score (continuous); Median for Rank (ordinal).",
                                        class = "text-muted",
                                        style = "font-size: 0.72rem; margin: 0;"
                                    )
                                ),
                                shiny::div(
                                    class = "country-overview-chart",
                                    style = "flex: 1 1 25%; min-width: 0; height: 200px;",
                                    shiny::uiOutput(ns("score_band_plot_or_placeholder"))
                                ),
                                shiny::div(
                                    class = "country-overview-chart",
                                    style = "flex: 1 1 25%; min-width: 0; height: 200px;",
                                    shiny::uiOutput(ns("rank_tier_plot_or_placeholder"))
                                )
                            )
                        )
                    )
                ),
                # Trend row: one card holding the combined Score(+dimensions)
                # / Rank(+dimension ranks) charts, merged via plotly::subplot()
                # with a single deduplicated floating legend (see
                # trend_plot_or_placeholder / trend_plot below).
                shiny::div(
                    class = "country-trend-wrapper",
                    # min-height: 420px is a floor, not a fixed size —
                    # flex-grow still lets this wrapper claim any extra
                    # room beyond the overview card on tall windows.
                    # Below 420px the two trend panels' x-axis title and
                    # bottom legend start crowding each other (Plotly
                    # reserves a fixed pixel margin for both regardless
                    # of how little total height it's given), so past
                    # this point the page scrolls (see the body div's
                    # own overflow-y: auto) instead of the charts
                    # shrinking into illegibility.
                    style = "flex: 1 1 0; min-height: 420px;",
                    bslib::card(
                        height = "100%",
                        bslib::card_header("Score & Rank trends (with explanatory factors, 2022\u20132025)"),
                        shiny::uiOutput(ns("trend_plot_or_placeholder"))
                    )
                )
            )
        })

        output$stat_table <- shiny::renderUI({
            d <- country_data()
            rd <- d |> dplyr::filter(!is.na(rank))
            scored_rows <- d |> dplyr::filter(!is.na(score))

            rank_st <- if (nrow(rd) > 0) {
                country_block_stats(d, "rank", "rank_evolution", direction = "lower_better")
            } else {
                NULL
            }
            rank_central <- if (nrow(rd) > 0) stats::median(rd$rank, na.rm = TRUE) else NA_real_

            # RSF changed its scoring methodology in 2013, so score_evolution
            # (score - score_n_1) compares two incompatible scales for that
            # one year, producing artifacts as large as +5,763 across the
            # dataset that aren't real year-over-year changes. rank_evolution
            # is unaffected (rank is a same-year relative ordering both
            # years). Excluded here, scoped to this stat table only.
            d_evol <- d |>
                dplyr::mutate(
                    score_evolution = dplyr::if_else(
                        year_n == 2013, NA_real_, score_evolution
                    )
                )
            score_st <- if (nrow(scored_rows) > 0) {
                country_block_stats(d_evol, "score", "score_evolution", direction = "higher_better")
            } else {
                NULL
            }
            score_central <- if (nrow(scored_rows) > 0) mean(scored_rows$score, na.rm = TRUE) else NA_real_

            stat_table(rank_st, score_st, rank_central, score_central)
        })

        # Score band counts: every year with a non-NA score (2013+),
        # classified via rsf_band() (from mod_map.R, best-\u2192worst order).
        score_band_data <- shiny::reactive({
            d <- country_data() |> dplyr::filter(!is.na(score))
            counts <- d |>
                dplyr::mutate(band = factor(rsf_band(score), levels = rsf_band_levels)) |>
                dplyr::count(band, .drop = FALSE)
            dplyr::tibble(band = factor(rsf_band_levels, levels = rsf_band_levels)) |>
                dplyr::left_join(counts, by = "band") |>
                dplyr::mutate(n = dplyr::coalesce(n, 0L))
        })

        # Rank tier counts: every year with a non-NA rank, classified via
        # rank_tier() using that year's own max_rank (total countries
        # surveyed varies by year, so tiers aren't comparable against a
        # single global max).
        rank_tier_data <- shiny::reactive({
            d <- country_data() |> dplyr::filter(!is.na(rank))
            max_ranks <- rwb |>
                dplyr::group_by(year_n) |>
                dplyr::summarise(max_rank = max(rank, na.rm = TRUE), .groups = "drop")
            counts <- d |>
                dplyr::left_join(max_ranks, by = "year_n") |>
                dplyr::mutate(tier = factor(rank_tier(rank, max_rank), levels = rank_tier_levels)) |>
                dplyr::count(tier, .drop = FALSE)
            dplyr::tibble(tier = factor(rank_tier_levels, levels = rank_tier_levels)) |>
                dplyr::left_join(counts, by = "tier") |>
                dplyr::mutate(n = dplyr::coalesce(n, 0L))
        })

        # Small horizontal-category bar chart shared by both band/tier
        # charts: x = the 5 ordered levels, y = year count, bar color
        # matching the map's band/tier palette; no legend (color already
        # encodes the same x-axis category).
        #
        # Height is passed directly to plot_ly()'s own `height` argument
        # (baked into the figure's layout), not just as CSS on the
        # surrounding <div> (via plotlyOutput()/htmlwidgets sizing). CSS
        # height alone didn't stick: bslib/htmlwidgets' "fill" behavior
        # (the `html-fill-item`/`html-fill-container` classes plotly
        # widgets and card_body() pick up) recomputes the widget's size
        # from its container at render time, ignoring the inline height
        # we set on the wrapper. Setting `height` on plot_ly() itself
        # fixes the figure's pixel size unconditionally, independent of
        # whatever the container resolves to.
        BAR_CHART_HEIGHT <- 200

        band_bar_chart <- function(df, cat_col, colors, title) {
            levels_ <- levels(df[[cat_col]])
            plotly::plot_ly(
                data   = df,
                x      = df[[cat_col]],
                y      = ~n,
                type   = "bar",
                marker = list(color = colors[as.character(df[[cat_col]])]),
                height = BAR_CHART_HEIGHT
            ) |>
                plotly::layout(
                    title  = list(text = paste0("<b>", title, "</b>"), font = list(size = 15), y = 0.98),
                    xaxis  = list(title = "", categoryorder = "array", categoryarray = levels_, tickfont = list(size = 10)),
                    yaxis  = list(title = "Occurrences", titlefont = list(size = 11), tickfont = list(size = 10)),
                    margin = list(t = 34, b = 60, l = 40, r = 10),
                    showlegend = FALSE
                ) |>
                plotly::config(displayModeBar = FALSE) |>
                # plotly's tickfont/titlefont don't expose a `weight`
                # property, so bold axis text is applied directly to the
                # rendered SVG <text> elements post-draw (font-weight is
                # a valid SVG/CSS style, just not a plot_ly() layout arg).
                htmlwidgets::onRender("
                    function(el, x) {
                        el.querySelectorAll(
                            '.xtick text, .ytick text, .xtitle, .ytitle'
                        ).forEach(function(t) { t.style.fontWeight = 'bold'; });
                    }
                ")
        }

        output$score_band_plot_or_placeholder <- shiny::renderUI({
            if (sum(score_band_data()$n) == 0) {
                return(no_data_msg("No score data available."))
            }
            plotly::plotlyOutput(ns("score_band_plot"), height = paste0(BAR_CHART_HEIGHT, "px"))
        })

        output$score_band_plot <- plotly::renderPlotly({
            band_bar_chart(score_band_data(), "band", rsf_band_colors, "Score bands")
        })

        output$rank_tier_plot_or_placeholder <- shiny::renderUI({
            if (sum(rank_tier_data()$n) == 0) {
                return(no_data_msg("No rank data available."))
            }
            plotly::plotlyOutput(ns("rank_tier_plot"), height = paste0(BAR_CHART_HEIGHT, "px"))
        })

        output$rank_tier_plot <- plotly::renderPlotly({
            band_bar_chart(rank_tier_data(), "tier", rank_tier_colors, "Rank tiers")
        })

        # --- Combined trend charts -----------------------------------
        #
        # Two bespoke charts, local to this module (not a reuse of
        # chartServer()/mod_chart.R — that shared Trends component is
        # deliberately scoped to Score/Rank only, dimensions excluded;
        # see AGENTS.md's "Dimension data (2022+): per-view treatment"):
        #
        #   Score panel: black Score line (2013+, its natural start),
        #     plus 5 thin dimension lines (2022-2025 only, naturally,
        #     since that's all the data that exists for them).
        #   Rank panel: black Rank bump line (~2003-2025), plus 5 thin
        #     dimension-rank bump lines (rank_pol etc., already in rwb
        #     — no need to recompute), built with ggplot2 + ggbump and
        #     converted via ggplotly() (same technique as mod_chart.R's
        #     Rank bump chart).
        #
        # Merged into one widget via plotly::subplot() (1:2 width split,
        # matching each panel's natural x-axis span: 13 years vs. ~23).
        # The 5 dimension colors would otherwise appear twice (once per
        # panel); each dimension trace in both panels shares a
        # `legendgroup` keyed on its label, with `showlegend` turned on
        # only in the score panel's copy — plotly.js still toggles both
        # traces together on legend click because they share a group,
        # so the dedup doesn't cost the toggle behavior. "Score" and
        # "Rank" each stay as their own single legend entry (only ever
        # drawn once, in their own panel).
        rank_dim_map <- c(
            rank_pol = "Political Context", rank_eco = "Economic Context",
            rank_leg = "Legal Context", rank_soc = "Social Context",
            rank_saf = "Safety"
        )
        trend_dim_labels <- unname(map_metric_labels[map_dimension_vars])
        trend_dim_colors <- stats::setNames(
            RColorBrewer::brewer.pal(5, "Set2"), trend_dim_labels
        )

        # Every trace whose `name` is a dimension label gets a shared
        # legendgroup and `show_dims` controls whether its legend entry
        # is drawn in *this* panel. "Score" is relabelled to
        # "Score/Rank" and kept as the sole legend entry for both black
        # lines — "Rank" is functionally the same series (just plotted
        # on the other panel's axis), so its own legend entry is
        # dropped entirely rather than shown twice.
        dedup_legend <- function(built, show_dims) {
            built$x$data <- lapply(built$x$data, function(tr) {
                nm <- tr$name
                if (!is.null(nm)) {
                    if (nm %in% trend_dim_labels) {
                        tr$legendgroup <- nm
                        tr$showlegend <- show_dims
                    } else if (nm == "Score") {
                        tr$name <- "Score/Rank"
                        tr$legendgroup <- "Score/Rank"
                        tr$showlegend <- TRUE
                    } else if (nm == "Rank") {
                        # ggplotly() may produce more than one "Rank"
                        # trace (e.g. a line trace and a point trace);
                        # all of them lose their legend entry here.
                        tr$legendgroup <- "Score/Rank"
                        tr$showlegend <- FALSE
                    }
                }
                tr
            })
            built
        }

        # Forces matching axis tick/title font sizes AND a matching
        # panel border on both panels after building. Font sizes need
        # this because the score panel (plot_ly(), unset ->
        # browser/Plotly.js default ~12px) and the rank panel (ggplot2
        # -> ggplotly(), theme_bw()'s default -> ~11.7px) come from two
        # different font-size conventions that don't produce visually
        # matching sizes on their own. The border needs it for the same
        # reason: plot_ly() draws no panel border by default, while
        # ggplot2's theme_bw() does (a call to which used to leave the
        # two panels visibly inconsistent side by side) — showline +
        # mirror draws the same 4-sided box on *both* panels from one
        # shared code path instead, so they're guaranteed to match
        # exactly rather than relying on two independent
        # border-drawing mechanisms staying in visual sync by luck.
        set_axis_font <- function(built, tick_size = 13, title_size = 14) {
            for (ax in c("xaxis", "yaxis")) {
                a <- built$x$layout[[ax]]
                if (is.null(a)) a <- list()
                a$tickfont <- list(size = tick_size)
                a$showline <- TRUE
                a$mirror <- TRUE
                a$linecolor <- "#333333"
                a$linewidth <- 1
                # An axis with no title at all (e.g. the untitled
                # plotly_empty() placeholder used for a country with no
                # data at all) must stay untouched here — wrapping a
                # NULL title in list(text = NULL, ...) breaks
                # plotly::subplot()'s later attribute verification with
                # "attempt to set an attribute on NULL".
                if (!is.null(a$title)) {
                    if (is.list(a$title)) {
                        a$title$font <- list(size = title_size)
                    } else {
                        a$title <- list(text = a$title, font = list(size = title_size))
                    }
                }
                built$x$layout[[ax]] <- a
            }
            built
        }

        score_trend_plot <- function(d) {
            has_any_score_data <- any(!is.na(d$score)) ||
                any(vapply(map_dimension_vars, function(v) any(!is.na(d[[v]])), logical(1)))
            if (!has_any_score_data) return(plotly::plotly_empty(type = "scatter", mode = "markers"))

            p <- plotly::plot_ly()
            score_only <- d |> dplyr::filter(!is.na(score))
            if (nrow(score_only) > 0) {
                score_only$tooltip_text <- paste0(
                    "Year: ", score_only$year_n, "<br>Score: ", score_only$score
                )
                p <- p |> plotly::add_trace(
                    data = score_only, x = ~year_n, y = ~score,
                    type = "scatter", mode = "lines+markers", name = "Score",
                    text = ~tooltip_text, hoverinfo = "text",
                    line = list(color = "black", width = 3),
                    marker = list(color = "black", size = 12)
                )
            }
            for (v in map_dimension_vars) {
                lbl <- map_metric_labels[[v]]
                dd <- d |> dplyr::filter(!is.na(.data[[v]]))
                if (nrow(dd) == 0) next
                dd$tooltip_text <- paste0("Year: ", dd$year_n, "<br>Score: ", dd[[v]])
                p <- p |> plotly::add_trace(
                    data = dd, x = ~year_n, y = as.formula(paste0("~", v)),
                    type = "scatter", mode = "lines+markers", name = lbl,
                    text = ~tooltip_text, hoverinfo = "text",
                    line = list(color = trend_dim_colors[[lbl]], width = 1.5),
                    marker = list(color = trend_dim_colors[[lbl]], size = 8)
                )
            }
            # Zoom the y-axis to the country's actual score range (with
            # a little padding) instead of the fixed 0-100 scale — most
            # countries only ever span a narrow band of the full axis,
            # which otherwise leaves the chart mostly empty and visually
            # tiny relative to its allotted space.
            all_vals <- c(d$score, unlist(d[map_dimension_vars], use.names = FALSE))
            all_vals <- all_vals[!is.na(all_vals)]
            rng <- range(all_vals)
            pad <- max(diff(rng) * 0.1, 2)
            y_range <- c(max(0, rng[1] - pad), min(100, rng[2] + pad))

            p |>
                plotly::layout(
                    xaxis = list(title = "Year"),
                    yaxis = list(title = "Score (0\u2013100)", range = y_range)
                )
        }

        rank_trend_plot <- function(d) {
            rank_df <- d |>
                dplyr::filter(!is.na(rank)) |>
                dplyr::transmute(year_n, series = "Rank", value = rank)
            dim_df <- dplyr::bind_rows(lapply(names(rank_dim_map), function(v) {
                d |>
                    dplyr::filter(!is.na(.data[[v]])) |>
                    dplyr::transmute(year_n, series = rank_dim_map[[v]], value = .data[[v]])
            }))
            # Rank's line is kept as thin as the dimension-rank lines —
            # it doesn't need extra weight to stand out because it
            # already spans far more years (~2003-2025 vs. 2022-2025
            # for the dimensions).
            df <- dplyr::bind_rows(rank_df, dim_df) |>
                dplyr::mutate(
                    lw = 0.7,
                    pt = dplyr::if_else(series == "Rank", 3, 1.5)
                )

            if (nrow(df) == 0) return(plotly::plotly_empty(type = "scatter", mode = "markers"))

            rank_colors <- c(Rank = "black", trend_dim_colors)

            # geom_bump() errors on a series with fewer than 2 points
            # (e.g. a defunct historical state with a single year of
            # rank data) — such series still show as an isolated dot
            # via geom_point() below, just without a bump line drawn
            # through them.
            bumpable <- df |>
                dplyr::count(series) |>
                dplyr::filter(n >= 2) |>
                dplyr::pull(series)
            bump_df <- df |> dplyr::filter(series %in% bumpable)

            # `text` is mapped only on geom_point() (not the top-level
            # aes()) because geom_bump()'s ggplotly() conversion errors
            # ("argument 1 is not a vector") when it inherits a `text`
            # aesthetic — its line traces end up with no tooltip text,
            # which is fine since each point already carries year/value.
            # geom_point()'s `text` aes isn't a real ggplot2 aesthetic —
            # only ggplotly() reads it later to build the tooltip — so
            # ggplot2 warns "Ignoring unknown aesthetics: text" on
            # construction. Harmless; suppressed here.
            p <- suppressWarnings(ggplot2::ggplot(
                df, ggplot2::aes(x = year_n, y = value, color = series, linewidth = lw)
            ) +
                ggplot2::geom_point(ggplot2::aes(
                    size = pt,
                    text = paste0("Year: ", year_n, "<br>Rank: ", value)
                )))
            p <- p +
                ggplot2::scale_linewidth_identity() +
                ggplot2::scale_size_identity() +
                ggplot2::scale_colour_manual(values = rank_colors) +
                ggplot2::scale_y_reverse() +
                ggplot2::theme_bw() +
                # Panel border is dropped here and instead drawn
                # identically on both panels by set_axis_font()'s
                # showline/mirror, below — see that function's comment
                # for why (theme_bw()'s own border, left in place,
                # visibly mismatched the plot_ly() score panel's lack
                # of one).
                ggplot2::theme(legend.position = "none", panel.border = ggplot2::element_blank()) +
                ggplot2::xlab("Year") +
                ggplot2::ylab("Rank")

            if (nrow(bump_df) > 0) {
                p <- p + ggbump::geom_bump(data = bump_df)
            }

            plotly::ggplotly(p, tooltip = "text")
        }

        trend_data_available <- shiny::reactive({
            d <- country_data()
            any(!is.na(d$score)) || any(!is.na(d$rank))
        })

        output$trend_plot_or_placeholder <- shiny::renderUI({
            if (!trend_data_available()) {
                return(no_data_msg("No Score or Rank data available for this country."))
            }
            # height = "100%" resolves correctly in both wide and
            # narrow mode because .country-trend-wrapper always has a
            # *definite* size (flex-basis, not just min-height — see
            # app.R's @container rule) — no need to branch on narrow()
            # here. This also means this renderUI (and thus the
            # plotlyOutput() div itself) no longer needs to
            # re-render when narrow() flips, only output$trend_plot's
            # *content* does — avoiding a race where the container was
            # destroyed/recreated at the same moment the new subplot
            # layout arrived, which could leave Plotly computing a
            # wildly wrong height (observed: tens of thousands of px)
            # against a container that hadn't finished resizing yet.
            plotly::plotlyOutput(ns("trend_plot"), height = "100%")
        })

        output$trend_plot <- plotly::renderPlotly({
            shiny::req(trend_data_available())
            d <- country_data()

            # plot_ly() and ggplotly() each stamp a default top-level
            # $x$config onto their widget; subplot() tries to merge both
            # widgets' top-level attributes and warns "Can only have
            # one: config" when the two configs differ. Stripping it
            # from *both* panels instead trips a different subplot()
            # warning ("No config found"), so keep exactly one copy
            # (the score panel's) and strip the other; the single
            # config() call after subplot()/layout() below is what
            # actually governs the merged widget's behavior anyway.
            p_score <- score_trend_plot(d) |>
                plotly::plotly_build() |>
                set_axis_font() |>
                dedup_legend(show_dims = TRUE)
            p_rank <- rank_trend_plot(d) |>
                plotly::plotly_build() |>
                set_axis_font() |>
                dedup_legend(show_dims = FALSE)
            p_rank$x$config <- NULL

            # Side by side above the breakpoint (1:2 width split, matching
            # each panel's natural x-axis span: 13 years vs. ~23); stacked
            # vertically below it, where the Overview row has already
            # gone to a single narrow column — squeezing both panels into
            # that width side by side left each one only ~150px wide,
            # crushing the x-axis and making the rank bump chart in
            # particular unreadable ("rotated" is really just its bumps
            # collapsing into near-vertical lines at that aspect ratio).
            is_narrow <- isTRUE(narrow())
            subplot_args <- if (is_narrow) {
                list(nrows = 2, heights = c(0.45, 0.55), margin = 0.08)
            } else {
                list(nrows = 1, widths = c(1 / 3, 2 / 3), margin = 0.04)
            }

            legend_y <- if (is_narrow) -0.14 else -0.3
            margin_b <- if (is_narrow) 90 else 110

            widget <- do.call(plotly::subplot, c(
                list(p_score, p_rank, titleX = TRUE, titleY = TRUE),
                subplot_args
            )) |>
                plotly::layout(
                    # subplot() otherwise inherits a top-level
                    # showlegend = FALSE from the rank panel's
                    # theme(legend.position = "none") (see
                    # rank_trend_plot()) and silences every trace's
                    # legend regardless of their own showlegend value
                    # set in dedup_legend() above.
                    showlegend = TRUE,
                    legend = list(
                        orientation = "h", xanchor = "center", x = 0.5,
                        yanchor = "top", y = legend_y, font = list(size = 15)
                    ),
                    margin = list(b = margin_b)
                ) |>
                plotly::config(displayModeBar = FALSE)

            widget
        })

        # Return the selected country reactive so other views can access it
        # (e.g., to add it to the Trends chart when navigating away)
        selected
    })
}
