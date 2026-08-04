This application uses data processed via the `pressfreedom.data` R package. While the raw data is sourced from [Reporters Sans Frontieres (RSF)](https://rsf.org/en/index), the cleaning and transformation logic is maintained in the [pressfreedom.data](https://www.peter-baumgartner.net/pressfreedom.data/index.html) package to ensure reproducibility and ease of use for researchers.

While this Shiny application provides an interactive overview of press freedom trends, researchers requiring more intensive data exploration can install the [pressfreedom R package](https://github.com/petzi53/pressfreedom) to run the application locally. This avoids shinyapps.io usage limits and provides a more seamless experience for heavy data exploration and analysis.

## Data & Methodology

- **Score** (0–100): RSF's overall press freedom score, classified here into five bands — Good (85–100), Satisfactory (70–85), Problematic (55–70), Difficult (40–55), Serious (0–40).

- **Rank**: ordinal position among all countries that year, grouped here into percentile tiers (Top 2.5%, 2.5%–15%, 15%–85%, 85%–97.5%, Bottom 2.5%) rather than score bands, since rank is a relative ordering within a single year rather than a fixed 0–100 scale.

- **Dimension scores** (Political, Economic, Legal, Social, Safety context): sub-components of the overall score, available from 2022 onward only.

- The `pressfreedom.data` package assembles, cleans, and standardizes RSF's yearly data releases (2002–present) into one tidy, analysis-ready dataset. See its [pkgdown site](https://www.peter-baumgartner.net/pressfreedom.data/index.html) for full documentation.

- For RSF's own scoring methodology, see their [methodology page](https://rsf.org/en/methodology-used-compiling-world-press-freedom-index-2026).

## Limitations & Caveats

- RSF changed its scoring methodology in 2013 — `score` (and, from 2022 on, the dimension scores) are not directly comparable across the 2002–2012 / 2013–present boundary. The Map and Trends views restrict Score to 2013 onward accordingly.

- 2011 has no published index — a genuine gap in RSF's own release history, not a data-cleaning artifact.

- Dimension scores exist for only four years so far (2022–present).

- Country names and ISO codes have shifted over 24 years of RSF releases (renames, territorial variants, defunct states); see [`pressfreedom.data`'s documentation](https://www.peter-baumgartner.net/pressfreedom.data/index.html) for how these are standardized.

- The index reflects an expert- and correspondent-based assessment methodology, which may entail uneven reporting depth across regions.

## Citation & Contact

**How to cite:**

The underlying Press Freedom Index data is produced by RSF and is not covered by the package citations above — please also cite RSF directly when using the data itself, e.g. "Reporters Without Borders (RSF), World Press Freedom Index, https://rsf.org/en/index".

**Contact & support:**

Found a bug, or have a question about the data? [Open an issue on GitHub](https://github.com/petzi53/pressfreedom/issues).

**Software:**

Built with R, Shiny, bslib, plotly, ggplot2, ggbump, and flagon.
