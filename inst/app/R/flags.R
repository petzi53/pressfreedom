## inst/app/R/flags.R
## Flag helpers: map rwb's 3-letter `iso` codes to flagon's 2-letter codes
## and build <img> tags for rendering.
##
## flagon::flags() is indexed by ISO 3166-1 alpha-2 codes; rwb$iso is
## alpha-3 and is not a clean 1:1 country mapping (see AGENTS.md). This
## file resolves the standard cases via countrycode and overrides the
## known non-standard/ambiguous ones by hand rather than guessing.

# Manual overrides for iso3 codes that countrycode::countrycode() cannot
# resolve to a standard ISO 3166-1 alpha-2 code (verified against
# flagon::country_codes during implementation):
#   - Kosovo (XKX, XKO): flagon has "xk" -> mapped
#   - Northern Cyprus (CTU): no ISO flag code exists -> no flag
#   - OECS (CSS, XCD): a regional organization, not a country -> no flag
#   - Israel territory splits (ISR1/2/3): no single national flag applies
#     unambiguously -> no flag
#   - United States territory splits (USA1, USA2, USA_I): unambiguously
#     the United States (unlike the Israel splits above) -> mapped to "us"
#   - Defunct historical states (YUG, SCG): no flag in flagon's source
#     -> no flag
flag_overrides <- c(
  XKX   = "xk",
  XKO   = "xk",
  CTU   = NA_character_,
  CSS   = NA_character_,
  XCD   = NA_character_,
  ISR1  = NA_character_,
  ISR2  = NA_character_,
  ISR3  = NA_character_,
  USA1  = "us",
  USA2  = "us",
  USA_I = "us",
  YUG   = NA_character_,
  SCG   = NA_character_
)

#' Convert rwb's 3-letter iso codes to flagon's 2-letter flag codes
#'
#' @param iso3 Character vector of `rwb$iso` values.
#' @return Character vector of lowercase 2-letter codes suitable for
#'   `flagon::flags()`, or `NA` where no sensible flag exists.
iso3_to_flag_code <- function(iso3) {
  overridden <- unname(flag_overrides[iso3])
  missing <- is.na(overridden)
  if (any(missing)) {
    overridden[missing] <- tolower(
      countrycode::countrycode(iso3[missing], "iso3c", "iso2c", warn = FALSE)
    )
  }
  overridden
}

#' Emoji-flag fallback for contexts that can't render `<img>`
#'
#' Plotly hover labels only support a small HTML subset (`<b>`, `<br>`,
#' `<i>`, ...) and do not reliably render `<img>` tags across renderers, so
#' the map tooltip uses this Unicode regional-indicator emoji instead of
#' `flag_img_tag()`. Falls back to `""` (no emoji) where no sensible flag
#' exists, same as `flag_img_tag()`.
#'
#' @param iso3 Character vector of `rwb$iso` values.
#' @return Character vector of emoji flags (or `""` where unavailable).
flag_emoji <- function(iso3) {
  code <- iso3_to_flag_code(iso3)
  vapply(code, function(cc) {
    if (is.na(cc)) return("")
    chars <- strsplit(toupper(cc), "")[[1]]
    if (length(chars) != 2) return("")
    paste0(
      intToUtf8(utf8ToInt(chars[1]) - utf8ToInt("A") + 0x1F1E6),
      intToUtf8(utf8ToInt(chars[2]) - utf8ToInt("A") + 0x1F1E6)
    )
  }, character(1), USE.NAMES = FALSE)
}

#' Build an `<img>` tag for a country's flag
#'
#' Assumes `shiny::addResourcePath("flags", ...)` has been called once at
#' app startup (see app.R). Falls back to `NULL` (no image) rather than a
#' broken image when no sensible flag exists.
#'
#' @param iso3   A single `rwb$iso` value.
#' @param alt    Alt text for the image (defaults to `iso3`).
#' @param height CSS height for the image.
flag_img_tag <- function(iso3, alt = iso3, height = "1em") {
  code <- iso3_to_flag_code(iso3)
  if (is.na(code)) return(NULL)
  shiny::tags$img(
    src = paste0("flags/", code, ".png"),
    alt = alt,
    style = paste0(
      "height: ", height, "; width: auto; ",
      "vertical-align: middle; margin-right: 0.3em;"
    )
  )
}
