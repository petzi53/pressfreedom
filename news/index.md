# Changelog

## pressfreedom 0.1.0

Initial release.

- Shiny dashboard for exploring the Reporters Without Borders (RSF)
  Press Freedom Index (2002–2025), with four views: Map, Trends,
  Country, and About.
- Data is loaded live from the companion package
  [`pressfreedom.data`](https://www.peter-baumgartner.net/pressfreedom.data/index.html)
  rather than bundled, so the dashboard always reflects the latest
  release of the cleaned dataset.
- [`run_app()`](https://www.peter-baumgartner.net/pressfreedom/reference/run_app.md)
  launches the dashboard locally; the same app code is also deployed
  read-only at <https://petzi53.shinyapps.io/pressfreedom/>.
