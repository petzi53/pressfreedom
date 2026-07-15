# Map Module Usage Guide

## Quick Start

The map module is already integrated into the main Shiny app (`inst/app/app.R`). To launch the dashboard:

```r
pressfreedom::run_app()
```

Then navigate to the **"Map"** tab.

## Filter Controls

### Year Selector
- **Type**: Single-select dropdown
- **Values**: 2002–2025 (excluding 2011, which has no data)
- **Default**: Latest year (2025)
- **Effect**: Filters all map data to selected year only

### Zone Selector
- **Type**: Multiple-select
- **Values**: All RSF zones (8 total):
  - Afrique
  - Amériques
  - Asie-Pacifique
  - EEAC (Eastern Europe and Central Asia)
  - Europe – Asie centrale
  - Maghreb – Moyen-Orient
  - MENA (Middle East and North Africa)
  - UE Balkans (EU and Balkans)
- **Default**: All zones selected
- **Effect**: Shows only countries in selected zones

### Score Bin Selector
- **Type**: Multiple-select
- **Values**:
  | Range | Interpretation |
  |-------|-----------------|
  | 0–20 | Crisis situation |
  | 20–40 | Difficult situation |
  | 40–60 | Problematic situation |
  | 60–80 | Satisfactory situation |
  | 80–100 | Good situation |
- **Default**: All bins selected
- **Effect**: Shows only countries whose score falls in selected ranges
- **Note**: Binning is computed after filtering to the selected year

### Metric Selector
- **Type**: Radio button (single-select)
- **Values**:
  - **Score**: Numeric value 0–100 (higher = more free)
  - **Rank**: Integer 1–191 (lower = more free; rank 1 = most free country)
- **Default**: "Score"
- **Effect**: Determines the value encoded in the map's color scale and colorbar

## Map Visualization

### Choropleth Map
- **Geography**: All 191 countries (identified by ISO 3166-1 alpha-3 codes)
- **Color encoding**: Consistent intuitive semantics for both metrics
  - **Dark red/green (top)** = Best press freedom
    - Score metric: 80–100 (high score)
    - Rank metric: 1–50 (best countries, rank 1 on top)
  - **Yellow (middle)** = Moderate press freedom
    - Score metric: 40–60 (mid score)
    - Rank metric: 80–130 (mid rank)
  - **Pale red (bottom)** = Worst press freedom
    - Score metric: 0–20 (low score)
    - Rank metric: 150+ (worst countries)
- **Colorbar**: Shows consistent gradient with best at top (dark) and worst at bottom (pale) for both metrics
- **Technical note**: Rank values are inverted (`max_rank - rank + 1`) and colorbar is reversed, so rank 1 (best) displays in dark red at the top, matching the color semantics of high scores
- **Interaction**:
  - **Hover**: Displays country name, score/rank, and zone
  - **Click**: Opens the right sidebar with detailed country information
  - **Zoom/Pan**: Native plotly controls in top-right

### Country Detail Sidebar
- **Display**: Collapses by default; opens on country click
- **Content**: Table with 8 rows
  | Row | Data | Availability |
  |-----|------|--------------|
  | Country name | Header text | Always |
  | Score | 0–100 | Always |
  | Rank | 1–191 | Always |
  | Zone | RSF zone | Always |
  | Political | 0–100 | 2022+ only |
  | Economic | 0–100 | 2022+ only |
  | Legal | 0–100 | 2022+ only |
  | Social | 0–100 | 2022+ only |
  | Safety | 0–100 | 2022+ only |
- **Missing data**: Shows "–" (en dash) for dimension scores before 2022

## Common Workflows

### Workflow 1: Compare Freedom Crisis Countries
1. Year: 2025
2. Zone: All (or specific regions)
3. Score Bin: Select **only 0–20**
4. Metric: Score
5. Result: Map highlights countries in crisis situations (lowest scores)

### Workflow 2: Rank Evolution by Region
1. Year: 2025
2. Zone: Select **EEAC** (Eastern Europe)
3. Score Bin: All
4. Metric: **Rank**
5. Result: See rank distribution within that region; click countries for detailed scores

### Workflow 3: Stable Democracies
1. Year: 2025
2. Zone: All
3. Score Bin: Select **80–100**
4. Metric: Score
5. Result: Map highlights only highest-freedom countries

### Workflow 4: Compare Dimension Scores
1. Year: **2025** (ensure 2022+)
2. Zone: Specific region (e.g., Amériques)
3. Score Bin: All
4. Metric: Score
5. Click a country
6. Result: Sidebar shows political, economic, legal, social, and safety scores

## Technical Notes

### Filtering Order
1. Filter to selected year
2. Filter to selected zones
3. **Compute** score bins (0–20, 20–40, etc.)
4. Filter to selected score bins
5. Render map

### Dimension Data Availability
Dimension scores (political, economic, legal, social, safety) are only available for **2022 onwards**. If you select 2021 or earlier and then click a country, the sidebar will show "–" for all dimension fields.

### Performance
The map updates reactively as you change filters. With 191 countries and up to 24 years of data, filtering and rendering is typically fast (<1 second). If you notice lag:
- Reduce the number of zones selected
- Try a single score bin rather than multiple

## Keyboard Shortcuts (Plotly)
- **Double-click map background**: Reset zoom
- **Click and drag**: Pan
- **Scroll wheel**: Zoom in/out (on hover)
