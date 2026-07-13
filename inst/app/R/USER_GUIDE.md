# Map Tab — Score vs. Rank Range Selector

## What Changed

When you're in the **Map tab**, the range selector now **automatically switches** based on which metric you choose.

---

## The Score Mode (Default)

**When you select "Score":**

```
Year: [2025 ▼]  Zone: [World ▼]  Score Range: [All Scores ▼]  ○ Score ◉ Rank
```

The "Score Range" dropdown offers:
- **All Scores** — Show all countries
- **0–20** — Very low scores
- **20–40**
- **40–60**
- **60–80**
- **80–100** — Highest scores

### How It Works
1. Select a score range, e.g., "80–100"
2. The map shows **only countries with scores in that range**
3. The colorbar shows the full 0–100 scale
4. Hover over any country to see: Score, Rank, Range, and Zone

---

## The Rank Mode (New)

**When you select "Rank":**

```
Year: [2025 ▼]  Zone: [World ▼]  Rank Range: [All Ranks ▼]  ◉ Score ◉ Rank
```

The "Rank Range" dropdown now offers **7 tiers** (instead of 5 score ranges):

### The 7 Rank Tiers

1. **The Best (Rank 1)**
   - Exactly rank 1 (typically 1 country)
   - Highest press freedom

2. **The Elite Tier (Top 2.5%)**
   - Roughly the top 4–5 countries
   - Exceptional press freedom

3. **The High Performer Tier (Next 12.5%)**
   - Roughly the next 20–25 countries
   - Very good press freedom

4. **The Middle Bulk (Next 70%)**
   - Roughly the middle 125+ countries
   - Moderate to mixed press freedom

5. **The Low Performer Tier (Next 12.5%)**
   - Roughly 20–25 countries
   - Poor press freedom

6. **The Critical Tier (Bottom 2.5%)**
   - Roughly the bottom 4–5 countries
   - Severe press freedom challenges

7. **The Worst (Highest Rank)**
   - Exactly the highest rank (typically 1 country)
   - Worst press freedom

### How It Works
1. Select a rank tier, e.g., "The Elite Tier (Top 2.5%)"
2. The map shows **only countries in that tier**
3. The colorbar shows the rank scale (1 = best, 180 = worst)
4. Hover over any country to see: Rank, Score, Tier, and Zone

---

## Visual Indicators in Hover & Details

When you hover over a country:

### Score Mode
```
France
Score: 78.5
Rank: 24
Range: 60–80
Zone: Europe – EU
```

### Rank Mode
```
France
Rank: 24
Score: 78.5
Tier: rank-3
Zone: Europe – EU
```

Click any country to see the full details sidebar (on the right).

---

## Why Two Systems?

| Aspect | Score Ranges | Rank Tiers |
|--------|-------------|-----------|
| **What it shows** | Score thresholds (quality) | Country percentiles (position) |
| **Use case** | "Which countries score above 60?" | "Where does a country rank globally?" |
| **Distribution** | Equal width buckets | Equal percentage groups |
| **Number of options** | 5 + All | 7 + All |

---

## Tips

- **Start with "All Ranges/Ranks"** to see the global picture
- **Combine with Zone filtering** — e.g., see only African countries in "High Performer Tier"
- **Combine with Year filtering** — e.g., track how countries move between tiers over time
- **Toggle between Score and Rank** to see both perspectives on the same countries

---

## Examples

### Example 1: Which countries have excellent scores?
1. Set Year: 2025
2. Set Zone: World
3. Set Score Range: **80–100**
4. Map highlights top-scoring countries

### Example 2: Where does my country rank?
1. Set Year: 2025
2. Set Zone: World (or select a specific zone)
3. Change to **Rank** metric
4. Select tier to filter
5. Click your country to see details

### Example 3: Compare regions over time
1. Set Year: 2024 (or another year)
2. Set Zone: **Asia** (or another region)
3. Change to **Rank** metric
4. Select "Middle Bulk" to see mid-ranking countries
5. Scroll through different years to see shifts

---

## Questions?

The map uses **Reporters Without Borders (RWB) Press Freedom Index** data. Scores and ranks are calculated by RWB based on surveys and editorial assessment.

- **Higher scores** = more press freedom violations detected
- **Lower ranks** (1 = best press freedom) = less press freedom

The tiers automatically adjust to your selected year and zone.
