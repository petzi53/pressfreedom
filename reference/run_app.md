# Launch the Press Freedom Dashboard

Opens the interactive Shiny dashboard for exploring Reporters Without
Borders (RWB) Press Freedom Index data. The dashboard lets users compare
country scores and rankings over time using line charts and bump charts.

## Usage

``` r
run_app(...)
```

## Arguments

- ...:

  Arguments passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html), such
  as `port` or `launch.browser`.

## Value

Called for its side effect (launching the app). Returns invisibly.

## Details

The dashboard has four tabs:

- **Map** — a choropleth of the world, colored by score, rank, or
  (2022+) dimension for a chosen year.

- **Trends** — multi-country line charts (Score) or bump charts (Rank)
  over 2002–2025.

- **Country** — a single country's profile: current/best/worst stats,
  score-band/rank-tier counts, and combined score/rank trend charts with
  dimension overlays.

- **About** — methodology, limitations, and citation information for the
  dashboard and its data.

A read-only version of this same dashboard is also deployed at
<https://petzi53.shinyapps.io/pressfreedom/>, useful for quick, casual
exploration without installing anything. Running it locally via
`run_app()` avoids that deployment's usage limits and is recommended for
repeated or heavier use.

This package does not bundle its own data; `run_app()` loads
[`rwb_standardized`](https://www.peter-baumgartner.net/pressfreedom.data/reference/rwb_standardized.html)
from the companion pressfreedom.data package at startup. To work with
that data directly (outside the dashboard) rather than through the app,
load pressfreedom.data and consult its documentation and vignettes at
<https://www.peter-baumgartner.net/pressfreedom.data/>, e.g.:

    library(pressfreedom.data)
    head(rwb_standardized)
    ?rwb_standardized

## See also

[`rwb_standardized`](https://www.peter-baumgartner.net/pressfreedom.data/reference/rwb_standardized.html)
for the underlying dataset's documentation.

## Examples

``` r
if (interactive()) {
  # Launch with defaults
  run_app()

  # Launch without opening a browser automatically, e.g. inside an
  # IDE's viewer pane or a remote session
  run_app(launch.browser = FALSE)

  # Pin a specific port, e.g. to satisfy a firewall rule
  run_app(port = 8080)
}
```
