# pressfreedom

<!-- badges: start -->
<!-- badges: end -->

A Shiny dashboard for exploring [Reporters Without Borders (RWB)](https://rsf.org/en/index)
Press Freedom Index data from 2002 to the present. The dataset combines RWB
scores with United Nations M49 geographic classifications.

The full data acquisition and cleaning pipeline is documented in the companion
Quarto book: <https://petzi53.github.io/rwb-book/>.

## Installation

```r
# Install the development version from GitHub:
# install.packages("pak")
pak::pak("petzi53/pressfreedom")
```

## Usage

```r
library(pressfreedom)
run_app()
```

## Data updates

The RWB Press Freedom Index is published annually, typically in May. To update
the bundled dataset, re-run `data-raw/rwb.R` after updating the source files
in the `rwb-book` project, then increment the package version.

## License

MIT © Peter Baumgartner
