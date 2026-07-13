# Visual Reference — Dynamic Range Selector

## UI Layout Comparison

### SCORE MODE (Default)

```
┌─────────────────────────────────────────────────────────────────┐
│ Year: [2025 ▼]  Zone: [World ▼]  Score Range: [All Scores ▼]  │
│ ◉ Score  ○ Rank                                                 │
└─────────────────────────────────────────────────────────────────┘
         ↓
    (Dropdown open)
    ┌─────────────────┐
    │ All Scores      │ ← selected
    │ 0–20            │
    │ 20–40           │
    │ 40–60           │
    │ 60–80           │
    │ 80–100          │
    └─────────────────┘
```

### RANK MODE (New)

```
┌─────────────────────────────────────────────────────────────────┐
│ Year: [2025 ▼]  Zone: [World ▼]  Rank Range: [All Ranks ▼]     │
│ ○ Score  ◉ Rank                                                 │
└─────────────────────────────────────────────────────────────────┘
         ↓
    (Dropdown open)
    ┌──────────────────────────────────────────┐
    │ All Ranks                                 │ ← selected
    │ The Best (Rank 1)                         │
    │ The Elite Tier (Top 2.5%)                │
    │ The High Performer Tier (Next 12.5%)     │
    │ The Middle Bulk (Next 70%)               │
    │ The Low Performer Tier (Next 12.5%)      │
    │ The Critical Tier (Bottom 2.5%)          │
    │ The Worst (Highest Rank)                 │
    └──────────────────────────────────────────┘
```

---

## State Transitions

```
┌──────────────────────────────────────────────────────────────┐
│                      USER TOGGLES METRIC                     │
└──────────────────────────────────────────────────────────────┘

   Score Selected                   Rank Selected
        ↓                                ↓
   ┌─────────┐                    ┌────────────┐
   │ "Score  │  Click "Rank" →    │  "Rank    │
   │ Range"  │  ──────────────→   │  Range"   │
   │ [5 opts]│                    │  [7 opts] │
   └─────────┘                    └────────────┘
        ↑                                │
        │     Click "Score" ←──────────  │
        └──────────────────────────────┘
```

---

## Dropdown Content

### Score Range (5 options + All)

| Label | Value | Selects |
|-------|-------|---------|
| All Scores | `"all"` | 0 ≤ score ≤ 100 |
| 0–20 | `"0-20"` | 0 ≤ score < 20 |
| 20–40 | `"20-40"` | 20 ≤ score < 40 |
| 40–60 | `"40-60"` | 40 ≤ score < 60 |
| 60–80 | `"60-80"` | 60 ≤ score < 80 |
| 80–100 | `"80-100"` | 80 ≤ score ≤ 100 |

### Rank Range (7 tiers + All)

| Label | Value | Selection Logic |
|-------|-------|-----------------|
| All Ranks | `"all"` | All ranks (1–180) |
| The Best (Rank 1) | `"rank-1"` | rank == 1 |
| The Elite Tier (Top 2.5%) | `"rank-2"` | 1 < rank ≤ 4.5 |
| The High Performer Tier (Next 12.5%) | `"rank-3"` | 4.5 < rank ≤ 27.0 |
| The Middle Bulk (Next 70%) | `"rank-4"` | 27.0 < rank ≤ 153.0 |
| The Low Performer Tier (Next 12.5%) | `"rank-5"` | 153.0 < rank ≤ 175.5 |
| The Critical Tier (Bottom 2.5%) | `"rank-6"` | 175.5 < rank ≤ 180 |
| The Worst (Highest Rank) | `"rank-7"` | rank == 180 |

---

## Data Flow

```
┌─────────────────┐
│ user selects    │
│ metric: score   │ ─→ render "Score Range" selector
│ or rank         │ ─→ update map_data() reactive
└─────────────────┘
         ↓
┌─────────────────┐
│ user selects    │
│ score/rank bin  │ ─→ filter data via bin_score() or bin_rank()
└─────────────────┘
         ↓
┌─────────────────┐
│ map_data()      │ ─→ filtered data frame with range_bin column
│ reactive        │
└─────────────────┘
         ↓
┌─────────────────┐
│ renderPlotly()  │ ─→ colorize countries by score/rank
│                 │ ─→ hover shows range/tier + other info
└─────────────────┘
```

---

## Hover Text Examples

### Score Mode: A High-Score Country (e.g., Norway)

```
┌───────────────────────────┐
│ Norway                    │
│                           │
│ Score: 84.5              │
│ Rank: 1                  │
│ Range: 80–100            │
│ Zone: Europe - Nordic    │
└───────────────────────────┘
```

### Score Mode: A Low-Score Country (e.g., Venezuela)

```
┌───────────────────────────┐
│ Venezuela                 │
│                           │
│ Score: 23.7              │
│ Rank: 173                │
│ Range: 20–40             │
│ Zone: Americas - South   │
└───────────────────────────┘
```

### Rank Mode: An Elite Tier Country (e.g., Sweden)

```
┌───────────────────────────┐
│ Sweden                    │
│                           │
│ Rank: 4                  │
│ Score: 83.2              │
│ Tier: rank-2             │
│ Zone: Europe - Nordic    │
└───────────────────────────┘
```

### Rank Mode: A Low Performer (e.g., Egypt)

```
┌───────────────────────────┐
│ Egypt                     │
│                           │
│ Rank: 158                │
│ Score: 43.1              │
│ Tier: rank-5             │
│ Zone: MENA               │
└───────────────────────────┘
```

---

## Percentile Distribution (Visual)

```
Countries ordered by rank (worst to best):

Worst ┌────────────────────────────────────────────────────────┐ Best
rank  │rank-7 │rank-6│        rank-5         │      rank-4      │rank-3│rank-2│rank-1
180   │ 176–  │ 176  │ 153.0 ← → 175.5       │ 27.0 ← → 153     │4.5–27│1–4.5 │ 1
      │ 180   │ 180  │                        │                  │      │      │
      │ 1%    │ 2.5% │       12.5%            │       70%        │12.5% │2.5% │0.6%
      └────────────────────────────────────────────────────────┘
        ↑                                                          ↑
        Critical tier                                            Elite tier
        (worst countries)                                        (best countries)
```

---

## Interaction Sequence (Example)

1. **User opens Map tab** → Metric: Score, Range: All Scores
   - Map shows all countries colored by score (0–100)

2. **User clicks "Rank" radio button**
   - Dropdown label changes: "Score Range" → "Rank Range"
   - Dropdown options change: 5 score bins → 7 rank tiers
   - Selected option: "All Ranks" (auto-selected)
   - Map re-renders: countries colored by rank (1–180)

3. **User selects "The Elite Tier (Top 2.5%)"**
   - Map filters to show ~4–5 countries with best ranks
   - Hover shows each country's exact rank and tier
   - Detail sidebar still available for clicking

4. **User selects Year 2024**
   - Data refreshes for 2024
   - Tier boundaries recalculated if number of countries changed
   - Filtered countries in elite tier updated

5. **User clicks "Score" radio button**
   - Dropdown changes back to "Score Range"
   - Map re-renders by score
   - Tier boundaries no longer apply (only score ranges)

---

## Accessibility Notes

- All dropdown labels are clearly associated with their selectors
- Color-coded map (red = low press freedom, green = high)
- Rank scale inverted in colorbar to match intuition: Rank 1 (best) shows as green
- Hover text is comprehensive for users who can't distinguish colors
- Detail sidebar provides full numeric values
