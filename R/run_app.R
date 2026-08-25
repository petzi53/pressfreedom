#' Launch the Press Freedom Dashboard
#'
#' Opens the interactive Shiny dashboard for exploring Reporters Without
#' Borders (RWB) Press Freedom Index data. The dashboard lets users compare
#' country scores and rankings over time using line charts and bump charts.
#'
#' The dashboard has four tabs:
#' \itemize{
#'   \item \strong{Map} — a choropleth of the world, colored by score, rank,
#'     or (2022+) dimension for a chosen year.
#'   \item \strong{Trends} — multi-country line charts (Score) or bump
#'     charts (Rank) over 2002–2025.
#'   \item \strong{Country} — a single country's profile: current/best/worst
#'     stats, score-band/rank-tier counts, and combined score/rank trend
#'     charts with dimension overlays.
#'   \item \strong{About} — methodology, limitations, and citation
#'     information for the dashboard and its data.
#' }
#'
#' A read-only version of this same dashboard is also deployed at
#' \url{https://petzi53.shinyapps.io/pressfreedom/}, useful for quick,
#' casual exploration without installing anything. Running it locally via
#' `run_app()` avoids that deployment's usage limits and is recommended
#' for repeated or heavier use.
#'
#' This package does not bundle its own data; `run_app()` loads
#' \code{\link[pressfreedom.data]{rwb_standardized}} from the companion
#' \pkg{pressfreedom.data} package at startup. To work with that data
#' directly (outside the dashboard) rather than through the app, load
#' \pkg{pressfreedom.data} and consult its documentation and vignettes at
#' \url{https://www.peter-baumgartner.net/pressfreedom.data/}, e.g.:
#'
#' ```r
#' library(pressfreedom.data)
#' head(rwb_standardized)
#' ?rwb_standardized
#' ```
#'
#' @param ... Arguments passed to [shiny::runApp()], such as `port` or
#'   `launch.browser`.
#'
#' @return Called for its side effect (launching the app). Returns invisibly.
#'
#' @seealso
#' \code{\link[pressfreedom.data]{rwb_standardized}} for the underlying
#' dataset's documentation.
#'
#' @importFrom bslib page_navbar card navset_hidden
#' @importFrom countrycode countrycode
#' @importFrom dplyr filter arrange desc mutate select
#' @importFrom ggplot2 ggplot aes geom_bar geom_point geom_line scale_y_reverse theme element_text
#' @importFrom htmlwidgets onRender
#' @importFrom plotly plot_ly add_trace layout subplot style config ggplotly
#' @importFrom purrr map
#' @importFrom RColorBrewer brewer.pal
#' @importFrom tidyr pivot_longer
#'
#' @export
#'
#' @examples
#' if (interactive()) {
#'   # Launch with defaults
#'   run_app()
#'
#'   # Launch without opening a browser automatically, e.g. inside an
#'   # IDE's viewer pane or a remote session
#'   run_app(launch.browser = FALSE)
#'
#'   # Pin a specific port, e.g. to satisfy a firewall rule
#'   run_app(port = 8080)
#' }
run_app <- function(...) {
    # pressfreedom.data is a hard dependency (Imports), but only used inside
    # inst/app/app.R, a runtime-sourced script invisible to R CMD check's
    # "all declared Imports should be used" scan. This guard is both a real
    # pre-flight check and what satisfies that scan.
    if (!requireNamespace("pressfreedom.data", quietly = TRUE)) {
        stop(
            "Package 'pressfreedom.data' is required to run this app. ",
            "Install it first.",
            call. = FALSE
        )
    }

    app_dir <- system.file("app", package = "pressfreedom")
    if (app_dir == "") {
        stop(
            "Could not find the app directory. Try re-installing pressfreedom.",
            call. = FALSE
        )
    }
    shiny::runApp(app_dir, ...)
}
