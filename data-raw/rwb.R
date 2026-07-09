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

# Verify the dataset looks as expected before saving.
stopifnot(
  is.data.frame(rwb),
  "year_n" %in% names(rwb),
  "country_en" %in% names(rwb)
)

usethis::use_data(rwb, overwrite = TRUE)
