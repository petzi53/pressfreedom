## Prepare the `rwb` dataset for the pressfreedom package.
##
## The full data acquisition and cleaning pipeline is documented in the
## pressfreedom.data package:
##   Phase A: Download raw CSV files from Reporters Sans Frontières
##   Phase B: Normalize column names and structure across periods
##   Phase C: Combine all periods into a single dataset
##   Phase D: Standardize country names and ISO codes
##
## All data cleaning, corrections, and standardizations are handled
## in pressfreedom.data (Phase A–D pipeline).
##
## Run this script whenever pressfreedom.data is updated (typically when
## a new RWB index is published in May).
##
## Annual update checklist:
##   1. Update pressfreedom.data with new RWB index
##   2. Run pressfreedom.data::source("data-raw/rwb_standardized.R")
##   3. Update pressfreedom.data version if needed
##   4. Update pressfreedom dependency version in DESCRIPTION
##   5. Source this script to rebuild rwb.rda
##   6. Test pressfreedom app thoroughly
##   7. Increment pressfreedom package version: usethis::use_version()

# Load standardized data from pressfreedom.data package
rwb <- pressfreedom.data::rwb_standardized

# Ensure character types (defensive coding)
rwb <- rwb |>
  dplyr::mutate(
    iso = as.character(iso),
    country_en = as.character(country_en),
    zone = as.character(zone)
  )

# Verify the dataset looks as expected before saving.
stopifnot(
  is.data.frame(rwb),
  nrow(rwb) > 0,
  "year_n" %in% names(rwb),
  "country_en" %in% names(rwb),
  "iso" %in% names(rwb),
  "zone" %in% names(rwb),
  "score" %in% names(rwb),
  "rank" %in% names(rwb)
)

usethis::use_data(rwb, overwrite = TRUE)
