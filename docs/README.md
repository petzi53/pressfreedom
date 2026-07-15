# Map Module Documentation

This directory contains the map visualization module for the pressfreedom Shiny dashboard.

## Module Structure

| File | Purpose |
|------|---------|
| `app.R` | Main Shiny app entry point |
| `mod_map.R` | **Map module** — interactive choropleth visualization |
| `mod_inputs.R` | Country selector (time series tab) |
| `mod_chart.R` | Line/bump chart (time series tab) |
| `mod_country.R` | Country detail view |
| `helpers.R` | Shared utility functions |

## Map Module (`mod_map.R`)

The map module provides an interactive geographic visualization of press freedom scores and ranks.

### Functions

#### `mapUI(id, rwb)`
Renders the UI for the map tab, including:
- Year selector
- Zone selector (World, region, or specific zone)
- **Dynamic range selector** (Score Range or Rank Range)
- Metric toggle (Score or Rank)
- Plotly choropleth map
- Right sidebar for country details (collapsed by default)

#### `mapServer(id, rwb)`
Handles the server logic:
1. **Reactive year updates** based on selected zone
2. **Dynamic range selector** that switches based on metric
3. **Data filtering** using appropriate binning function
4. **Choropleth rendering** with color scale and hover text
5. **Country detail sidebar** on click

### Features

#### Dynamic Range Selector (NEW)

When the user toggles between Score and Rank metrics, the range selector automatically changes:

| Metric | Selector Label | Options |
|--------|----------------|---------|
| Score | "Score Range" | All Scores, 0–20, 20–40, ..., 80–100 |
| Rank | "Rank Range" | All Ranks, The Best, Elite, High Performers, Middle Bulk, Low Performers, Critical, Worst |

#### Score Ranges (5 bins)
- `0-20`: Scores 0–20
- `20-40`: Scores 20–40
- `40-60`: Scores 40–60
- `60-80`: Scores 60–80
- `80-100`: Scores 80–100

#### Rank Tiers (7 percentile-based categories)
- `rank-1`: Rank 1 only (best press freedom)
- `rank-2`: Top 2.5% (elite tier)
- `rank-3`: Next 12.5% (high performers)
- `rank-4`: Core 70% (middle bulk)
- `rank-5`: Next 12.5% (low performers)
- `rank-6`: Bottom 2.5% (critical tier)
- `rank-7`: Highest rank only (worst press freedom)

### Data Flow

```
User Input (Year, Zone, Metric, Range)
         ↓
    map_data() reactive
    (applies filtering)
         ↓
    Choropleth Map
    (colored by metric)
         ↓
    Click Country → Detail Sidebar
```

### Hover Text

**Score mode:**
```
<Country>
Score: 75.5
Rank: 42
Range: 60–80
Zone: Europe
```

**Rank mode:**
```
<Country>
Rank: 42
Score: 75.5
Tier: rank-4
Zone: Europe
```

---

## Key Functions

### `bin_score(score)`
Assigns a score to a 5-bin category (0–20, 20–40, ..., 80–100).

### `bin_rank(rank, max_rank)`
Assigns a rank to one of 7 percentile-based tiers:
- Rank 1 → Tier 1 (The Best)
- Top 2.5% → Tier 2 (Elite)
- Next 12.5% → Tier 3 (High Performers)
- Core 70% → Tier 4 (Middle Bulk)
- Next 12.5% → Tier 5 (Low Performers)
- Bottom 2.5% → Tier 6 (Critical)
- Highest rank → Tier 7 (The Worst)

### `map_data()`
Reactive that:
1. Filters data by year and zone
2. Applies score or rank binning based on metric
3. Filters by selected range/tier
4. Returns prepared data frame with `range_bin` column

---

## Customization

### Adding a New Score Range
Edit `bin_score()` and the Score Range choices in `output$range_selector_ui`:

```r
bin_score <- function(score) {
    dplyr::case_when(
        score < 10  ~ "0–10",    # Add new tier
        score < 20  ~ "10–20",   # Shift others
        ...
    )
}

# In output$range_selector_ui, update choices
choices = c(
    "All Scores" = "all",
    "0–10" = "0-10",
    "10–20" = "10-20",
    ...
)
```

### Changing Rank Percentiles
Edit the boundaries in `bin_rank()`:

```r
p2_5 <- max_rank * 0.025    # Change percentile
p15 <- max_rank * 0.15      # (multiplier)
```

### Updating Hover Text Format
Edit the `hovertext` definition in `output$map`:

```r
hovertext <- paste0(
    "<b>", data$country_en, "</b><br>",
    "Additional info: ", ...
)
```

---

## Testing Checklist

- [ ] App loads without errors
- [ ] Score metric selected → Score Range dropdown visible
- [ ] Click "Rank" → dropdown changes to Rank Range with 7 options
- [ ] Click "Score" → dropdown changes back to Score Range
- [ ] Select each range/tier → map updates with filtered data
- [ ] Hover over countries → hover text shows correct range/tier
- [ ] Click country → detail sidebar appears with info
- [ ] Year selector updates based on zone
- [ ] "All" option shows complete dataset

---

## Documentation Files

| File | Content |
|------|---------|
| `RANK_RANGE_IMPLEMENTATION.md` | Technical implementation details |
| `IMPLEMENTATION_SUMMARY.md` | High-level change summary |
| `USER_GUIDE.md` | User-facing documentation |
| `VISUAL_REFERENCE.md` | UI mockups and examples |
| `README.md` | This file |

---

## Dependencies

Packages used in this module:
- `shiny` — Web framework
- `plotly` — Interactive choropleth
- `dplyr` — Data filtering
- `stringr` — String utilities

All dependencies are listed in the main `DESCRIPTION` file.

---

## Notes

- Percentile boundaries are calculated dynamically based on `max_rank` from the dataset.
- The module uses explicit namespacing (e.g., `dplyr::filter`) to avoid polluting the search path.
- All reactive dependencies are explicit in `shiny::req()` calls.
- The module is self-contained and doesn't modify global state.

---

## Questions?

Refer to the detailed documentation files in this directory for:
- **How it works internally:** `RANK_RANGE_IMPLEMENTATION.md`
- **What changed:** `IMPLEMENTATION_SUMMARY.md`
- **How to use it:** `USER_GUIDE.md`
- **Visual examples:** `VISUAL_REFERENCE.md`
