## The functions under test (iso3_to_flag_code(), rsf_band(), rank_tier())
## are pure helpers defined in inst/app/R/, sourced at runtime by the Shiny
## app rather than exported from the package namespace. Source them directly
## so tests can call them without spinning up the app.
app_r_dir <- system.file("app", "R", package = "pressfreedom")
if (!nzchar(app_r_dir)) {
  # Package not installed (e.g. devtools::test() on source tree)
  app_r_dir <- testthat::test_path("..", "..", "inst", "app", "R")
}

source(file.path(app_r_dir, "flags.R"), local = FALSE)
source(file.path(app_r_dir, "mod_map.R"), local = FALSE)
source(file.path(app_r_dir, "helpers.R"), local = FALSE)
