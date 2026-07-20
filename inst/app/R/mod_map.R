## inst/app/R/mod_map.R
## Map module: interactive geographic visualization of press freedom
## scores/ranks/dimensions.
##
## mapSidebarUI() — year/zone/metric filters + band checkboxes (sidebar)
## mapMainUI()    — choropleth output
## mapServer()    — reactive filtering, choropleth rendering, and
##                  click-to-navigate; returns a reactive holding the most
##                  recently clicked country's name (or NULL)
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

mapSidebarUI <- function(id, rwb) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::selectInput(
      ns("year"),
      label = "Year",
      choices = sort(unique(rwb$year_n), decreasing = TRUE),
      selected = max(rwb$year_n, na.rm = TRUE),
      width = "100%"
    ),
    shiny::selectInput(
      ns("zone"),
      label = "Zone",
      choices = c("World", sort(unique(rwb$zone))),
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
    shiny::uiOutput(ns("bands_ui"))
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

mapServer <- function(id, rwb, reset = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # Reset filters to their defaults when triggered (e.g. title click).
    # The old pan/zoom relayout plumbing tied to the previous
    # dropdown+hover-pulse selection mechanism is intentionally dropped —
    # click-to-navigate (below) replaces that interaction entirely.
    if (!is.null(reset)) {
      shiny::observeEvent(reset(), {
        shiny::updateSelectInput(session, "year",
            choices  = sort(unique(rwb$year_n), decreasing = TRUE),
            selected = max(rwb$year_n, na.rm = TRUE))
        shiny::updateSelectInput(session, "zone", selected = "World")
        shiny::updateSelectInput(session, "metric", selected = "score")
      }, ignoreInit = TRUE)
    }

    # Year choices react to both zone (existing behaviour) and metric:
    # dimensions only exist from 2022 onward and score only from 2013
    # onward (rank goes back to 2002), so picking one restricts the year
    # list accordingly.
    shiny::observe({
      shiny::req(input$zone, input$metric)

      years <- if (input$zone == "World") {
        rwb$year_n
      } else {
        rwb$year_n[rwb$zone == input$zone]
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
    # whether the active metric is rank or a score-like variable. All
    # bands start checked; switching metric type rebuilds the set fresh.
    output$bands_ui <- shiny::renderUI({
      shiny::req(input$metric)
      is_rank <- input$metric == "rank"
      levels_ <- if (is_rank) rank_tier_levels else rsf_band_levels
      labels_ <- if (is_rank) rank_tier_labels else rsf_band_labels
      colors_ <- if (is_rank) rank_tier_colors else rsf_band_colors

      shiny::tagList(
        # Scoped to this input's id so it doesn't leak to other checkbox
        # groups in the app; smaller font keeps every label on one line
        # at the sidebar's 260px width.
        shiny::tags$style(shiny::HTML(paste0(
          "#", ns("bands"), " .checkbox label { font-size: 0.8rem; }"
        ))),
        shiny::checkboxGroupInput(
          ns("bands"),
          label = if (is_rank) "Show tiers" else "Show bands",
          choiceNames = band_choice_names(levels_, labels_, colors_),
          choiceValues = levels_,
          selected = levels_
        )
      )
    })

    # Filtered data: year + zone, with every row classified into a band
    # regardless of checkbox state (unchecked bands are greyed out at
    # render time, not removed here).
    map_data <- shiny::reactive({
      shiny::req(input$year, input$zone, input$metric)

      selected_zones <- if (input$zone == "World") {
        unique(rwb$zone)
      } else {
        input$zone
      }

      result <- rwb |>
        dplyr::filter(year_n == input$year, zone %in% selected_zones)

      metric <- input$metric
      result <- if (metric == "rank") {
        max_rank <- max(rwb$rank, na.rm = TRUE)
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
      checked <- input$bands
      if (is.null(checked)) checked <- levels_

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
            marker = list(line = list(width = 0.5, color = "rgb(180, 180, 180)"))
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
          margin = list(l = 0, r = 0, t = 10, b = 0)
        ) |>
        plotly::event_register("plotly_click")
    })

    # Click-to-navigate: a click on any country sets a reactive that the
    # app-level server can observe to switch to the Country view. Replaces
    # the old dropdown + hover-pulse selection JS entirely.
    clicked_country <- shiny::reactiveVal(NULL)
    shiny::observeEvent(plotly::event_data("plotly_click", source = ns("map")), {
      ed <- plotly::event_data("plotly_click", source = ns("map"))
      shiny::req(ed$customdata)
      clicked_country(ed$customdata)
    })

    shiny::reactive(clicked_country())
  })
}
