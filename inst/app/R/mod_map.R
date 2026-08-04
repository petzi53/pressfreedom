## inst/app/R/mod_map.R
## Map module: interactive geographic visualization of press freedom
## scores/ranks/dimensions.
##
## mapSidebarUI() — year/zone/metric filters + band checkboxes (sidebar)
## mapMainUI()    — choropleth output
## mapServer()    — reactive filtering, choropleth rendering, and
##                  click-to-navigate; returns a reactive holding
##                  list(country=, nonce=) for the most recently clicked
##                  country (or NULL) — not a bare string; see the
##                  "Click-to-navigate" comment below for why the nonce
##                  is needed
##
## Bands (score-like metrics) use RSF's real 5-class classification, taken
## verbatim from RSF's methodology page ("Press freedom map" section):
##   [85-100] good, [70-85[ satisfactory, [55-70[ problematic,
##   [40-55[ difficult, [0-40[ very serious.
## Rank keeps the existing percentile-tier bins (top 2.5% / 2.5-15% /
## 15-85% / 85-97.5% / bottom 2.5%), per decision #2 (rank stays as a map
## metric) — just exposed via the same checkbox interaction as the score
## bands, rather than a single-select range filter.
##
## Each band/tier is an independent checkboxGroupInput toggle. Unchecked
## bands are greyed out rather than removed from the map, so geography
## stays legible even when narrowing focus to specific bands.

# Dimension columns are only available 2022+; kept as map-coloring options
# (per decision #1/#2) since a single-year snapshot is the natural unit for
# them, unlike a multi-year trend (see AGENTS.md for the Trends-view
# treatment, which excludes them).
map_dimension_vars <- c(
  "political_context", "economic_context", "legal_context",
  "social_context", "safety"
)

map_metric_choices <- c(
  "Score"             = "score",
  "Rank"              = "rank",
  "Political Context" = "political_context",
  "Economic Context"  = "economic_context",
  "Legal Context"     = "legal_context",
  "Social Context"    = "social_context",
  "Safety"            = "safety"
)

map_metric_labels <- c(
  score              = "Score",
  rank               = "Rank",
  political_context = "Political Context",
  economic_context   = "Economic Context",
  legal_context       = "Legal Context",
  social_context      = "Social Context",
  safety              = "Safety"
)

# RSF score bands (score + dimensions, all 0-100 scales) — cutoffs and
# labels verified against RSF's methodology page.
rsf_band_levels <- c("Good", "Satisfactory", "Problematic", "Difficult", "Very Serious")
rsf_band_labels <- c(
  "Good"         = "Good (85\u2013100)",
  "Satisfactory" = "Satisfactory (70\u201385)",
  "Problematic"  = "Problematic (55\u201370)",
  "Difficult"    = "Difficult (40\u201355)",
  "Very Serious" = "Serious (0\u201340)"
)

# Rank percentile tiers (unchanged bins from the previous single-select
# implementation), ordered best -> worst to match the score bands above.
rank_tier_levels <- c("Top 2.5%", "2.5%\u201315%", "15%\u201385%", "85%\u201397.5%", "Bottom 2.5%")
rank_tier_labels <- stats::setNames(rank_tier_levels, rank_tier_levels)

# Shared best -> worst palette (green -> yellow -> orange -> dark orange ->
# dark red), applied to whichever level set is active.
map_band_colors <- c("#2E7D32", "#FDD835", "#FB8C00", "#D84315", "#7B0000")
rsf_band_colors  <- stats::setNames(map_band_colors, rsf_band_levels)
rank_tier_colors <- stats::setNames(map_band_colors, rank_tier_levels)
map_grey <- "rgb(224, 224, 224)"

# Build checkboxGroupInput choiceNames that pair a small colour swatch with
# each label, so the sidebar doubles as the map's legend.
band_choice_names <- function(levels_, labels_, colors_) {
  lapply(levels_, function(lvl) {
    shiny::tagList(
      shiny::span(style = paste0(
        "display:inline-block; width:10px; height:10px; margin-right:5px;",
        "border-radius:2px; vertical-align:middle;",
        "background-color:", colors_[[lvl]], ";"
      )),
      shiny::span(labels_[[lvl]], style = "vertical-align:middle;")
    )
  })
}

# Classify a 0-100 score-like value into an RSF band
rsf_band <- function(score) {
  dplyr::case_when(
    score >= 85 ~ "Good",
    score >= 70 ~ "Satisfactory",
    score >= 55 ~ "Problematic",
    score >= 40 ~ "Difficult",
    !is.na(score) ~ "Very Serious",
    TRUE ~ NA_character_
  )
}

# Classify rank into a percentile tier
# 2: top 2.5%  — includes rank 1
# 3: 2.5%-15%
# 4: 15%-85%   — bulk of countries
# 5: 85%-97.5%
# 6: bottom 2.5% — includes last rank
rank_tier <- function(rank, max_rank) {
  p2_5  <- ceiling(max_rank * 0.025)
  p15   <- floor(max_rank * 0.15)
  p85   <- floor(max_rank * 0.85)
  p97_5 <- floor(max_rank * 0.975)

  dplyr::case_when(
    is.na(rank)   ~ NA_character_,
    rank <= p2_5  ~ "Top 2.5%",
    rank <= p15   ~ "2.5%\u201315%",
    rank <= p85   ~ "15%\u201385%",
    rank <= p97_5 ~ "85%\u201397.5%",
    TRUE          ~ "Bottom 2.5%"
  )
}

mapSidebarUI <- function(id, rwb_standardized) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectInput(
      ns("year"),
      label = "Year",
      choices = sort(unique(rwb_standardized$year_n), decreasing = TRUE),
      selected = max(rwb_standardized$year_n, na.rm = TRUE),
      width = "100%"
    ),
    shiny::selectInput(
      ns("zone"),
      label = "Zone",
      choices = c("World", sort(unique(rwb_standardized$zone))),
      selected = "World",
      width = "100%"
    ),
    shiny::selectInput(
      ns("metric"),
      label = "Metric",
      choices = map_metric_choices,
      selected = "score",
      width = "100%"
    ),
    # Band checkboxes are built once here (score bands, matching the
    # default metric = "score") rather than via renderUI keyed on
    # input$metric. mapServer()'s metric-change observer below uses
    # shiny::updateCheckboxGroupInput() to swap choices/labels/selection
    # when the metric type (score-like vs rank) changes, restoring each
    # type's own remembered selection instead of resetting to "all
    # checked" every time. See mapServer() for why a uiOutput/renderUI
    # rebuild here was the source of the "checkboxes reset when switching
    # back to a previously used metric" bug.
    shiny::tags$style(shiny::HTML(paste0(
      "#", ns("bands"), " .checkbox label { font-size: 0.8rem; }"
    ))),
    shiny::checkboxGroupInput(
      ns("bands"),
      label = "Show bands",
      choiceNames = band_choice_names(rsf_band_levels, rsf_band_labels, rsf_band_colors),
      choiceValues = rsf_band_levels,
      selected = rsf_band_levels
    ),
    shiny::checkboxInput(
      ns("deselect_all"),
      label = "Deselect all",
      value = FALSE
    ),
    shiny::actionButton(
      ns("clear"),
      "Clear",
      icon = shiny::icon("times"),
      class = "btn-sm btn-outline-secondary w-100 mt-1"
    )
  )
}

mapMainUI <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    bslib::card(
      height = "calc(100vh - 105px)",
      full_screen = TRUE,
      plotly::plotlyOutput(ns("map"), height = "100%")
    )
  )
}

mapServer <- function(id, rwb_standardized, reset = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Map view state tracking for zoom/pan preservation.
    # When uirevision in the plotly layout changes, plotly.js resets the
    # user's zoom/pan/geo positioning back to the layout's default. By
    # keeping uirevision constant across all routine control changes
    # (metric switch, band toggles, year/zone selection, etc.), the
    # geo view persists. Only do_reset_map() changes this token, so
    # reset-triggered redraws return to the default position. Uses
    # proc.time()[["elapsed"]] for a globally unique, monotonic value
    # (same pattern as clicked_country's nonce elsewhere in this module).
    map_view_id <- shiny::reactiveVal(as.numeric(proc.time()[["elapsed"]]))

    # Tracks the "Deselect all" checkbox value most recently *set by this
    # module* (whether programmatically, to keep its displayed state
    # honest, or in direct response to the user's own click on it) --
    # see the observeEvent(input$deselect_all, ...) and
    # observeEvent(input$bands, ...) blocks below for why this is needed:
    # without it, a programmatic updateCheckboxInput() call that merely
    # syncs the toggle's *display* (e.g. unchecking it because the user
    # manually re-checked a band) is indistinguishable, from inside the
    # deselect_all observer, from a genuine user click -- and that
    # observer unconditionally resets the whole band selection whenever
    # the box becomes unchecked. See AGENTS.md for the full reproduction
    # and root-cause writeup.
    deselect_all_tracked <- shiny::reactiveVal(FALSE)

    # Complete reset of Map filters and band checkboxes to their defaults.
    # This is called from two entry points:
    # 1. input$clear (the new Clear button in the sidebar)
    # 2. reset() reactive (fed by app.R's "Reset all" button)
    do_reset_map <- function() {
      # Reset both metric types' remembered band/tier selections first
      # (see score_bands_selected/rank_tiers_selected below), so that
      # regardless of whether resetting "metric" to "score" actually
      # changes its value (and thus fires the metric-change observer) or
      # not, the checkbox group ends up showing the full default set.
      score_bands_selected(rsf_band_levels)
      rank_tiers_selected(rank_tier_levels)
      # Reset year/zone/metric to defaults
      shiny::updateSelectInput(session, "year",
          choices  = sort(unique(rwb_standardized$year_n), decreasing = TRUE),
          selected = max(rwb_standardized$year_n, na.rm = TRUE))
      shiny::updateSelectInput(session, "zone", selected = "World")
      shiny::updateSelectInput(session, "metric", selected = "score")
      # Reset band checkboxes and "Deselect all" toggle to their defaults.
      # This closes a pre-existing gap where resetting metric to a value it
      # already had wouldn't re-trigger the metric-change observer above
      # and therefore wouldn't visually reset the checkboxes.
      shiny::updateCheckboxGroupInput(
        session, "bands",
        label = "Show bands",
        choiceNames = band_choice_names(rsf_band_levels, rsf_band_labels, rsf_band_colors),
        choiceValues = rsf_band_levels,
        selected = rsf_band_levels
      )
      deselect_all_tracked(FALSE)
      shiny::updateCheckboxInput(session, "deselect_all", value = FALSE)
      # Bump the map view ID so plotly.js resets zoom/pan to the default
      # geo projection (defined by the layout spec below).
      map_view_id(as.numeric(proc.time()[["elapsed"]]))
    }

    # Wire Clear button to do_reset_map()
    shiny::observeEvent(input$clear, {
      do_reset_map()
    })

    # Wire reset() trigger (fed by app.R's "Reset all" button) to do_reset_map()
    if (!is.null(reset)) {
      shiny::observeEvent(reset(), {
        do_reset_map()
      }, ignoreInit = TRUE)
    }

    # Year choices react to both zone (existing behaviour) and metric:
    # dimensions only exist from 2022 onward and score only from 2013
    # onward (rank goes back to 2002), so picking one restricts the year
    # list accordingly.
    shiny::observe({
      shiny::req(input$zone, input$metric)

      years <- if (input$zone == "World") {
        rwb_standardized$year_n
      } else {
        rwb_standardized$year_n[rwb_standardized$zone == input$zone]
      }

      min_year <- dplyr::case_when(
        input$metric %in% map_dimension_vars ~ 2022,
        input$metric == "score" ~ 2013,
        TRUE ~ -Inf
      )
      years <- years[years >= min_year]

      available_years <- sort(unique(years), decreasing = TRUE)

      shiny::updateSelectInput(
        session, "year",
        choices  = available_years,
        selected = max(available_years, na.rm = TRUE)
      )
    })

    # Band checkboxes: level set (and thus labels/colours) depends on
    # whether the active metric is rank or a score-like variable. Each
    # type remembers its own checkbox selection independently (via the
    # two reactiveVals below) so that switching the metric away and back
    # restores whatever the user had checked, instead of resetting to
    # "all checked".
    #
    # This used to be a uiOutput/renderUI rebuilt on every input$metric
    # change, always with selected = levels_ (full set). That silently
    # discarded the user's checkbox state on every metric switch -- e.g.
    # picking "Good" only under Score, switching to Rank, then back to
    # Score would show all Score bands checked again, even though nothing
    # about Score's own selection should have changed. Fixed by keeping
    # the checkboxGroupInput itself static in mapSidebarUI() and instead
    # using shiny::updateCheckboxGroupInput() here to swap its
    # choices/label/selection, sourcing `selected` from whichever
    # reactiveVal matches the metric type being switched *to*.
    score_bands_selected <- shiny::reactiveVal(rsf_band_levels)
    rank_tiers_selected  <- shiny::reactiveVal(rank_tier_levels)

    shiny::observeEvent(input$metric, {
      is_rank <- input$metric == "rank"
      levels_ <- if (is_rank) rank_tier_levels else rsf_band_levels
      labels_ <- if (is_rank) rank_tier_labels else rsf_band_labels
      colors_ <- if (is_rank) rank_tier_colors else rsf_band_colors
      selected_ <- if (is_rank) rank_tiers_selected() else score_bands_selected()

      shiny::updateCheckboxGroupInput(
        session, "bands",
        label = if (is_rank) "Show tiers" else "Show bands",
        choiceNames = band_choice_names(levels_, labels_, colors_),
        choiceValues = levels_,
        selected = selected_
      )
      # Sync "Deselect all"'s displayed state via deselect_all_tracked
      # *first* -- see its declaration above -- so that when this
      # programmatic update reaches the client and bounces back as an
      # input$deselect_all change, the observer below recognises it as
      # its own echo and skips the destructive full-reset logic, instead
      # of clobbering the selected_ restore just performed above.
      deselect_all_tracked(length(selected_) == 0)
      shiny::updateCheckboxInput(session, "deselect_all", value = length(selected_) == 0)
    }, ignoreInit = TRUE)

    # Wire the "Deselect all" toggle to the band checkboxes. ignoreInit
    # avoids clearing bands on first render, and the levels_ used here
    # must match whichever set (rank tiers vs score bands) is currently
    # displayed.
    #
    # Guarded by deselect_all_tracked: skip the reset logic entirely when
    # this fires as the echo of our own programmatic
    # updateCheckboxInput() call (from the metric-change observer, the
    # input$bands sync below, or do_reset_map()) rather than a genuine
    # user click. Without this guard, restoring a previously-saved
    # partial band selection on a metric switch would immediately be
    # overwritten back to "everything checked" whenever "Deselect all"
    # happened to still be checked from an earlier action -- see
    # AGENTS.md for the full reproduction.
    shiny::observeEvent(input$deselect_all, {
      if (identical(input$deselect_all, deselect_all_tracked())) {
        return(invisible(NULL))
      }
      deselect_all_tracked(input$deselect_all)
      is_rank <- identical(input$metric, "rank")
      levels_ <- if (is_rank) rank_tier_levels else rsf_band_levels
      shiny::updateCheckboxGroupInput(
        session, "bands",
        selected = if (input$deselect_all) character(0) else levels_
      )
    }, ignoreInit = TRUE)

    # Track the "actually checked" set separately from input$bands.
    # checkboxGroupInput reports NULL both (a) before it has ever been
    # rendered, and (b) once the user has unchecked every box — those two
    # cases are indistinguishable from input$bands alone. The render code
    # below used to paper over this with `if (is.null(checked)) checked <-
    # levels_`, which fixed case (a) but silently treated case (b) as "show
    # everything" too, so unchecking all boxes had no visible effect.
    #
    # Fix: initialise to the full default set (matching the initial
    # checkboxGroupInput's selected=levels_) so case (a) still renders
    # correctly, then let every subsequent input$bands change --
    # including a change to NULL from unchecking the last box, captured via
    # ignoreNULL = FALSE -- overwrite it verbatim, so case (b) sticks.
    #
    # Also persists the change into whichever per-type reactiveVal
    # (score_bands_selected / rank_tiers_selected) matches the *current*
    # metric, so the metric-change observer above can restore it later.
    # input$metric already reflects the new value by the time a
    # metric-triggered updateCheckboxGroupInput() call above causes this
    # observer to re-fire (Shiny delivers the metric change first), so
    # this never misattributes a band update to the wrong type.
    checked_bands <- shiny::reactiveVal(rsf_band_levels)
    shiny::observeEvent(input$bands, {
      checked_bands(input$bands)
      is_rank <- identical(input$metric, "rank")
      if (is_rank) {
        rank_tiers_selected(input$bands)
      } else {
        score_bands_selected(input$bands)
      }

      # Keep "Deselect all"'s displayed state honest: check it once the
      # user has (via the individual band checkboxes) ended up with
      # nothing selected, uncheck it as soon as anything is selected --
      # e.g. after checking "Deselect all" and then manually re-checking
      # one band, which used to leave "Deselect all" visibly checked
      # despite a non-empty selection. deselect_all_tracked is updated
      # here *before* the update call reaches the client, so the echoed
      # input$deselect_all change is recognised as our own and doesn't
      # re-trigger the destructive full-reset logic in that observer.
      should_be_checked <- length(input$bands) == 0
      if (!identical(should_be_checked, deselect_all_tracked())) {
        deselect_all_tracked(should_be_checked)
        shiny::updateCheckboxInput(session, "deselect_all", value = should_be_checked)
      }
    }, ignoreNULL = FALSE)

    # Filtered data: year + zone, with every row classified into a band
    # regardless of checkbox state (unchecked bands are greyed out at
    # render time, not removed here).
    map_data <- shiny::reactive({
      shiny::req(input$year, input$zone, input$metric)

      selected_zones <- if (input$zone == "World") {
        unique(rwb_standardized$zone)
      } else {
        input$zone
      }

      result <- rwb_standardized |>
        dplyr::filter(year_n == input$year, zone %in% selected_zones)

      metric <- input$metric
      result <- if (metric == "rank") {
        max_rank <- max(rwb_standardized$rank, na.rm = TRUE)
        result |> dplyr::mutate(band = rank_tier(rank, max_rank))
      } else {
        result |> dplyr::mutate(band = rsf_band(.data[[metric]]))
      }

      result |>
        dplyr::filter(!is.na(band)) |>
        dplyr::select(
          iso, country_en, year_n, zone, score, rank, band,
          political_context, economic_context, legal_context,
          social_context, safety
        )
    })

    # Render the choropleth: one flat-colour trace per band/tier, so
    # unchecked bands can be greyed out independently of the others while
    # keeping every country visible (geography stays legible).
    output$map <- plotly::renderPlotly({
      data <- map_data()
      metric <- input$metric
      is_rank <- metric == "rank"
      levels_ <- if (is_rank) rank_tier_levels else rsf_band_levels
      colors_ <- if (is_rank) rank_tier_colors else rsf_band_colors
      checked <- checked_bands()
      if (is.null(checked)) checked <- character(0)

      # Dimension scores are only available from 2022 onward; substitute
      # one explanatory line instead of five "-" placeholders pre-2022.
      fmt_or_dash <- function(x) ifelse(is.na(x), "\u2013", as.character(round(x, 1)))
      has_dimension_data <- any(!is.na(data$political_context))
      detail_lines <- if (has_dimension_data) {
        paste0(
          "Political: ", fmt_or_dash(data$political_context), "<br>",
          "Economic: ", fmt_or_dash(data$economic_context), "<br>",
          "Legal: ", fmt_or_dash(data$legal_context), "<br>",
          "Social: ", fmt_or_dash(data$social_context), "<br>",
          "Safety: ", fmt_or_dash(data$safety)
        )
      } else {
        "Dimension scores available from 2022"
      }

      band_label <- if (is_rank) data$band else rsf_band_labels[data$band]
      hovertext <- paste0(
        flag_emoji(data$iso), " <b>", data$country_en, "</b><br>",
        "Score: ", round(data$score, 1), "<br>",
        "Rank: ", data$rank, "<br>",
        map_metric_labels[metric], " band: ", band_label, "<br>",
        "Zone: ", data$zone, "<br>",
        detail_lines
      )
      data$hovertext <- hovertext

      # plotly keys shiny click events on the plot's own `source`
      # attribute (defaults to "A"), not the plotlyOutput's DOM id —
      # must match the `source` used in event_data() below or clicks
      # are silently never delivered (and Shiny warns about it).
      p <- plotly::plot_geo(source = ns("map"))
      for (lvl in levels_) {
        sub <- data[data$band == lvl, , drop = FALSE]
        if (nrow(sub) == 0) next

        color <- if (lvl %in% checked) colors_[[lvl]] else map_grey

        p <- p |>
          plotly::add_trace(
            data = sub,
            type = "choropleth",
            locations = ~iso,
            z = rep(1, nrow(sub)),
            showscale = FALSE,
            colorscale = list(list(0, color), list(1, color)),
            customdata = ~country_en,
            text = ~hovertext,
            hovertemplate = "%{text}<extra></extra>",
            showlegend = FALSE,
            marker = list(line = list(width = 0.5, color = "white"))
          )
      }

      p |>
        plotly::layout(
          annotations = list(
            list(
              text = paste0(
                "<b>Press Freedom ", map_metric_labels[metric], " \u2013 ", input$year, "</b>"
              ),
              xref = "paper", yref = "paper", x = 0, y = 1,
              xanchor = "left", yanchor = "top",
              showarrow = FALSE, font = list(size = 14)
            )
          ),
          geo = list(
            showland = TRUE,
            landcolor = "rgb(243, 243, 243)",
            coastcolor = "rgb(204, 204, 204)",
            countrywidth = 0.5,
            showocean = TRUE,
            oceancolor = "rgb(204, 229, 255)",
            projection = list(type = "robinson"),
            lataxis = list(range = c(-75, 80))
          ),
          margin = list(l = 0, r = 0, t = 10, b = 0),
          uirevision = map_view_id(),
          # The plotly htmlwidget's Shiny binding only calls Plotly.react()
          # (which respects uirevision) when layout$transition is truthy;
          # otherwise every renderPlotly() re-run does Plotly.purge() +
          # Plotly.newPlot(), a full teardown that discards uirevision's
          # preserved zoom/pan regardless of the token. duration = 0 keeps
          # this instantaneous (no visible animation) while still routing
          # through the react() path.
          transition = list(duration = 0)
        ) |>
        plotly::event_register("plotly_click")
    })

    # Click-to-navigate: a click on any country sets a reactive that the
    # app-level server can observe to switch to the Country view. Replaces
    # the old dropdown + hover-pulse selection JS entirely.
    #
    # Stored as list(country=, nonce=) rather than a bare string:
    # reactiveVal() skips invalidating dependents when set to a value
    # identical() to its current one. The nonce (proc.time() elapsed
    # seconds) ensures two clicks are never identical(), even when the
    # country name repeats or when a different module already set the
    # same country into the shared selected_country reactiveVal in
    # app.R — an integer counter would collide across modules.
    #
    # priority = "event" on both event_data() calls below is also
    # required: event_data()'s default priority ("input") reads from an
    # internal plotly-managed reactiveValues cache that itself skips
    # invalidating dependents when the newly parsed click payload is
    # identical() to the previously cached one — the same class of bug
    # as above, just inside plotly's own code. Without it, re-clicking
    # the same country never even reaches this observeEvent(), so the
    # nonce below would never get a chance to run. See mod_chart.R's
    # matching click observer for the same fix.
    clicked_country <- shiny::reactiveVal(NULL)
    shiny::observeEvent(
      plotly::event_data("plotly_click", source = ns("map"), priority = "event"),
      {
      ed <- plotly::event_data("plotly_click", source = ns("map"), priority = "event")
      shiny::req(ed$customdata)
      clicked_country(list(
        country = ed$customdata,
        nonce = as.numeric(proc.time()[["elapsed"]])
      ))
    })

    shiny::reactive(clicked_country())
  })
}
