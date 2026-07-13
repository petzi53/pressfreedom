## inst/app/R/mod_country.R
## Country profile module: time-series charts for a single country across all dimensions

countrySidebarUI <- function(id, rwb) {
    ns <- shiny::NS(id)
    shiny::selectInput(
        ns("country"),
        label = "Select country",
        choices = sort(unique(rwb$country_en)),
        selected = sort(unique(rwb$country_en))[1]
    )
}

countryMainUI <- function(id) {
    ns <- shiny::NS(id)
    shiny::tagList(
        shiny::uiOutput(ns("country_header")),
        bslib::card(
            height = "calc(100vh - 155px)",
            bslib::card_header("Dimensions Overview (2022–Present)"),
            shiny::plotOutput(ns("plot_overview"), height = "100%")
        )
    )
}

countryServer <- function(id, rwb) {
    shiny::moduleServer(id, function(input, output, session) {
        ns <- session$ns

        # Define the dimensions we care about
        dim_cols <- c("score", "political_context", "economic_context", 
                      "legal_context", "social_context", "safety")
        
        # Clean names for labels ("Law" padded to match width of longer labels)
        dim_labels <- c(
            "score" = "Global Score",
            "political_context" = "Politics",
            "economic_context" = "Economy",
            "legal_context" = "Law      ",
            "social_context" = "Society",
            "safety" = "Safety"
        )

        # Dynamic header
        output$country_header <- shiny::renderUI({
            shiny::tags$h3(
                card_title("score", input$country),
                class = "mb-0"
            )
        })

        # Overview Plot: All dimensions in one (2022 onwards)
        output$plot_overview <- shiny::renderPlot({
            # Get all data for this country at once, filtering to 2022+
            data_long <- rwb |>
                dplyr::filter(country_en == input$country, year_n >= 2022) |>
                tidyr::pivot_longer(
                    cols = dplyr::all_of(dim_cols),
                    names_to = "dimension",
                    values_to = "value"
                ) |>
                dplyr::mutate(dimension = factor(dimension, levels = dim_cols))

            if (nrow(data_long) == 0) {
                return(plotly::plot_ly() |>
                         plotly::layout(title = "No data available"))
            }

            # Create color mapping: colorblind-friendly palette
            # Uses Okabe-Ito palette which is distinguishable for all types of colorblindness
            # Global Score is black and thicker; other dimensions use colors
            color_map <- c(
                "score" = "#000000",           # Black (Global Score - de-emphasized)
                "political_context" = "#0072B2",   # Blue
                "economic_context" = "#D55E00",    # Red-orange
                "legal_context" = "#009E73",       # Green
                "social_context" = "#CC79A7",      # Pink
                "safety" = "#56B4E9"                # Light blue
            )

            # Line width mapping: Global Score is thicker
            linewidth_map <- c(
                "score" = 1.5,
                "political_context" = 1,
                "economic_context" = 1,
                "legal_context" = 1,
                "social_context" = 1,
                "safety" = 1
            )

            # Get start and end values for labeling
            data_labels_start <- data_long |>
                dplyr::group_by(dimension) |>
                dplyr::filter(year_n == min(year_n)) |>
                dplyr::ungroup() |>
                dplyr::mutate(
                    label_type = "start",
                    label_hjust = 1.1,
                    label_nudge = -0.3
                )

            data_labels_end <- data_long |>
                dplyr::group_by(dimension) |>
                dplyr::filter(year_n == max(year_n)) |>
                dplyr::ungroup() |>
                dplyr::mutate(
                    label_type = "end",
                    label_hjust = -0.1,
                    label_nudge = 0.3
                )

            data_labels <- dplyr::bind_rows(data_labels_start, data_labels_end)

            p <- ggplot2::ggplot(data_long, ggplot2::aes(
                    x = year_n, 
                    y = value, 
                    color = dimension, 
                    linetype = dimension
                )) +
                ggplot2::geom_line(ggplot2::aes(linewidth = dimension)) +
                ggplot2::geom_point(size = 1.5) +
                ggplot2::scale_color_manual(values = color_map) +
                ggplot2::scale_linewidth_manual(values = linewidth_map) +
                ggplot2::scale_linetype_manual(values = c(1, 2, 3, 4, 5, 6)) +
                ggplot2::theme_minimal(base_size = 20) +
                ggplot2::labs(x = NULL, y = "Index Value") +
                ggplot2::theme(
                    legend.position = "none",
                    axis.text  = ggplot2::element_text(face = "bold"),
                    axis.title = ggplot2::element_text(face = "bold")
                )

            p +
                ggplot2::scale_x_continuous(
                    expand = ggplot2::expansion(mult = 0.25)
                ) +
                # Start-of-line labels: right-aligned, nudged left
                ggrepel::geom_label_repel(
                    data = data_labels_start,
                    ggplot2::aes(label = dim_labels[dimension], fill = dimension),
                    color = "white",
                    fontface = "bold",
                    size = 5,
                    label.size = 0.2,
                    label.padding = ggplot2::unit(0.3, "lines"),
                    direction = "y",
                    force = 0.5,
                    hjust = 1,
                    nudge_x = -0.2,
                    segment.size = 0.4,
                    segment.alpha = 0.6,
                    show.legend = FALSE
                ) +
                # End-of-line labels: left-aligned, nudged right
                ggrepel::geom_label_repel(
                    data = data_labels_end,
                    ggplot2::aes(label = dim_labels[dimension], fill = dimension),
                    color = "white",
                    fontface = "bold",
                    size = 5,
                    label.size = 0.2,
                    label.padding = ggplot2::unit(0.3, "lines"),
                    direction = "y",
                    force = 0.5,
                    hjust = 0,
                    nudge_x = 0.2,
                    segment.size = 0.4,
                    segment.alpha = 0.6,
                    show.legend = FALSE
                ) +
                ggplot2::scale_fill_manual(values = color_map, guide = "none")
        })
    })
}
