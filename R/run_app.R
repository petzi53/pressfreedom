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
    app_dir <- system.file("app", package = "pressfreedom")
    if (app_dir == "") {
        stop(
            "Could not find the app directory. Try re-installing pressfreedom.",
            call. = FALSE
        )
    }
    shiny::runApp(app_dir, ...)
}
