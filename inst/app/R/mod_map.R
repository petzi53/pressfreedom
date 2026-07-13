## inst/app/R/mod_map.R
## Map module: interactive geographic visualization of press freedom scores/ranks
##
## mapSidebarUI() — filter controls (year, zone, metric) for the sidebar
## mapMainUI()    — choropleth output with collapsible country detail panel
## mapServer()    — reactive filtering, choropleth rendering, country detail sidebar

mapSidebarUI <- function(id) {
  ns <- shiny::NS(id)
  shiny::div(shiny::uiOutput(ns("country_detail")))
}

mapMainUI <- function(id, rwb) {
  ns <- shiny::NS(id)
  shiny::tagList(
    # Filter controls in a compact flex row — each input sized to its content
    shiny::div(
      style = "display: flex; gap: 1rem; align-items: flex-end; flex-wrap: wrap;",
      shiny::selectInput(
        ns("year"),
        label = "Year",
        choices = sort(unique(rwb$year_n), decreasing = TRUE),
        selected = max(rwb$year_n, na.rm = TRUE),
        width = "90px"
      ),
      shiny::selectInput(
        ns("zone"),
        label = "Zone",
        choices = c("World", sort(as.character(unique(rwb$zone)))),
        selected = "World",
        width = "175px"
      ),
      shiny::uiOutput(ns("range_selector_ui")),
      shiny::radioButtons(
        ns("metric"),
        label = "Metric",
        choices = c("Score" = "score", "Rank" = "rank"),
        selected = "score",
        inline = TRUE
      )
    ),
    # Map visualization
    plotly::plotlyOutput(ns("map"), height = "600px")
  )
}

mapServer <- function(id, rwb) {
  shiny::moduleServer(id, function(input, output, session) {
    ns <- session$ns

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
          width = "150px"
        )
      } else {
        # Rank ranges: 7 tiers based on percentiles
        shiny::selectInput(
          ns("range_bin"),
          label = "Rank Range",
          choices = c(
            "All Ranks" = "all",
            "Rank 1" = "rank-1",
            "Top 2.5%" = "rank-2",
            "2.5% - 15%" = "rank-3",
            "15% - 85%" = "rank-4",
            "85% - 97.5%" = "rank-5",
            "Bottom 2.5%" = "rank-6",
            "Last Rank" = "rank-7"
          ),
          selected = "all",
          width = "200px"
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
    # Divides countries into 7 tiers:
    # 1: rank 1 (the best)
    # 2: top 2.5% (elite)
    # 3: next 12.5% (high performers)
    # 4: next 70% (bulk)
    # 5: next 12.5% (low performers)
    # 6: bottom 2.5% (critical)
    # 7: highest rank (the worst)
    bin_rank <- function(rank, max_rank) {
      p1 <- 1
      p2_5 <- max_rank * 0.025
      p15 <- max_rank * 0.15
      p85 <- max_rank * 0.85
      p97_5 <- max_rank * 0.975
      p100 <- max_rank

      dplyr::case_when(
        rank == 1 ~ "rank-1",
        rank <= p2_5 ~ "rank-2",
        rank <= p15 ~ "rank-3",
        rank <= p85 ~ "rank-4",
        rank <= p97_5 ~ "rank-5",
        rank <= p100 ~ "rank-6",
        TRUE ~ "rank-7"
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

      # Determine color scale and value column based on metric
      if (metric == "score") {
        z_values <- data$score
        z_min <- 0
        z_max <- 100
        colorscale <- "RdYlGn"
        reversescale <- TRUE
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
          data$zone
        )
      } else {
        # Rank metric: invert rank values so rank 1 (best) maps to high color intensity
        z_values <- max_rank - data$rank + 1
        z_min <- 1
        z_max <- max_rank
        colorscale <- "RdYlGn"
        reversescale <- TRUE
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
          data$zone
        )
      }

      # Build choropleth
      plotly::plot_geo(
        data,
        locations = ~iso,
        z = z_values,
        text = hovertext,
        hovertemplate = "%{text}<extra></extra>"
      ) |>
        plotly::add_trace(
          type = "choropleth",
          colorscale = colorscale,
          reversescale = reversescale,
          zmin = z_min,
          zmax = z_max,
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
            }
          ),
          marker = list(line = list(width = 0.5))
        ) |>
        plotly::layout(
          title = paste0(
            "Press Freedom ",
            stringr::str_to_title(metric),
            " – ",
            input$year
          ),
          geo = list(
            showland = TRUE,
            landcolor = "rgb(243, 243, 243)",
            coastcolor = "rgb(204, 204, 204)",
            countrywidth = 0.5,
            showocean = TRUE,
            oceancolor = "rgb(204, 229, 255)",
            projection = list(type = "natural earth")
          ),
          margin = list(l = 0, r = 0, t = 40, b = 0)
        )
    })

    # Display country detail in sidebar when a country is clicked
    output$country_detail <- shiny::renderUI({
      data <- map_data()

      # Try to extract clicked point from plotly event
      click_data <- plotly::event_data("plotly_click")

      if (is.null(click_data)) {
        shiny::p(
          "Click any country on the map to see details.",
          class = "text-muted"
        )
      } else {
        # Get the index of the clicked point
        idx <- click_data$pointNumber[1] + 1
        if (idx <= nrow(data)) {
          country_row <- data[idx, ]

          shiny::tagList(
            shiny::h5(country_row$country_en[[1]]),
            shiny::hr(),
            shiny::tags$table(
              class = "table table-sm",
              shiny::tags$tbody(
                shiny::tags$tr(
                  shiny::tags$td("Score"),
                  shiny::tags$td(shiny::strong(round(
                    country_row$score[[1]],
                    1
                  )))
                ),
                shiny::tags$tr(
                  shiny::tags$td("Rank"),
                  shiny::tags$td(shiny::strong(country_row$rank[[1]]))
                ),
                shiny::tags$tr(
                  shiny::tags$td("Zone"),
                  shiny::tags$td(country_row$zone[[1]])
                ),
                shiny::tags$tr(
                  shiny::tags$td("Political"),
                  shiny::tags$td(
                    if (!is.na(country_row$political_context[[1]])) {
                      round(country_row$political_context[[1]], 1)
                    } else {
                      "–"
                    }
                  )
                ),
                shiny::tags$tr(
                  shiny::tags$td("Economic"),
                  shiny::tags$td(
                    if (!is.na(country_row$economic_context[[1]])) {
                      round(country_row$economic_context[[1]], 1)
                    } else {
                      "–"
                    }
                  )
                ),
                shiny::tags$tr(
                  shiny::tags$td("Legal"),
                  shiny::tags$td(
                    if (!is.na(country_row$legal_context[[1]])) {
                      round(country_row$legal_context[[1]], 1)
                    } else {
                      "–"
                    }
                  )
                ),
                shiny::tags$tr(
                  shiny::tags$td("Social"),
                  shiny::tags$td(
                    if (!is.na(country_row$social_context[[1]])) {
                      round(country_row$social_context[[1]], 1)
                    } else {
                      "–"
                    }
                  )
                ),
                shiny::tags$tr(
                  shiny::tags$td("Safety"),
                  shiny::tags$td(
                    if (!is.na(country_row$safety[[1]])) {
                      round(country_row$safety[[1]], 1)
                    } else {
                      "–"
                    }
                  )
                )
              )
            )
          )
        } else {
          shiny::p(
            "Click any country on the map to see details.",
            class = "text-muted"
          )
        }
      }
    })
  })
}
