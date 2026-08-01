# pressfreedom

An interactive Shiny dashboard for exploring **Reporters Without Borders (RWB) Press Freedom Index** data from 2002 to the present.

## Overview

The Press Freedom Index measures press freedom across countries and regions worldwide. This dashboard combines RWB scores with United Nations M49 geographic classifications to enable rich comparisons across:

- **Countries** — Historical trends, current rankings, and dimensional breakdowns
- **Regions** — Geographic aggregations (Asia, Europe, Americas, Africa, Oceania)
- **Time** — Press freedom trends over two decades (2002–2026)

## Features

### 📊 Interactive Visualizations

- **Map** — Visualize press freedom zones and rankings by country
- **Trends** — Explore press freedom trajectories over time
- **Country profiles** — Detailed country-specific analysis with dimensional breakdowns

### 🎯 Flexible Filtering

- Filter by country, region, or zone
- Compare multiple countries side-by-side
- Explore trends across time periods

### 📈 Multi-dimensional Analysis

For recent years (2022–2026), explore press freedom across five dimensions:
- Political context
- Economic context
- Legal framework
- Social environment
- Safety of journalists

## Installation

### From GitHub

```r
# Using remotes
remotes::install_github("petzi53/pressfreedom")

# Or using pak
pak::pak("petzi53/pressfreedom")
```

### Requirements

- R ≥ 3.5
- Shiny 1.7.0+
- pressfreedom.data ≥ 0.1.0

## Getting Started

### Run the Dashboard

```r
library(pressfreedom)
run_app()
```

The dashboard will launch in your default browser. No additional configuration needed.

### Explore the Data

If you want to work with the underlying data directly:

```r
library(pressfreedom.data)

# Load the standardized press freedom data
data(rwb_standardized)

# View structure and summary
head(rwb_standardized)
str(rwb_standardized)
```

## Data Source

Data comes from the **Reporters Without Borders (RSF) Press Freedom Index**, processed and standardized by the [pressfreedom.data](https://github.com/petzi53/pressfreedom.data) R package.

### Data Coverage

- **Years:** 2002–2026 (excluding 2011)*
- **Countries/Territories:** 191
- **Observations:** 4,192 rows

*2011 data was not published by RSF.

### Data Standardization

The underlying dataset is automatically standardized by pressfreedom.data to:

- **Consolidate country names** — Handle official changes (Turkey → Türkiye, Czechia) and RSF methodology variations
- **Assign ISO codes** — Every country has a standardized ISO 3-letter code
- **Normalize columns** — Unified 20-column structure across different RSF methodologies (2002–2012, 2013–2021, 2022–2026)
- **Preserve audit trails** — Full consolidation history available for data transparency

For technical details, see the [pressfreedom.data documentation](https://github.com/petzi53/pressfreedom.data/blob/main/AGENTS.md).

## Dashboard Modules

### 🗺️ Map Module

Interactive geographic visualization using Plotly. Countries are color-coded by press freedom zone:

- **Green** — Good press freedom
- **Yellow** — Satisfactory
- **Orange** — Problematic
- **Red** — Very serious situation

Click countries to filter; zoom for regional detail.

### 📈 Trends Module

Line charts showing press freedom score trajectories over time.

- Compare individual countries side-by-side
- Aggregate trends by region
- Highlight ranking changes and inflection points

### 🌍 Country Module

Detailed country profiles with:

- Historical score evolution (2002–2026)
- Dimensional analysis (2022–2026 only)
- Regional ranking and context
- Year-over-year score changes

## Technical Details

### Built With

| Package | Purpose |
|---------|---------|
| [Shiny](https://shiny.rstudio.com/) | Web application framework |
| [bslib](https://rstudio.github.io/bslib/) | Bootstrap 5 theming |
| [Plotly](https://plotly.com/r/) | Interactive maps and charts |
| [ggplot2](https://ggplot2.tidyverse.org/) | Static visualizations |
| [ggbump](https://github.com/davidsjoberg/ggbump) | Ranking bump charts |
| [flagon](https://github.com/coolbutuseless/flagon) | Country flag icons |
| [dplyr](https://dplyr.tidyverse.org/) | Data manipulation |
| [pressfreedom.data](https://github.com/petzi53/pressfreedom.data) | Data infrastructure & standardization |

### Package Structure

```
pressfreedom/
├── R/
│   ├── data.R                 # Data documentation
│   └── run_app.R              # App launcher function
├── inst/app/
│   ├── app.R                  # Shiny app entry point
│   ├── R/
│   │   ├── mod_inputs.R       # Input controls module
│   │   ├── mod_map.R          # Map visualization module
│   │   ├── mod_chart.R        # Trend charts module
│   │   ├── mod_country.R      # Country profiles module
│   │   ├── flags.R            # Flag icon utilities
│   │   └── helpers.R          # Helper functions
│   ├── www/                   # Static assets (CSS, JS, images)
│   └── data/                  # Pre-computed cached data
├── data/
│   └── rwb.rda                # Processed press freedom dataset
├── README.md                  # This file
├── DESCRIPTION                # Package metadata
└── LICENSE
```

## Data Updates

The RWB Press Freedom Index is published annually (typically in May). To update this package with the latest data:

1. New CSV files are added to pressfreedom.data
2. Run the pressfreedom.data pipeline (phases A–D)
3. Update pressfreedom's dependency version in `DESCRIPTION`
4. Re-run `data-raw/rwb.R` to rebuild `data/rwb.rda`
5. Increment pressfreedom's version and commit

**Estimated time:** ~30 minutes

For the complete data infrastructure, see [pressfreedom.data](https://github.com/petzi53/pressfreedom.data).

## Support

Found a bug? Have a feature request? Please open an issue:

[**petzi53/pressfreedom/issues**](https://github.com/petzi53/pressfreedom/issues)

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

The hex logo's microphone icon is from Flaticon:

<a href="https://www.flaticon.com/free-icons/microphone" title="microphone icons">Microphone icons created by Magnific - Flaticon</a>

## Author

**Peter Baumgartner**

- Email: petzi53@gmail.com
- ORCID: [0000-0003-4526-8791](https://orcid.org/0000-0003-4526-8791)
- GitHub: [@petzi53](https://github.com/petzi53)

## Related Projects

- [pressfreedom.data](https://github.com/petzi53/pressfreedom.data) — Data acquisition and standardization
- [Reporters Without Borders (RSF)](https://rsf.org/) — Original data source

---

**Last updated:** July 29, 2026  
**Package version:** 0.1.0
