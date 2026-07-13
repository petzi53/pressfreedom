# Dynamic Rank/Score Range Selector Implementation

## Overview

The map module (`mod_map.R`) now features a **dynamically switching range selector** that changes label and options based on the selected metric (Score vs. Rank).

## Changes Made

### 1. UI Changes (`mapUI`)

**Before:**
```r
shiny::selectInput(
    ns("score_bin"),
    label = "Score Range",
    choices = c("All Scores", "0–20", "20–40", ...),
    ...
)
```

**After:**
```r
shiny::uiOutput(ns("range_selector_ui"))
```

The static score range selector is replaced with a reactive `uiOutput()` that re-renders based on the selected metric.

---

### 2. Reactive Range Selector (`mapServer`)

A new reactive output dynamically renders the appropriate selector:

```r
output$range_selector_ui <- shiny::renderUI({
    metric <- input$metric
    
    if (metric == "score") {
        # Score Range selector (5 ranges + All)
    } else {
        # Rank Range selector (7 tiers + All)
    }
})
```

#### Score Range (when metric = "score")
- All Scores
- 0–20
- 20–40
- 40–60
- 60–80
- 80–100

#### Rank Range (when metric = "rank")
- All Ranks
- **The Best (Rank 1)** — exactly rank 1
- **The Elite Tier (Top 2.5%)** — top 2.5% of countries
- **The High Performer Tier (Next 12.5%)** — next 12.5%
- **The Middle Bulk (Next 70%)** — core 70%
- **The Low Performer Tier (Next 12.5%)** — next 12.5%
- **The Critical Tier (Bottom 2.5%)** — bottom 2.5%
- **The Worst (Highest Rank)** — highest rank only

---

### 3. Rank Binning Logic

New `bin_rank()` function divides countries into 7 percentile-based tiers:

```r
bin_rank <- function(rank, max_rank) {
    p2_5 <- max_rank * 0.025     # ~4.8 for 191 countries
    p15 <- max_rank * 0.15       # ~28.6
    p85 <- max_rank * 0.85       # ~162.3
    p97_5 <- max_rank * 0.975    # ~186.2
    
    dplyr::case_when(
        rank == 1 ~ "rank-1",
        rank <= p2_5 ~ "rank-2",
        rank <= p15 ~ "rank-3",
        rank <= p85 ~ "rank-4",
        rank <= p97_5 ~ "rank-5",
        rank <= p100 ~ "rank-6",
        TRUE ~ "rank-7"
    )
}
```

**Percentile Breakdown (for ~191 countries):**
| Tier | Label | Boundaries | Count |
|------|-------|-----------|-------|
| 1 | The Best | rank = 1 | 1 |
| 2 | Elite | 1 < rank ≤ 4.8 | ~4 |
| 3 | High Performers | 4.8 < rank ≤ 28.6 | ~24 |
| 4 | Middle Bulk | 28.6 < rank ≤ 162.3 | ~134 |
| 5 | Low Performers | 162.3 < rank ≤ 186.2 | ~24 |
| 6 | Critical | 186.2 < rank ≤ 191 | ~5 |
| 7 | The Worst | rank = 191 | 1 |

---

### 4. Data Filtering Updates

The `map_data()` reactive now:
1. Accepts `input$metric` and `input$range_bin` (instead of just `input$score_bin`)
2. Applies the appropriate binning function (score or rank)
3. Filters based on the selected range type

```r
if (metric == "score") {
    # Score-based filtering
    result <- result |> dplyr::mutate(range_bin = bin_score(score), ...)
    if (input$range_bin != "all") {
        bounds <- as.numeric(strsplit(input$range_bin, "-")[[1]])
        result <- result |> dplyr::filter(score >= bounds[1], score < bounds[2])
    }
} else {
    # Rank-based filtering
    max_rank <- max(rwb$rank, na.rm = TRUE)
    result <- result |> dplyr::mutate(range_bin = bin_rank(rank, max_rank), ...)
    if (input$range_bin != "all") {
        result <- result |> dplyr::filter(range_bin == input$range_bin)
    }
}
```

---

### 5. Hover Text Updates

The hover text now dynamically includes the binned range information:

**For Score:**
```
<Country Name>
Score: 75.5
Rank: 25
Range: 60–80
Zone: Europe - Balkans
```

**For Rank:**
```
<Country Name>
Rank: 25
Score: 75.5
Tier: rank-2
Zone: Europe - Balkans
```

---

## User Experience

1. **Default state:** Score metric is selected; Score Range selector shows.
2. **Switch to Rank:** The range selector label and options automatically change to Rank Range with 7 tiers.
3. **Filter application:** All filtering logic automatically adapts—countries are binned and filtered according to the active metric.
4. **No state loss:** When switching between metrics, the "All" option is selected to show the complete picture.

---

## Technical Notes

- The `range_selector_ui` is a reactive output that depends on `input$metric`.
- Percentile boundaries are calculated as fractions of `max_rank` from the dataset (handles any number of countries).
- The binning functions (`bin_score`, `bin_rank`) are defined within the `mapServer` closure and have access to reactive values.
- All filtering logic is contained in the `map_data()` reactive, ensuring consistency across the chart rendering and sidebar detail display.

---

## Testing Checklist

- [ ] Load app with score metric selected → Score Range selector displays
- [ ] Switch to rank metric → Rank Range selector appears with 7 tiers
- [ ] Switch back to score → Score Range selector reappears
- [ ] Apply score filters → map updates correctly
- [ ] Apply rank filters → map updates, countries binned correctly
- [ ] Hover text shows correct range/tier information
- [ ] Click country for details → sidebar shows country information
- [ ] Year and Zone filters still work correctly

