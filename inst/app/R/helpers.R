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
#' @param var     "score", "rank", or a dimension variable
#' @param country Character vector of selected country names.
card_title <- function(var, country) {
    prefix <- switch(var,
        "score" = "Global Score for",
        "rank" = "Global Rank for",
        "political_context" = "Political Context for",
        "economic_context" = "Economic Context for",
        "legal_context" = "Legal Context for",
        "social_context" = "Social Context for",
        "safety" = "Safety for",
        "Unknown for"
    )
    countries <- paste(country, collapse = ", ")
    paste(prefix, countries)
}
