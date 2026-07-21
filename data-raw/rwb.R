## Prepare the `rwb` dataset for the pressfreedom package.
##
## The full data acquisition and cleaning pipeline is documented in the
## rwb-book Quarto book:
##   011-get-rwb-data.qmd  – RWB Press Freedom Index download and cleaning
##   012-get-m49-data.qmd  – UN M49 country classification
##   031-consolidate.qmd   – merging and final standardisation (2022–2025)
##
## Run this script whenever a new RWB index is published (typically May).
## After running, the updated rwb.rda in data/ is ready for the package.
##
## Annual update checklist:
##   1. Add the new year's raw RWB file to data/chap011/rsf/ in rwb-book.
##   2. Run the book chapters above to produce the updated cleaned files.
##   3. Update the source path below if the file location changed.
##   4. Source this script.
##   5. Increment the package version: usethis::use_version().

# Source: cleaned dataset produced by the rwb-book pipeline.
# Adjust the path if rwb-book lives elsewhere on your system.
rwb_book_path <- here::here(
  "../rwb-book/data/chap011/rwb/rwb.rds"
)

rwb <- readRDS(rwb_book_path)

# Ensure these are plain character vectors, not factors. Factor levels from
# the source data have previously caused coercion bugs downstream (e.g. in
# case_when() comparisons and Shiny select inputs).
rwb <- rwb |>
  dplyr::mutate(
    country_en = as.character(country_en),
    zone = as.character(zone),
    iso = as.character(iso)
  )

# COUNTRY NAME CORRECTION: Normalize country names for consistency.
# - 2023–2025: "Russia" → "Russian Federation" (for consistency with 2002–2022)
rwb <- rwb |>
  dplyr::mutate(
    country_en = dplyr::case_when(
      year_n >= 2023 & country_en == "Russia" ~ "Russian Federation",
      TRUE ~ country_en
    )
  )

# 2022 ZONE CORRECTION: In 2022, RWB used non-standard zone classifications
# ("Europe - Asie centrale" and "Maghreb - Moyen-Orient"). These appear only in 2022
# and do not align with historical classifications used in all other years.
# Reassign these to match the traditional zones used in other years:
#   - "Europe - Asie centrale" → "UE Balkans" (40 countries) or "EEAC" (13 countries)
#   - "Maghreb - Moyen-Orient" → "MENA" (19 countries)
# This ensures zone homogeneity across the entire time series.
# See: https://github.com/petzi/pressfreedom/issues/[ISSUE_NUMBER]
rwb <- rwb |>
  dplyr::mutate(
    zone = dplyr::case_when(
      # European/Balkan countries (traditionally "UE Balkans")
      year_n == 2022 & zone == "Europe - Asie centrale" & country_en %in% c(
        "Albania", "Andorra", "Austria", "Belgium", "Bosnia and Herzegovina",
        "Bulgaria", "Croatia", "Cyprus", "Cyprus North", "Czech Republic",
        "Denmark", "Estonia", "Finland", "France", "Germany", "Greece",
        "Hungary", "Iceland", "Ireland", "Italy", "Kosovo", "Latvia",
        "Liechtenstein", "Lithuania", "Luxembourg", "Malta", "Montenegro",
        "Netherlands", "North Macedonia", "Norway", "Poland", "Portugal",
        "Romania", "Serbia", "Slovakia", "Slovenia", "Spain", "Sweden",
        "Switzerland", "United Kingdom"
      ) ~ "UE Balkans",
      # Central Asian/Eastern European countries (traditionally "EEAC")
      year_n == 2022 & zone == "Europe - Asie centrale" & country_en %in% c(
        "Armenia", "Azerbaijan", "Belarus", "Georgia", "Kazakhstan",
        "Kyrgyzstan", "Moldova", "Russian Federation", "Tajikistan",
        "Turkey", "Turkmenistan", "Ukraine", "Uzbekistan"
      ) ~ "EEAC",
      # Maghreb and Middle Eastern countries (traditionally "MENA")
      year_n == 2022 & zone == "Maghreb - Moyen-Orient" ~ "MENA",
      # Keep all other assignments unchanged
      TRUE ~ zone
    )
  )

# Verify the dataset looks as expected before saving.
stopifnot(
  is.data.frame(rwb),
  "year_n" %in% names(rwb),
  "country_en" %in% names(rwb)
)

usethis::use_data(rwb, overwrite = TRUE)
