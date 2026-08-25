## inst/app/R/helpers.R
## Shared helper functions for the WPFI Shiny app.

# Note: has_ggbump() and has_flagon() have been removed.
# Both ggbump and flagon are now vendored directly (see LICENSE.note and AGENTS.md):
# - ggbump functions are in inst/app/R/geom_bump_vendored.R (pf_geom_bump, etc.)
# - flag-icons SVGs are in inst/app/www/flags/ (auto-served by Shiny)

#' Filter and prepare data for a chart
#'
#' @param df    The full rwb_standardized data frame.
#' @param var   Column name to select ("score" or "rank").
#' @param country Character vector of country names to include.
df_chart <- function(df, var, country) {
    # RSF changed its scoring methodology in 2013; pre-2013 scores use a different
    # non-comparable scale, so restrict score charts to the comparable era only
    min_year <- if (var == "score") 2013L else 1L
    
    # Dimension columns available only from 2022 onward
    dimensions <- c("political_context", "economic_context", "legal_context",
                    "social_context", "safety")
    
    df |>
        dplyr::filter(year_n >= min_year) |>
        dplyr::select(year_n, dplyr::all_of(var), dplyr::any_of(dimensions), 
                      country_en, iso) |>
        dplyr::filter(country_en %in% country) |>
        dplyr::arrange(year_n) |>
        # Drop rows only where the requested metric itself is NA (e.g. a
        # defunct historical state with rank but no score). Do NOT use a
        # blanket na.omit() here: the dimension columns are NA for every
        # year before 2022 by design (see AGENTS.md), and na.omit() across
        # all columns would silently drop all pre-2022 rows for every
        # chart/export, regardless of the requested var.
        dplyr::filter(!is.na(.data[[var]])) |>
        droplevels()
}

#' Build a card title string from variable, country selection, and year range
#'
#' @param var     "score", "rank", or a dimension variable
#' @param country Character vector of selected country names.
#' @param years   Numeric vector of years present in the filtered data.
card_title <- function(var, country, years = NULL) {
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
    countries  <- paste(country, collapse = ", ")
    year_range <- if (is.null(years) || length(years) == 0) {
        ""
    } else if (min(years) == max(years)) {
        paste("in", min(years))
    } else {
        paste("in", min(years), "\u2013", max(years))
    }
    paste(prefix, countries, year_range)
}

#' Generate dynamic CSV export caveats
#'
#' Inspects the actual exported data frame to determine which caveats apply
#' (methodology notes about score comparability, dimension availability, and 2011
#' data gap). Content-driven rather than view-specific, so the notes stay correct
#' if filtering changes later.
#'
#' @param df A data frame with optional year_n column and columns that may include
#'   "score", "rank", or dimension columns.
#' @param for_trends Logical: if TRUE, use Trends view-specific logic (skip score
#'   comparability note since Trends always starts at 2013+). Default FALSE.
#' @return Character vector of note strings (possibly empty).
csv_notes <- function(df, for_trends = FALSE) {
    notes <- character(0)

    # Score comparability note: RSF changed methodology in 2013
    # For Trends view, this is always moot since df_chart() filters to 2013+,
    # so skip it entirely.
    if (!for_trends && "score" %in% names(df)) {
        # Only add caveat if data actually spans the 2013 boundary
        years <- df$year_n
        if (!is.null(years) && min(years, na.rm = TRUE) <= 2012) {
            notes <- c(notes, paste(
                "Note: RSF changed its scoring methodology in 2013 -- score",
                "values from 2002-2012 are on a different, non-comparable",
                "scale to 2013-present scores. Do not average or compare",
                "scores across that boundary."
            ))
        }
    }

    # Dimension availability note: dimensions only available from 2022+
    dimension_cols <- c("political_context", "economic_context", "legal_context",
                        "social_context", "safety")
    if (any(dimension_cols %in% names(df))) {
        notes <- c(notes, paste(
            "Note: Context factors (political, economic, legal, social context,",
            "and safety) are not available (NA) before 2022."
        ))
    }

    # 2011 gap note: spans the year range without reaching 2011
    years <- df$year_n
    if (!is.null(years) && dplyr::n_distinct(years) > 1 &&
        min(years, na.rm = TRUE) <= 2010 && max(years, na.rm = TRUE) >= 2012) {
        notes <- c(notes, paste(
            "Note: 2011 has no published index and is absent from this",
            "data -- a gap in RSF's own release history, not a data-",
            "cleaning artifact."
        ))
    }

    notes
}

#' Write data frame to CSV with optional caveat comments
#'
#' Writes note lines (prefixed with #) followed by a blank line, then the CSV data.
#' Notes are readable in text editors and skippable by `read.csv(..., comment.char = "#")`.
#'
#' @param df A data frame to export.
#' @param con A file path (string) or file connection object.
#' @param notes Optional character vector of note lines. If NULL (default), auto-detects
#'   via csv_notes(). If provided, bypasses csv_notes() entirely.
#' @param for_trends Logical: passed to csv_notes() if notes=NULL. If TRUE, uses
#'   Trends-specific logic (e.g., skip score comparability note). Default FALSE.
write_csv_with_notes <- function(df, con, notes = NULL, for_trends = FALSE) {
    if (is.null(notes)) notes <- csv_notes(df, for_trends = for_trends)
    lines <- if (length(notes) > 0) c(paste0("# ", notes), "") else character(0)

    con_h <- file(con, open = "w")
    on.exit(close(con_h))

    if (length(lines) > 0) writeLines(lines, con_h)
    utils::write.csv(df, con_h, row.names = FALSE)
}
