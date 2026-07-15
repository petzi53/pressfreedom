# Map Module Implementation Summary

## Overview
The `mod_map.R` module provides an interactive geographic visualization of press freedom data using `plotly::plot_geo()` for a choropleth map. Users can filter by year, zone, score bin, and metric (score or rank).

## Module Structure

### UI (`mapUI`)
Provides:
- **Filter controls** (4 columns):
  - Year selector (dropdown, sorted descending)
  - Zone selector (multiple, defaults to all zones)
  - Score bin selector (multiple ranges: 0–20, 20–40, 40–60, 60–80, 80–100)
  - Metric radio buttons (Score or Rank)
- **Choropleth map** (600px height)
- **Right sidebar** (collapsible, for country details)

### Server (`mapServer`)
Implements:

#### 1. Score Binning Function (`bin_score`)
Converts numeric scores (0–100) into five categories:
- 0–20: Crisis situation
- 20–40: Difficult situation
- 40–60: Problematic situation
- 60–80: Satisfactory situation
- 80–100: Good situation

#### 2. Reactive Data Filtering (`map_data`)
Filters the full dataset based on:
- Selected year
- Selected zones (multiple)
- Score bins (multiple, computed after binning)
- Selects only necessary columns for efficiency

#### 3. Choropleth Rendering (`output$map`)
Builds a choropleth map with:
- **Geographic encoding**: ISO 3166-1 alpha-3 codes for country identification
- **Color scale selection**:
  - **Score metric**: "RdYlGn" (Red–Yellow–Green, not reversed)
    - Green = high scores (80–100, more free)
    - Red = low scores (0–20, less free)
  - **Rank metric**: "RdYlGn" (not reversed; rank values inverted for consistent semantics)
    - Inverts rank values so rank 1 (best) maps to highest color intensity
    - Green = low rank numbers (1–50, most free)
    - Red = high rank numbers (150+, least free)
    - Visual consistency: both metrics show "good" in green, "bad" in red
- **Value range**:
  - Score: 0–100 (fixed)
  - Rank: 1 to max rank in dataset
- **Hover text**: Country name, metric value, zone
- **Styling**:
  - Natural Earth projection
  - Light gray land, light blue ocean
  - Custom colorbar title

#### 4. Country Detail Sidebar (`output$country_detail`)
Displays a table with details for the clicked country:
- Country name (header)
- Score and rank
- Zone
- Dimension scores (if available, showing "–" for missing data)

Uses `plotly::event_data("plotly_click")` to detect clicks and extract the clicked point's index.

## Technical Details

### Dependencies
- `shiny`: Module framework, reactivity, UI functions
- `dplyr`: Data filtering and manipulation
- `plotly`: Interactive choropleth mapping
- `stringr`: String case conversion for title formatting

### Data Pipeline
1. User selects year, zones, score bins, metric → triggers `map_data()` reactivity
2. `map_data()` filters `rwb` dataset and computes score bins
3. Map renders with filtered data, metric determines color scale and range
4. Click event on map updates sidebar with country details

### Color Scale Behavior
Both metrics use the RdYlGn (Red–Yellow–Green) color scale with **consistent semantics**:
- **Dark red/green (top of scale)** → Best press freedom (high score OR rank 1)
- **Pale red (bottom of scale)** → Worst press freedom (low score OR high rank)

**Technical implementation**:
- For **Score**: Values 0–100 passed directly; colorbar not reversed
  - Top: 100 (best) in dark green
  - Bottom: 0 (worst) in dark red
- For **Rank**: Values inverted (`max_rank - rank + 1`) AND colorbar reversed
  - Inversion: rank 1 → value 191, rank 191 → value 1
  - Reversal: colorbar shows 191 at top (labeled "Rank 1") in dark red
  - Result: rank 1 (best) in dark red at top; rank 191 (worst) in pale red at bottom

This dual transformation ensures rank 1 (most free country) displays in dark colors at the top, visually consistent with high scores being dark colors at the top. Users see intuitive color language for both metrics: **dark = good, pale = bad**.

### Missing Data Handling
- Dimension scores (political, economic, legal, social, safety) are only available for 2022+
- Sidebar displays "–" (en dash) when these values are NA
- Main map filters work with `dplyr::filter()` which automatically handles NA values

## Usage Notes

### Score Bin Filtering
The UI provides score bins, but they are computed reactively on the *selected year's data*. Users can:
- Select all bins (default): shows all countries in selected zones
- Select specific bins: filters to countries whose score falls in those ranges
- Combine with zone selection for targeted views (e.g., "Show all 20–40 score countries in Europe")

### Year Selection
Only one year can be selected at a time, matching the typical use case of "compare countries at a single point in time on a map."

### Map Interactivity
- **Zoom/pan**: Native plotly controls
- **Click country**: Opens sidebar with details
- **Hover**: Shows country name, value, zone in tooltip

## Example Workflow
1. User selects 2025 (latest year)
2. User deselects some zones, keeping only "Europe – Asie centrale" and "UE Balkans"
3. User selects metric = "Rank"
4. Map renders showing only countries in those zones, colored by rank (green = rank 1–20, red = rank 100+)
5. User clicks Finland
6. Sidebar opens showing Finland's score, rank, and dimension scores for 2025

## Future Enhancements
- Add time animation slider to show rank/score evolution (requires significant refactor)
- Add region-level aggregations (average score per zone)
- Add comparison mode: overlay two years or two metrics
- Integrate with country profile module for deep dives
