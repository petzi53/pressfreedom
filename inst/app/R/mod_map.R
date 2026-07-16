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
      choices = c("World", sort(unique(rwb$zone))),
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
      style = "position: relative;",
      # Floating country dropdown, positioned near the in-plot title
      # (top-left annotation) but offset right, clear of plotly's modebar
      # icons at the top-right of the plot. Exact offsets may need visual
      # tuning once running.
      shiny::div(
        style = paste(
          "position: absolute; top: 8px; right: 190px; z-index: 20;",
          "background: rgba(255,255,255,0.9); border-radius: 4px;",
          "padding: 2px 6px; box-shadow: 0 1px 3px rgba(0,0,0,0.15);"
        ),
        shiny::uiOutput(ns("country_select_ui"))
      ),
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
        shiny::updateSelectInput(session, "selected_country", selected = "")

        # Reset pan/zoom directly: updateSelectInput()/updateRadioButtons()
        # above are no-ops (and don't retrigger output$map) when the widgets
        # already hold their default values, so the map's zoom/pan state
        # would otherwise survive a reset. Zooming mutates geo.projection.scale
        # and geo.center.*; panning on this (Robinson) projection mutates
        # geo.projection.rotation.* instead, so both must be reset.
        plotly::plotlyProxy("map", session) |>
          plotly::plotlyProxyInvoke(
            "relayout",
            list(
              "geo.projection.scale" = 1,
              "geo.center.lon" = 0,
              "geo.center.lat" = 0,
              "geo.projection.rotation.lon" = 0,
              "geo.projection.rotation.lat" = 0,
              "geo.projection.rotation.roll" = 0
            )
          )
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

    # Country choices for the floating dropdown: alphabetically sorted,
    # restricted to the countries present for the current year *and* zone
    # filter (independent of metric/range-bin, so narrowing the range
    # doesn't shrink the list — only year/zone do)
    country_choices <- shiny::reactive({
      shiny::req(input$year, input$zone)

      selected_zones <- if (input$zone == "World") {
        unique(rwb$zone)
      } else {
        input$zone
      }

      rwb |>
        dplyr::filter(year_n == input$year, zone %in% selected_zones) |>
        dplyr::pull(country_en) |>
        unique() |>
        sort()
    })

    # Floating country dropdown (rendered in the map card, not the sidebar)
    output$country_select_ui <- shiny::renderUI({
      choices <- country_choices()

      # Preserve the current selection across year/zone changes if it's
      # still valid; otherwise fall back to "None"
      current <- shiny::isolate(input$selected_country)
      selected <- if (!is.null(current) && current %in% choices) current else ""

      shiny::selectInput(
        ns("selected_country"),
        label = NULL,
        choices = c("None" = "", choices),
        selected = selected,
        width = "180px"
      )
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
        unique(rwb$zone)
      } else {
        input$zone
      }

      result <- rwb |>
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
      # NA (an individual country missing a value despite dimension data
      # being available for the selected year — expected to be rare)
      fmt_or_dash <- function(x) {
        ifelse(is.na(x), "–", as.character(round(x, 1)))
      }

      # Dimension scores are only available from 2022 onward. Rather than
      # showing five "–" placeholders per country for every earlier year,
      # check once (year-level, not row-level) and substitute a single
      # explanatory line.
      has_dimension_data <- any(!is.na(data$political_context))

      # Detail lines shared by both metric branches: dimension context
      # scores and safety, appended to the hover tooltip so all country
      # detail is available on hover (no click/sidebar panel needed)
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

      # Resolve the dropdown's selected country (if any) to an iso code and
      # its 0-based point index within this trace's data, for the
      # selection outline and hover/pulse JS below. The selected country
      # may have dropped out of the current year/zone/range filter (e.g.
      # narrowing the range bin) — in that case treat it as unselected here.
      selected_country <- input$selected_country
      selected_iso <- NULL
      selected_idx <- -1
      if (!is.null(selected_country) && nzchar(selected_country)) {
        match_row <- which(data$country_en == selected_country)
        if (length(match_row) == 1 && data$iso[match_row] %in% data$iso) {
          selected_iso <- data$iso[match_row]
          selected_idx <- match_row - 1L # 0-based index for JS
        }
      }

      # Default (non-hovered) border styling — explicit so the hover/pulse
      # JS below can restyle relative to a known baseline
      base_border_width <- 0.5
      base_border_color <- "rgb(180, 180, 180)"

      # Build choropleth
      p <- plotly::plot_geo(data, locations = ~iso, z = z_values) |>
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
          marker = list(line = list(width = base_border_width, color = base_border_color))
        )

      # Selection outline: a second, fill-transparent choropleth trace
      # covering only the selected country, giving it an independently
      # styled (dashed black) border without touching the shared score/rank
      # color scale. Only added when a valid selection exists.
      if (!is.null(selected_iso)) {
        p <- p |>
          plotly::add_trace(
            type = "choropleth",
            locations = selected_iso,
            z = 1,
            showscale = FALSE,
            colorscale = list(list(0, "rgba(0,0,0,0)"), list(1, "rgba(0,0,0,0)")),
            marker = list(line = list(color = "black", width = 3, dash = "dash")),
            hoverinfo = "skip"
          )
      }

      p <- p |>
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

      # Hover / selection-pulse behaviour, injected as JS since plotly.js
      # has no built-in "highlight hovered choropleth region" option:
      #   - plotly_hover:   thicken + blacken the border of the hovered
      #                     country on the main trace (trace 0)
      #   - plotly_unhover: reset the main trace border to baseline, and
      #                     stop/reset any pulsing on the selection trace
      #   - if the hovered country IS the selected country (trace 1, when
      #     present), also pulse its dashed outline via Plotly.restyle
      #     (width/dash alternation) rather than a fragile stroke-dashoffset
      #     animation
      n_points <- nrow(data)
      has_selection_trace <- !is.null(selected_iso)

      js <- sprintf(
        "
        function(el) {
          var n = %d;
          var selIdx = %d;
          var hasSel = %s;
          var baseWidth = %f, baseColor = '%s';
          var hoverWidth = 4, hoverColor = 'black';
          var pulseTimer = null;

          function resetMain() {
            var widths = new Array(n).fill(baseWidth);
            var colors = new Array(n).fill(baseColor);
            Plotly.restyle(el, {'marker.line.width': [widths], 'marker.line.color': [colors]}, [0]);
          }

          function stopPulse() {
            if (pulseTimer) { clearInterval(pulseTimer); pulseTimer = null; }
            if (hasSel) {
              Plotly.restyle(el, {'marker.line.width': [[3]], 'marker.line.dash': [['dash']]}, [1]);
            }
          }

          el.on('plotly_hover', function(d) {
            var pt = d.points[0];
            if (pt.curveNumber !== 0) return;
            var idx = pt.pointNumber;

            var widths = new Array(n).fill(baseWidth);
            var colors = new Array(n).fill(baseColor);
            widths[idx] = hoverWidth;
            colors[idx] = hoverColor;
            Plotly.restyle(el, {'marker.line.width': [widths], 'marker.line.color': [colors]}, [0]);

            if (hasSel && idx === selIdx) {
              var toggle = false;
              pulseTimer = setInterval(function() {
                toggle = !toggle;
                Plotly.restyle(el, {
                  'marker.line.width': [[toggle ? 5 : 2]],
                  'marker.line.dash': [[toggle ? 'dot' : 'dash']]
                }, [1]);
              }, 450);
            }
          });

          el.on('plotly_unhover', function(d) {
            resetMain();
            stopPulse();
          });
        }
        ",
        n_points,
        selected_idx,
        if (has_selection_trace) "true" else "false",
        base_border_width,
        base_border_color
      )

      p |> htmlwidgets::onRender(js)
    })
  })
}
