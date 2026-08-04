# pressfreedom

An interactive Shiny dashboard for exploring the **Reporters Without Borders
(RSF) Press Freedom Index**, 2002–present, across countries, regions, and
time — including a five-dimension breakdown (political, economic, legal,
social, safety) available from 2022 onward.

## Two ways to use it

- **[petzi53.shinyapps.io/pressfreedom](https://petzi53.shinyapps.io/pressfreedom/)**
  — for casual, interactive exploration. No install needed, but subject to
  shinyapps.io's usage limits.
- **As an R package** — for heavy exploration, repeated sessions, or
  offline use, avoiding those limits entirely:

  ```r
  remotes::install_github("petzi53/pressfreedom")
  # or: pak::pak("petzi53/pressfreedom")

  library(pressfreedom)
  run_app()
  ```

Both run the exact same app code (`inst/app/app.R`), so the experience is
identical either way.

## Data

Data is sourced from RSF and standardized by the companion
[pressfreedom.data](https://github.com/petzi53/pressfreedom.data) package,
which `pressfreedom` loads live at startup (`pressfreedom.data::rwb_standardized`) rather than bundling.
See its [pkgdown site](https://www.peter-baumgartner.net/pressfreedom.data/index.html)
for the full data dictionary, cleaning pipeline, and known-issue documentation.
The dashboard's own "About" tab covers scoring bands, methodology, and
limitations.

## Package structure

```
pressfreedom/
├── R/run_app.R          # Exported run_app() launcher
├── inst/app/
│   ├── app.R            # Shiny entry point (also deployed as-is to shinyapps.io)
│   └── R/                # Modules: map, trends chart, country profile, inputs, flags, about, helpers
└── DESCRIPTION
```

## Citation & Contact

**How to cite:**

If you use this package or the underlying Press Freedom Index data, please cite both:

1. The **pressfreedom R package**:
   ```
   Peter Baumgartner (2026). pressfreedom: Press Freedom Dashboard. 
   R package version 0.1.0.
   https://github.com/petzi53/pressfreedom
   ```

2. The **original RSF data**:
   ```
   Reporters Without Borders (RSF). World Press Freedom Index. 
   https://rsf.org/en/index
   ```

**Found a bug or have a question?**

[Open an issue on GitHub](https://github.com/petzi53/pressfreedom/issues).

## License

MIT License. See [LICENSE](LICENSE) for details.

## Credits

The hex logo's microphone icon is from Flaticon:
<a href="https://www.flaticon.com/free-icons/microphone" title="microphone icons">Microphone icons created by Magnific - Flaticon</a>

## Author

**Peter Baumgartner** · petzi53@gmail.com · [ORCID](https://orcid.org/0000-0003-4526-8791) · [GitHub](https://github.com/petzi53)

## Related

- [pressfreedom.data](https://github.com/petzi53/pressfreedom.data) — data acquisition and standardization
- [Reporters Without Borders (RSF)](https://rsf.org/) — original data source
