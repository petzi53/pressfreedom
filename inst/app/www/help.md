This dashboard shows press freedom trends from the Reporters Without Borders (RSF) World Press Freedom Index. Use the tabs at the top to explore different views, and the panel on the left to filter. This page explains how to navigate and use the interface.

## Navigating the dashboard

The dashboard has four data views plus this Help tab and an About tab:

- **Map** — a world view for a single year, colored by press freedom score, rank, or context dimensions. Use the sidebar to pick the year, region, metric, and which score bands (or rank tiers) to display.
- **Trends** — compare multiple countries over time using either line charts (Score) or bump charts (Rank). Select countries in the sidebar and watch how they evolve from 2002 to 2026.
- **Country** — a single country's full profile: rank and score statistics, score-band and rank-tier distributions, and combined trend charts (Score and Rank, overlaid with context dimensions for 2022–2026).
- **Help** — this page.
- **About** — data sources, methodology, limitations, and how to cite.

**Clicking a country** on the Map or on a point in a Trends chart jumps directly to that country's profile.

**Clear** button (on each sidebar) resets that tab's filters only. The **Reset all** button (top right) clears all filters everywhere and returns to the Map.

## Reading the charts

All charts in this dashboard are interactive:

- **Hover** over a point, line, or area to see a tooltip with the country name, year, and value.
- **Click** a data point on the Map or a Trends chart to jump to that country's profile.
- **Legend** — click a country or dimension name in the legend to hide or isolate that series. Click again to show it.

On the **Trends** tab, hovering over one country's line automatically dims the others, so it's easier to follow a single series in a crowded chart.

## The chart toolbar

Hovering near the **top-right corner** of any chart reveals a small row of icons (the Plotly toolbar). These are optional — you don't need them to read the dashboard — but they're useful for zooming in on a busy chart or saving an image.

The most useful buttons, from left to right:

- **Camera icon** — Download the current view of this chart as a PNG image file.
- **Box select / zoom icons** — Click and drag to zoom into a region of the chart. Use the zoom in (+) and zoom out (−) buttons to step in fixed increments. Note: the Map view has a different zoom style (single zoom button) since it shows a globe.
- **Pan icon (hand or cross-arrows)** — Drag the chart without zooming (for moving around after you've zoomed in).
- **Autoscale icon (diagonal arrows)** — Rescale the axes to fit the data currently visible on screen.
- **House / reset icon** — Reset the chart back to its original view, undoing any zooming or panning you've done.

Other icons may also appear (e.g., "compare data on hover", spike lines); explore them if curious, but the five above cover 95% of real use cases.

## Downloading data

Each of the Map, Trends, and Country tabs has a **Download CSV** button in the sidebar, below the "Clear" button. It exports exactly what's currently displayed — the filtered slice, not the entire dataset.

**Important: the file starts with notes, not data.**

The downloaded CSV begins with 1–3 comment lines (starting with `#`), which describe the export (e.g., caveats about data methodology or score comparability). These are **not part of the data table** — they're explanatory notes.

> The real **column headers appear several rows down** (row 3 or 4, depending on the file), **not at row 1**.

Most spreadsheet programs (Excel, Google Sheets, LibreOffice) will open the file fine and may even skip the `#` lines automatically, but you may need to scroll down a bit to see the actual data table. If you're using R, you can skip the comment lines automatically:

```r
readr::read_csv("pressfreedom_trends_score_austria.csv", comment = "#")
```

The `comment = "#"` parameter tells `readr` to ignore any line starting with `#`, so the header row is read directly into column names.

## Frequently asked questions

**Why do some years have no data for certain countries?**

There are two main reasons:

1. **2011 has no published index** — RSF did not release an index for 2011, so that year is entirely absent from the dataset. This is a genuine gap in RSF's own release history, not a data error.
2. **Some context dimensions exist only from 2022 onward** — Political, Economic, Legal, and Social context scores, plus Safety scores, were introduced in 2022. If you filter to a dimension and then switch years, you'll see only 2022–2026; pre-2022 data is not available for those metrics.

**Why can't I select certain years and metrics together?**

The dashboard enforces this automatically: dimensions (Political Context, Economic Context, etc.) only exist from 2022 onward, so picking a dimension metric restricts the year list to 2022–2026. Conversely, selecting a pre-2022 year removes dimension metrics from the available choices on the Map. This prevents you from accidentally requesting data that doesn't exist.

**Why does the score look different before and after 2013?**

RSF changed its scoring methodology in 2013, so **scores from 2002–2012 and 2013–2026 are not directly comparable** — they're on two different scales. The dashboard shows both eras (so you can see long-term trends), but any aggregate (average, min, max) that spans the 2013 boundary will be misleading. The Trends tab restricts Score to 2013 onward for this reason.

**Can I use this data for my own research or analysis?**

Yes! All data comes from the Reporters Without Borders (RSF) World Press Freedom Index. See the **About** tab for how to cite RSF correctly. If you want to work with the data in R directly (without the web interface), you can install the [`pressfreedom.data` R package](https://www.peter-baumgartner.net/pressfreedom.data/index.html), which provides the underlying dataset and full documentation of the data pipeline and any quirks. The `pressfreedom` package (which runs this dashboard) also has source code and documentation on [GitHub](https://github.com/petzi53/pressfreedom).

**I found a bug or have a question about the data.**

[Open an issue on GitHub](https://github.com/petzi53/pressfreedom/issues). Include as much detail as you can (which view, what filters you applied, what you expected to see, what you actually saw).
