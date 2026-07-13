# Dynamic Rank/Score Range Selector — Implementation Summary

## What Was Changed

The map module (`inst/app/R/mod_map.R`) has been updated to provide a **dynamic range selector** that automatically switches between score ranges and rank tiers when the user toggles the metric.

## Key Changes

### 1. **UI Replacement** (Line 27)
- **Removed:** Static `selectInput()` for score ranges
- **Added:** Reactive `uiOutput(ns("range_selector_ui"))` that renders the appropriate selector based on metric

### 2. **New Reactive Output** (Lines 74–112)
Added `output$range_selector_ui` which renders:
- **Score metric selected:** "Score Range" with 5 bins (0–20, 20–40, ..., 80–100)
- **Rank metric selected:** "Rank Range" with 7 tiers based on percentiles

### 3. **New Rank Binning Function** (Lines 134–151)
`bin_rank(rank, max_rank)` divides countries into 7 tiers:
1. **The Best** — rank = 1
2. **The Elite Tier** — top 2.5%
3. **The High Performer Tier** — next 12.5%
4. **The Middle Bulk** — core 70%
5. **The Low Performer Tier** — next 12.5%
6. **The Critical Tier** — bottom 2.5%
7. **The Worst** — highest rank

### 4. **Updated Filtering Logic** (Lines 153–210)
- Changed input reference from `input$score_bin` → `input$range_bin`
- Added `input$metric` as a required reactive dependency
- Conditional logic applies the correct binning function (score or rank)
- Filter logic adapts based on metric (numeric bounds for score, categorical filter for rank)

### 5. **Updated Hover Text** (Lines 226–247)
- Score metric: Shows "Range: 60–80" (e.g.)
- Rank metric: Shows "Tier: rank-2" and uses human-readable names in detail sidebar

---

## Actual Data Parameters

For the current dataset (180 countries):
| Tier | Range | Count |
|------|-------|-------|
| 1 | rank = 1 | 1 |
| 2 | 1 < rank ≤ 4.5 | ~4 |
| 3 | 4.5 < rank ≤ 27 | ~22 |
| 4 | 27 < rank ≤ 153 | ~126 |
| 5 | 153 < rank ≤ 175.5 | ~22 |
| 6 | 175.5 < rank ≤ 180 | ~5 |
| 7 | rank = 180 | 1 |

---

## Testing Instructions

1. **Load the app:**
   ```r
   pressfreedom::run_app()
   ```

2. **Navigate to the Map tab**

3. **Test metric switching:**
   - Default: "Score Range" selector visible
   - Click "Rank" radio button → "Rank Range" selector appears with 7 options
   - Click "Score" radio button → "Score Range" selector reappears

4. **Test filtering:**
   - Select a score range → map filters to countries in that range
   - Switch to Rank, select a tier → map filters to countries in that tier
   - Hover over countries → hover text shows the selected range/tier
   - Click a country → sidebar shows details including range/tier

5. **Test with different years and zones:**
   - All combinations should work correctly
   - The "All Ranges" / "All Ranks" option shows all countries

---

## Files Modified

- `inst/app/R/mod_map.R` — Complete update with dynamic selector and rank binning

## Files Created

- `inst/app/R/RANK_RANGE_IMPLEMENTATION.md` — Detailed technical documentation
- `inst/app/R/IMPLEMENTATION_SUMMARY.md` — This file

---

## No Breaking Changes

✓ Backward compatible with existing UI layout  
✓ All existing filtering functionality preserved  
✓ Map rendering logic unchanged (uses same colorscale and geo projection)  
✓ Sidebar detail display still works with `plotly::event_data("plotly_click")`

---

## Questions or Issues?

The implementation is modular and self-contained within `mapServer()`. Key functions:
- `bin_score()` — Score binning (existing, unchanged)
- `bin_rank()` — Rank binning (new)
- `map_data()` — Reactive filtering (updated)
- `range_selector_ui` output — Dynamic UI (new)

All logic is clearly commented and follows the existing code style.
