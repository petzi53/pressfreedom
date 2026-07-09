## inst/app/R/helpers.R
## Shared helper functions for the WPFI Shiny app.

#' Filter and prepare data for a chart
#'
#' @param df    The full rwb data frame.
#' @param var   Column name to select ("score" or "rank").
#' @param country Character vector of country names to include.
df_chart <- function(df, var, country) {
    df |>
        dplyr::select(year_n, dplyr::all_of(var), country_en, iso) |>
        dplyr::filter(country_en %in% country) |>
        dplyr::arrange(year_n) |>
        stats::na.omit() |>
        droplevels()
}

#' Build a card title string from variable and country selection
#'
#' @param var     "score" or "rank"
#' @param country Character vector of selected country names.
card_title <- function(var, country) {
    prefix <- if (var == "score") "Global Score for" else "Global Rank for"
    countries <- paste(country, collapse = ", ")
    paste(prefix, countries)
}
