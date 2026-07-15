## inst/app/R/mod_map.R
## Map module: interactive geographic visualization of press freedom scores/ranks
##
## mapSidebarUI() — filter controls (year, zone, metric) for the sidebar
## mapMainUI()    — choropleth output
## mapServer()    — reactive filtering and choropleth rendering; full country
##                  detail (score/rank/contexts/safety) surfaces in the hover
##                  tooltip rather than a click-triggered sidebar panel

mapSidebarUI <- function(id, rwb) {
  ns <- shiny::NS(id)
  shiny::tagList(
    # Strategy A: filter controls live in the sidebar so the main panel is
    # dedicated entirely to the map. Stacked vertically to fit the sidebar
    # width, above the (dynamic) country-detail panel.
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
      choices = c("World", sort(as.character(unique(rwb$zone)))),
      selected = "World",
      width = "100%"
    ),
    shiny::uiOutput(ns("range_selector_ui")),
    shiny::radioButtons(
      ns("metric"),
      label = "Metric",
      choices = c("Score" = "score", "Rank" = "rank"),
      selected = "score",
      inline = TRUE
    )
  )
}

mapMainUI <- function(id, rwb) {
  ns <- shiny::NS(id)
  shiny::tagList(
    # Map visualization — fluid height (matches the calc(100vh - Xpx) pattern
    # used by the other cards in mod_chart.R / mod_country.R). With the
    # controls row removed from the main panel (Strategy A), only the
    # navbar remains above the card, so the offset matches the ~105px used
    # by the sibling modules.
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

    # Reset map to default state (last year, World, Score) when triggered
    if (!is.null(reset)) {
      shiny::observeEvent(reset(), {
        shiny::updateSelectInput(session, "year",
            choices  = sort(unique(rwb$year_n), decreasing = TRUE),
            selected = max(rwb$year_n, na.rm = TRUE))
        shiny::updateSelectInput(session, "zone",   selected = "World")
        shiny::updateRadioButtons(session, "metric", selected = "score")
      }, ignoreInit = TRUE)
    }

    # Reactively update year choices based on selected zone
    shiny::observe({
      shiny::req(input$zone)
      selected_zone <- input$zone

      # Get years available for the selected zone
      if (selected_zone == "World") {
        available_years <- sort(unique(rwb$year_n), decreasing = TRUE)
      } else {
        available_years <- sort(
          unique(rwb$year_n[rwb$zone == selected_zone]),
          decreasing = TRUE
        )
      }

      # Update the year selector
      shiny::updateSelectInput(
        session,
        "year",
        choices = available_years,
        selected = max(available_years, na.rm = TRUE)
      )
    })

    # Dynamically render the range selector based on metric choice
    output$range_selector_ui <- shiny::renderUI({
      shiny::req(input$metric)
      metric <- input$metric

      if (metric == "score") {
        shiny::selectInput(
          ns("range_bin"),
          label = "Score Range",
          choices = c(
            "All Scores" = "all",
            "80–100" = "80-100",
            "60–80" = "60-80",
            "40–60" = "40-60",
            "20–40" = "20-40",
            "0–20" = "0-20"
          ),
          selected = "all",
          width = "100%"
        )
      } else {
        # Rank ranges: 5 tiers based on percentiles
        # Rank 1 is included in Top 2.5%; last rank is included in Bottom 2.5%
        shiny::selectInput(
          ns("range_bin"),
          label = "Rank Range",
          choices = c(
            "All Ranks" = "all",
            "Top 2.5%" = "rank-2",
            "2.5% - 15%" = "rank-3",
            "15% - 85%" = "rank-4",
            "85% - 97.5%" = "rank-5",
            "Bottom 2.5%" = "rank-6"
          ),
          selected = "all",
          width = "100%"
        )
      }
    })

    # Score binning function
    bin_score <- function(score) {
      dplyr::case_when(
        score < 20 ~ "0–20",
        score < 40 ~ "20–40",
        score < 60 ~ "40–60",
        score < 80 ~ "60–80",
        TRUE ~ "80–100"
      )
    }

    # Rank binning function based on percentiles
    # Divides countries into 5 tiers:
    # 2: top 2.5%  — includes rank 1
    # 3: 2.5%–15%
    # 4: 15%–85%   — bulk of countries
    # 5: 85%–97.5%
    # 6: bottom 2.5% — includes last rank
    bin_rank <- function(rank, max_rank) {
      p2_5  <- ceiling(max_rank * 0.025)
      p15   <- floor(max_rank * 0.15)
      p85   <- floor(max_rank * 0.85)
      p97_5 <- floor(max_rank * 0.975)

      dplyr::case_when(
        rank <= p2_5  ~ "rank-2",
        rank <= p15   ~ "rank-3",
        rank <= p85   ~ "rank-4",
        rank <= p97_5 ~ "rank-5",
        TRUE          ~ "rank-6"
      )
    }

    # Filtered data: year, zone, and range bin selection
    map_data <- shiny::reactive({
      shiny::req(input$year, input$zone, input$range_bin, input$metric)

      # If "World" is selected, include all zones; otherwise use the selected zone
      selected_zones <- if (input$zone == "World") {
        as.character(unique(rwb$zone))
      } else {
        input$zone
      }

      result <- rwb |>
        dplyr::mutate(zone = as.character(zone)) |>
        dplyr::filter(
          year_n == input$year,
          zone %in% selected_zones
        )

      metric <- input$metric

      if (metric == "score") {
        # Apply score-based filtering
        result <- result |>
          dplyr::mutate(
            range_bin = bin_score(score),
            .keep = "all"
          )

        # Apply score bin filter if not "all"
        if (input$range_bin != "all") {
          bounds <- as.numeric(strsplit(input$range_bin, "-")[[1]])
          result <- result |>
            dplyr::filter(score >= bounds[1], score < bounds[2])
        }
      } else {
        # Apply rank-based filtering
        max_rank <- max(rwb$rank, na.rm = TRUE)
        result <- result |>
          dplyr::mutate(
            range_bin = bin_rank(rank, max_rank),
            .keep = "all"
          )

        # Apply rank tier filter if not "all"
        if (input$range_bin != "all") {
          result <- result |>
            dplyr::filter(range_bin == input$range_bin)
        }
      }

      result |>
        dplyr::select(
          iso,
          country_en,
          year_n,
          zone,
          score,
          rank,
          range_bin,
          political_context,
          economic_context,
          legal_context,
          social_context,
          safety
        )
    })

    # Render the choropleth map using plotly
    output$map <- plotly::renderPlotly({
      shiny::req(map_data())

      data <- map_data()
      metric <- input$metric
      max_rank <- max(rwb$rank, na.rm = TRUE)

      # Format a numeric vector for tooltip display, falling back to "–" for
      # NA (dimension scores are only available for 2022+)
      fmt_or_dash <- function(x) {
        ifelse(is.na(x), "–", as.character(round(x, 1)))
      }

      # Detail lines shared by both metric branches: dimension context
      # scores and safety, appended to the hover tooltip so all country
      # detail is available on hover (no click/sidebar panel needed)
      detail_lines <- paste0(
        "Political: ", fmt_or_dash(data$political_context), "<br>",
        "Economic: ", fmt_or_dash(data$economic_context), "<br>",
        "Legal: ", fmt_or_dash(data$legal_context), "<br>",
        "Social: ", fmt_or_dash(data$social_context), "<br>",
        "Safety: ", fmt_or_dash(data$safety)
      )

      # RSF-style color scale: dark red (worst) → orange → yellow → light green → dark green (best)
      # Based on ColorBrewer RdYlGn 5-class; luminance variation aids colorblind legibility
      rsf_colorscale <- list(
        list(0.00, "rgb(215, 48, 39)"),
        list(0.25, "rgb(252, 141, 89)"),
        list(0.50, "rgb(254, 224, 139)"),
        list(0.75, "rgb(145, 207, 96)"),
        list(1.00, "rgb(26, 152, 80)")
      )

      # Determine color scale and value column based on metric
      if (metric == "score") {
        z_values <- data$score
        z_min <- 0
        z_max <- 100
        colorscale <- rsf_colorscale
        reversescale <- FALSE
        z_label <- "Score (0–100)"
        hovertext <- paste0(
          "<b>",
          data$country_en,
          "</b><br>",
          "Score: ",
          round(data$score, 1),
          "<br>",
          "Rank: ",
          data$rank,
          "<br>",
          "Range: ",
          data$range_bin,
          "<br>",
          "Zone: ",
          data$zone,
          "<br>",
          detail_lines
        )
      } else {
        # Rank metric: invert rank values so rank 1 (best) maps to high color intensity
        z_values <- max_rank - data$rank + 1
        z_min <- 1
        z_max <- max_rank
        colorscale <- rsf_colorscale
        reversescale <- FALSE
        z_label <- "Rank"
        hovertext <- paste0(
          "<b>",
          data$country_en,
          "</b><br>",
          "Rank: ",
          data$rank,
          "<br>",
          "Score: ",
          round(data$score, 1),
          "<br>",
          "Tier: ",
          data$range_bin,
          "<br>",
          "Zone: ",
          data$zone,
          "<br>",
          detail_lines
        )
      }

      # Build choropleth
      plotly::plot_geo(data, locations = ~iso, z = z_values) |>
        plotly::add_trace(
          type = "choropleth",
          colorscale = colorscale,
          reversescale = reversescale,
          zmin = z_min,
          zmax = z_max,
          text = hovertext,
          hovertemplate = "%{text}<extra></extra>",
          colorbar = list(
            title = z_label,
            # For rank: show inverted tick labels (1 at top = best)
            tickvals = if (metric == "rank") {
              seq(max_rank, 1, by = -max_rank / 4)
            } else {
              NULL
            },
            ticktext = if (metric == "rank") {
              as.character(seq(1, max_rank, by = max_rank / 4))
            } else {
              NULL
            },
            # Strategy C: narrower colorbar frees up horizontal space
            len = 0.7,
            thickness = 15
          ),
          marker = list(line = list(width = 0.5))
        ) |>
        plotly::layout(
          # Strategy C: title moved into an in-plot annotation (top-left) so
          # the reclaimed 40px margin goes to the map instead of a title bar
          annotations = list(
            list(
              text = paste0(
                "Press Freedom ",
                stringr::str_to_title(metric),
                " – ",
                input$year
              ),
              xref = "paper",
              yref = "paper",
              x = 0,
              y = 1,
              xanchor = "left",
              yanchor = "top",
              showarrow = FALSE,
              font = list(size = 14)
            )
          ),
          geo = list(
            showland = TRUE,
            landcolor = "rgb(243, 243, 243)",
            coastcolor = "rgb(204, 204, 204)",
            countrywidth = 0.5,
            showocean = TRUE,
            oceancolor = "rgb(204, 229, 255)",
            # Strategy C: Robinson projection reduces the polar inflation of
            # Natural Earth; latitude clipping drops Antarctica/Arctic, where
            # there is no press freedom data, freeing up plot area for the
            # inhabited landmass
            projection = list(type = "robinson"),
            lataxis = list(range = c(-75, 80))
          ),
          margin = list(l = 0, r = 0, t = 10, b = 0)
        )
    })
  })
}
