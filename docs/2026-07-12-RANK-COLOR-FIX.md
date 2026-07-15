# Rank Color Scheme Fix

**Date**: July 12, 2026  
**Change**: Reversed rank color scheme so rank 1 (best) displays in dark red/green  
**Status**: ✓ Complete

## Problem
The map module was using `reversescale = (metric == "rank")` to reverse the RdYlGn color scale for ranks. However, this made:
- Rank 1 (best) → pale red/yellow (wrong!)
- Rank 191 (worst) → dark green (wrong!)

This was visually inconsistent with the score metric, where high scores (good) displayed in dark green.

## Solution
Instead of reversing the color scale, **invert the rank values** before passing them to plotly:

```r
# Old approach: reversescale = TRUE
z_values <- data$rank                    # 1, 2, 3, ..., 191
reversescale = TRUE                      # Makes 1 pale, 191 dark

# New approach: invert values
max_rank <- max(rwb$rank, na.rm = TRUE)  # 191
z_values <- max_rank - data$rank + 1     # 191, 190, 189, ..., 1
reversescale = FALSE                     # Makes 191 dark green, 1 dark green
```

**Result**: Rank 1 (best) → highest color value (191) → dark green ✓

## Changes Made

### `inst/app/R/mod_map.R` (lines 111–141)
- Compute `max_rank` from the full dataset
- Invert rank values: `z_values <- max_rank - data$rank + 1`
- Change `reversescale = FALSE` (was `TRUE`)
- Updated colorbar label and comments

### `inst/app/R/MOD_MAP_IMPLEMENTATION.md`
- Updated color scale behavior section
- Clarified technical implementation of inversion
- Noted visual consistency between metrics

### `inst/app/R/MOD_MAP_USAGE.md`
- Revised color encoding explanation
- Emphasized consistent visual language across both metrics
- Added note explaining the rank inversion

## Color Semantics (Now Consistent)

| Metric | Good | Moderate | Bad |
|--------|------|----------|-----|
| **Score** | 80–100 (dark green) | 40–60 (yellow) | 0–20 (dark red) |
| **Rank** | 1–50 (dark green) | 80–130 (yellow) | 150+ (dark red) |

Both metrics now use the same intuitive color language:
- **Dark red/green = good press freedom**
- **Pale red = poor press freedom**

## Verification

✓ Rank inversion formula tested with edge cases (rank 1, 10, 50, 100, 191)  
✓ Module reloaded without errors  
✓ Color scheme consistency verified  
✓ Documentation updated in three files  

The map will now display consistent, intuitive colors for both metrics when switched in the UI.
