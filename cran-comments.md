# CRAN Submission: pressfreedom 0.2.0

## Test Environments

- R 4.6.1 on aarch64-apple-darwin23 (macOS Tahoe 26.5)

## R CMD Check Results

✔ **0 errors | 0 warnings | 0 notes**

All checks pass successfully.

## Comments

`pressfreedom` is a Shiny dashboard for exploring Reporters Without Borders Press Freedom Index data (2002–2026). It is a companion visualization package to `pressfreedom.data` (the authoritative dataset, now on CRAN).

### Vendored Dependencies

This submission includes two vendored dependencies with full MIT attribution (see `LICENSE.note`):

- **ggbump geometry functions** (`inst/app/R/geom_bump_vendored.R`): Vendored from the archived GitHub repository `jlbusch/ggbump` (commit fe6d5c7, main branch, 2025). Functions are prefixed with `pf_` (e.g., `pf_geom_bump()`) to avoid conflicts. This eliminates a dependency on an archived package. Rank-based bump charts now always use S-curve smoothing.

- **flag-icons SVGs** (`inst/app/www/flags/`): Vendored from `lipis/flag-icons` (v7.5.0, commit 086f7e97, 2026-05-29). A subset of ~270 SVG files corresponding to ISO 3166-1 alpha-2 codes present in the dataset are included. This upgrades from PNG-format flags (via the GitHub-only `flagon` wrapper) to crisper, smaller SVG assets and eliminates a GitHub-only package dependency.

Both components are properly attributed in `LICENSE.note`, which must be included with the distribution per the MIT license.

### All CRAN Dependencies

As of this submission, all packages in `Imports` are available from CRAN:

- `pressfreedom.data` (>= 0.3.0) — companion dataset package, published on CRAN as of August 20, 2026
- `shiny`, `bslib`, `dplyr`, `plotly`, `ggplot2`, `htmlwidgets`, `RColorBrewer`, `countrycode`, `tidyr`, `purrr` — all CRAN-available

The `Remotes:` field has been removed entirely; no GitHub overrides are needed.

### Design & Architecture

The package exports a single function, `run_app()`, which launches the Shiny dashboard. The dashboard has three main interactive views:

- **Map**: A choropleth colored by Press Freedom Score, Rank, or 2022+ dimension scores (filtered by year, zone, and band/tier selection).
- **Trends**: Multi-country line charts (Score) or bump charts (Rank) over 2002–2025, with client-side hover-dimming and click-to-navigate.
- **Country**: A single-country profile with stat tables, band/tier counts, and combined trend charts overlaying dimension scores (2022+) on score and rank trends.

All interactive behavior (hover-dimming, click-to-navigate) is handled client-side via JavaScript (`htmlwidgets::onRender`) to avoid timing issues with server round-trips.

### Data Separation

`pressfreedom.data` (imported) provides the cleaned, standardized `rwb_standardized` dataset. All data-cleaning logic is maintained in that separate package; this dashboard is the visualization layer only. This separation enables:

- **Reusability**: Other researchers can use the cleaned dataset directly without installing the Shiny app.
- **Annual updates**: When RSF publishes a new index each May, `pressfreedom.data` is updated with the new data; this package's dashboard automatically reflects those updates with no code changes needed (except for new dimension scores or methodological changes).

### Live Deployment

The dashboard is live at https://pbaumgartner-pressfreedom.share.connect.posit.cloud/ on Posit Connect Cloud. This CRAN submission makes the code available via CRAN and GitHub for reproducibility and local deployment.
