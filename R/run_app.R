#' Launch the Press Freedom Dashboard
#'
#' Opens the interactive Shiny dashboard for exploring Reporters Without
#' Borders (RWB) Press Freedom Index data. The dashboard lets users compare
#' country scores and rankings over time using line charts and bump charts.
#'
#' @param ... Arguments passed to [shiny::runApp()], such as `port` or
#'   `launch.browser`.
#'
#' @return Called for its side effect (launching the app). Returns invisibly.
#' @export
#'
#' @examples
#' if (interactive()) {
#'   run_app()
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
