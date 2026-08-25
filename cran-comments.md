# CRAN Submission: pressfreedom 0.1.1

## Test Environments
- macOS 13.x–26.x (arm64), R 4.6.1

## R CMD Check Results
- 0 errors
- 0 warnings
- 1 note: "Namespaces in Imports field not imported from" (pre-existing, expected)
  - This note reflects the package's structure: all visualization packages (`bslib`, `dplyr`, `plotly`, `ggplot2`, `htmlwidgets`, `RColorBrewer`, `countrycode`) are used only inside `inst/app/app.R` and module files (runtime-sourced scripts invisible to R CMD check's namespace scanner), not in the package's own `R/` code. This is by design for a package whose primary purpose is to provide a Shiny app rather than exported functions.

## Comments

This package provides an interactive Shiny dashboard for exploring the Reporters Without Borders Press Freedom Index dataset (2002–2026).

### Design & Dependencies

The package exports a single function, `run_app()`, which launches a Shiny dashboard. The dashboard's interactive features depend on visualization packages (`bslib`, `dplyr`, `plotly`, `ggplot2`, `htmlwidgets`, `RColorBrewer`, `countrycode`) listed in `Imports` because they are required at runtime and have no platform/CRAN barriers.

### Optional Enhancements: `ggbump` and `flagon`

Two GitHub-only packages are listed in `Suggests`:

- **`ggbump`** (GitHub: `davidsjoberg/ggbump`): Provides smooth "bump chart" lines for rank trends in the Trends and Country views. When unavailable, the app falls back to standard `ggplot2::geom_line()` (straight line segments between yearly rank points).

- **`flagon`** (GitHub: `coolbutuseless/flagon`): Provides country flag icons for the Map and Country views. When unavailable, the app renders without flag icons but remains fully functional.

**Graceful Degradation:** The app was architected (as of 2026-08-24) to degrade gracefully when either package is unavailable. Rather than crashing or throwing errors, missing visualizations are replaced with simpler alternatives:

1. **`inst/app/R/helpers.R`** defines `has_ggbump()` and `has_flagon()` helper functions that check for package availability via `requireNamespace(..., quietly = TRUE)`.

2. **`inst/app/app.R`** wraps the flag resource registration in a guard: `if (requireNamespace("flagon", quietly = TRUE)) { ... }`, preventing startup failure.

3. **`inst/app/R/flags.R`** — `flag_img_tag()` checks `has_flagon()` and returns `NULL` (no image) instead of building a broken-image tag when flagon is unavailable.

4. **`inst/app/R/mod_chart.R` and `inst/app/R/mod_country.R`** both check `has_ggbump()` and fall back to `geom_line()` when unavailable.

**Verified Behavior:** Live testing via headless browser automation with a restricted library (both packages excluded) confirmed the app launches, loads all three main views (Map, Trends, Country), and renders interactive charts without errors — with the graceful substitutions noted above.

**renv Detection:** Explicit `if (requireNamespace(...)) library(...)` calls in `inst/app/app.R` ensure `renv::dependencies()` correctly identifies these packages as used, even though they're in `Suggests`.

### Installation for CRAN Users

CRAN users installing this package via `install.packages("pressfreedom")` will not automatically receive the GitHub dependencies. To get the full experience (smooth bump charts, country flags), they can install via:

```r
remotes::install_github("petzi53/pressfreedom")
# or
pak::pak("petzi53/pressfreedom")
```

These tools automatically resolve GitHub packages listed in `Remotes:`.

Alternatively, users can use the browser-based dashboard without installing anything:  
https://pbaumgartner-pressfreedom.share.connect.posit.cloud/

### Data Dependency: `pressfreedom.data`

**`pressfreedom.data` (>= 0.2.0)** is listed in `Imports` and is now available on CRAN (as of August 2026). This companion package provides the cleaned, standardized `rwb_standardized` dataset, the core data source for the dashboard. For reproducibility and transparency, all data-cleaning logic is maintained in that separate package; this dashboard is the visualization layer only.

### Why This Approach?

- **Separation of concerns:** Data logic lives in `pressfreedom.data`; visualization logic lives in this package.
- **Reusability:** Other researchers can use the cleaned dataset directly via `library(pressfreedom.data)` without installing the Shiny app.
- **Annual updates:** When RSF publishes a new index each May, `pressfreedom.data` is updated with the new data; this package's dashboard automatically reflects those updates with no code changes needed (except for new dimension scores or methodological changes in RSF's scoring).

### Deployment

The dashboard is live at https://pbaumgartner-pressfreedom.share.connect.posit.cloud/ on Posit Connect Cloud. This CRAN submission makes the code available via CRAN and GitHub for reproducibility and local deployment; it does not change the live deployment.
