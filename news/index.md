# Changelog

## pressfreedom 0.2.0 (2026-08-25)

### Breaking changes

None. This is a maintainability and CRAN-preparation release.

### Major changes

- **Vendored ggbump geometry functions**
  (`inst/app/R/geom_bump_vendored.R`) to replace the GitHub-only
  dependency on `jlbusch/ggbump` (archived from CRAN 2025-12-04).
  Functions are prefixed with `pf_` (e.g., `pf_geom_bump()`,
  `PfStatBump`) to avoid conflicts. Rank-based bump charts now always
  use S-curve smoothing; the conditional fallback to `geom_line()` has
  been removed.

- **Vendored flag-icons SVGs** (`inst/app/www/flags/`) to replace the
  GitHub-only `flagon` package. A curated subset of ~270 SVG files from
  `lipis/flag-icons` v7.5.0 corresponding to ISO 3166-1 alpha-2 codes in
  the dataset are now served directly. This eliminates a GitHub-only
  dependency and provides crisper, smaller-file-size flags than the
  previous PNG-format approach.

- **Removed all GitHub-only dependencies**: `DESCRIPTION`’s `Imports`,
  `Suggests`, and `Remotes:` fields are now clean. All packages are
  available from CRAN.

- **Updated documentation**: Comprehensive updates to `AGENTS.md`
  documenting vendoring rationale, attribution, and the finalized app
  architecture.

- **Added `LICENSE.note`**: Full MIT attribution for vendored `ggbump`
  and `flag-icons` components.

### Minor changes

- `DESCRIPTION`: Version → 0.2.0, Date → 2026-08-25
- `flags.R`: Updated to use `.svg` extension instead of `.png`
- `app.R`: Removed library calls and resource path registrations for
  `ggbump` and `flagon`
- `mod_chart.R` and `mod_country.R`: Now call `pf_geom_bump()` directly
  without conditional fallback
- `helpers.R`: Removed `has_ggbump()` and `has_flagon()` utility
  functions
- Test suite: Updated to expect `.svg` file extension
- `renv.lock`: Refreshed to reflect removal of GitHub-only dependencies

### Testing

- R CMD check: 0 errors, 0 warnings, 0 notes
- All unit tests pass

### Acknowledgments

Vendored dependencies: - `ggbump` functions adapted from
[jlbusch/ggbump](https://github.com/jlbusch/ggbump), copyright © 2023
Jake L. Busch, licensed under MIT - Flag SVGs from
[lipis/flag-icons](https://github.com/lipis/flag-icons), copyright ©
2013–2024 Lipis, licensed under MIT

Full license texts included in `LICENSE.note`.

------------------------------------------------------------------------

## pressfreedom 0.1.0 (2026-08-03)

Initial release.

- Shiny dashboard for exploring the Reporters Without Borders (RSF)
  Press Freedom Index (2002–2025), with Map, Trends, Country, and About
  views.
- Data is loaded live from the companion package
  [`pressfreedom.data`](https://github.com/petzi53/pressfreedom.data)
  rather than bundled, so the dashboard always reflects the latest
  release of the cleaned dataset.
- [`run_app()`](https://www.peter-baumgartner.net/pressfreedom/reference/run_app.md)
  launches the dashboard locally; deployed at
  <https://pbaumgartner-pressfreedom.share.connect.posit.cloud/> on
  Posit Connect Cloud.
