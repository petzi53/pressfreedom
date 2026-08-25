# Vendored ggbump geometry functions
#
# Source: https://github.com/davidsjoberg/ggbump
# Commit: fe6d5c7 (main branch, 2025)
# Author: David Sjöberg
# License: MIT (see LICENSE.note)
#
# This file bundles the core bump-chart geometry functions from ggbump
# to eliminate a GitHub-only package dependency (ggbump was archived from
# CRAN on 2025-12-04). All functions are renamed with a `pf_` prefix
# to avoid conflicts if ggbump is ever added back as a dependency.
#
# Functions renamed:
#   sigmoid() -> pf_sigmoid()
#   rank_sigmoid() -> pf_rank_sigmoid()
#   geom_bump() -> pf_geom_bump()
#   StatBump -> PfStatBump
#   StatSigmoid -> PfStatSigmoid (not exported; included for completeness)

# ============================================================================
# Sigmoid and rank_sigmoid helpers
# ============================================================================

#' pf_sigmoid
#'
#' Creates a longer dataframe with coordinates for a smoothed line.
#'
#' @param x_from start x value
#' @param x_to end x value
#' @param y_from start y value
#' @param y_to end y values
#' @param n number of point that should be smoothed
#' @param smooth smooth parameter. Higher means less smoothing
#' @param direction the character x or y depending on direction of smoothing
#'
#' @return a data frame
#'
#' @keywords internal
pf_sigmoid <- function(x_from, x_to, y_from, y_to, smooth = 5, n = 100, direction = "x") {
  if (!direction %in% c("x", "y")) {
    stop("Only the directions x or y is allowed.")
  }

  if (direction == "x") {
    x <- seq(-smooth, smooth, length = n)
    y <- exp(x) / (exp(x) + 1)
    out <- data.frame(
      x = (x + smooth) / (smooth * 2) * (x_to - x_from) + x_from,
      y = y * (y_to - y_from) + y_from
    )
  }

  if (direction == "y") {
    y <- seq(-smooth, smooth, length = n)
    x <- exp(y) / (exp(y) + 1)
    out <- data.frame(
      y = (y + smooth) / (smooth * 2) * (y_to - y_from) + y_from,
      x = x * (x_to - x_from) + x_from
    )
  }
  out
}

#' pf_rank_sigmoid
#'
#' Creates a longer dataframe with coordinates for a smoothed line
#' interpolating between points.
#'
#' @param x vector
#' @param y vector
#' @param smooth smooth parameter. Higher means less smoothing
#' @param direction the character x or y depending of smoothing direction
#'
#' @return a data frame
#'
#' @keywords internal
pf_rank_sigmoid <- function(x, y, smooth = 8, direction = "x") {
  .df <- dplyr::tibble(
    x = x,
    y = y
  ) |>
    dplyr::mutate(
      x_lag = dplyr::lag(x),
      y_lag = dplyr::lag(y)
    ) |>
    tidyr::drop_na("x_lag")

  purrr::pmap_dfr(
    .df,
    ~ pf_sigmoid(
      x_from = ..3, x_to = ..1, y_from = ..4, y_to = ..2,
      smooth = smooth, direction = direction
    )
  )
}

# ============================================================================
# ggproto stat and geom
# ============================================================================

#' PfStatBump
#'
#' ggproto stat for bump charts (vendored from ggbump).
#'
#' @keywords internal
PfStatBump <- ggplot2::ggproto(
  "PfStatBump", ggplot2::Stat,
  setup_data = function(data, params) {
    # Create x_lag, and y_lag to be passed to `compute_group`
    # Factors need this to be able to compute a sigmoid function
    data <- data |>
      dplyr::mutate(r = dplyr::row_number()) |>
      dplyr::arrange(x) |>
      dplyr::group_by(dplyr::across(-c(PANEL, group, x, y, r))) |>
      dplyr::mutate(
        x_lag = dplyr::lag(x),
        y_lag = dplyr::lag(y)
      ) |>
      dplyr::ungroup() |>
      dplyr::arrange(r) |>
      dplyr::select(-r) |>
      as.data.frame()
    data
  },
  compute_group = function(data, scales, smooth = 8, direction = "x") {
    data <- data |>
      dplyr::arrange(x)

    # Handling of the special case of factors
    # Factors come as a df with one row
    if (nrow(data) == 1) {
      if (is.na(data$x_lag) | is.na(data$y_lag)) {
        return(data |> dplyr::slice(0))
      } else {
        out <- pf_sigmoid(
          data$x_lag, data$x, data$y_lag, data$y,
          smooth = smooth, direction = direction
        )
        return(as.data.frame(out))
      }
    }

    # Normal case
    out <- pf_rank_sigmoid(data$x, data$y, smooth = smooth, direction = direction) |>
      dplyr::mutate(key = 1) |>
      dplyr::left_join(
        data |>
          dplyr::select(-x, -y) |>
          dplyr::mutate(key = 1) |>
          dplyr::distinct(),
        by = "key"
      ) |>
      dplyr::select(-key) |>
      as.data.frame()
    out
  },
  required_aes = c("x", "y")
)

#' pf_geom_bump
#'
#' Creates a ggplot layer with smooth bump-chart geometry (vendored from ggbump).
#'
#' This creates a smooth rank over time. To change the `smooth`
#' argument you need to put it outside of the `aes` of the geom. Uses the x and y aesthetics.
#' Usually you want to compare multiple lines and if so, use the `color` aesthetic.
#' To change the direction of the curve to 'vertical' set `direction = "y"`.
#'
#' @param mapping provide your own mapping. both x and y need to be numeric.
#' @param data provide your own data
#' @param geom change geom
#' @param position change position
#' @param na.rm remove missing values
#' @param show.legend show legend in plot
#' @param smooth how much smooth should the curve have? More means steeper curve.
#' @param direction the character x or y depending of smoothing direction
#' @param inherit.aes should the geom inherits aesthetics
#' @param ... other arguments to be passed to the geom
#'
#' @return ggplot layer
#'
#' @examples
#' library(ggplot2)
#' df <- data.frame(
#'   country = c(
#'     "India", "India", "India",
#'     "Sweden", "Sweden", "Sweden",
#'     "Germany", "Germany", "Germany",
#'     "Finland", "Finland", "Finland"
#'   ),
#'   year = c(2011, 2012, 2013, 2011, 2012, 2013, 2011, 2012, 2013, 2011, 2012, 2013),
#'   rank = c(4, 2, 2, 3, 1, 4, 2, 3, 1, 1, 4, 3)
#' )
#'
#' ggplot(df, aes(year, rank, color = country)) +
#'   geom_point(size = 10) +
#'   pf_geom_bump(size = 2)
#'
#' @export
pf_geom_bump <- function(mapping = NULL, data = NULL, geom = "line",
                         position = "identity", na.rm = FALSE, show.legend = NA,
                         smooth = 8, direction = "x", inherit.aes = TRUE, ...) {
  ggplot2::layer(
    stat = PfStatBump, data = data, mapping = mapping, geom = geom,
    position = position, show.legend = show.legend, inherit.aes = inherit.aes,
    params = list(na.rm = na.rm, smooth = smooth, direction = direction, ...)
  )
}
