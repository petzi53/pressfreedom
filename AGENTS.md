# Agents

This file provides context and guidance for AI agents working on the `pressfreedom` R package.

## CRITICAL: One Question at a Time (UI Glitch Workaround)

**Requirement:** NEVER ask multiple questions in a single response. Ask only one question per response, whether using `AskUser()` or inline clarifying questions.

**Why:** There is a UI glitch in RStudio/Posit that prevents rendering of multiple questions in a single batch. Only the **last question is visible** to the user. When the user answers the last (only visible) question, the interface stalls because the system is still waiting for answers to the earlier (hidden) questions.

**Correct pattern:**
```
Turn 1: Ask Question 1 only
Turn 2: Wait for answer to Q1, then ask Question 2 only
Turn 3: Wait for answer to Q2, then ask Question 3 only
```

**Incorrect pattern (causes stalling):**
```
Turn 1: Ask Questions 1, 2, 3 all in one response
[User sees only Q3, answers it, interface stalls]
```

**If multiple sequential questions are needed:** Ask them across multiple turns (one per turn), not all at once. This is slower but avoids the glitch entirely.

**If you want to batch multiple options into one decision:** Use a single `AskUser()` call with multiple `options` (buttons), which renders correctly. This is fine — the glitch affects *multiple questions*, not *multiple options within one question*.

## Project Overview

`pressfreedom` is an R package bundling a Shiny dashboard for exploring the Reporters Without Borders (RSF) Press Freedom Index. The dashboard has three views:

- **Map** — a choropleth of the world, colored by score/rank/dimension for a chosen year; the low-friction entry point into the data.
- **Trends** — multi-country line charts (Score) or bump charts (Rank) over 2002–2025.
- **Country** — a single country's profile: a horizontal Rank/Score stat table, score-band/rank-tier count bar charts, and two combined trend charts (Score + dimensions, Rank + dimension ranks) sharing one deduplicated legend.

Clicking a country on the Map or a point on a Trends chart jumps to its Country profile (see "Shared navigation" below).

### Data model: live dependency on `pressfreedom.data`

`pressfreedom` does **not** bundle its own dataset. It depends on the companion package [`pressfreedom.data`](https://github.com/petzi53/pressfreedom.data) (on CRAN), which owns the cleaned, multi-year `rwb_standardized` dataset (year, score, rank, country/zone/ISO classifications, UN M49 geography, and 2022+ dimension scores) along with all data-cleaning decisions and known-issue documentation.

At app startup, `inst/app/app.R` loads the data directly:

```r
rwb_standardized <- pressfreedom.data::rwb_standardized
```

For anything about the dataset itself — schema, years covered, known data quirks (e.g. the Russia/Russian Federation naming inconsistency, the 2022 zone classification anomaly, factor-coercion history), or the data pipeline that produces it — consult `pressfreedom.data`'s own `AGENTS.md` and documentation, not this file. This package's `AGENTS.md` covers only the Shiny app and package infrastructure that consumes that data.

The companion project `rwb-book` (at `~/Documents/Meine-Repos/rwb-book/`) is a Quarto book documenting the full data pipeline that ultimately feeds `pressfreedom.data`.

### Known data observations in `rwb_standardized`

**Date documented:** 2026-08-05. Four systemic observations were identified in the `rwb_standardized` dataset (owned by `pressfreedom.data`):

1. **`score` inflated in 2008:** ~114 of ~167 countries show scores multiplied by 10–100 (Austria: 35 instead of 3.5–3.6). Pre-2013 scores are **excluded from all analyses and displays in this app** due to RSF's 2013 methodology change. The inflated values suggest a **data transformation issue** (incomplete division by 10 or 100) in the original ingestion and warrant investigation in `rwb-book` for data quality understanding, though correction is not urgent for this app.

2. **`score` anomalies in 2012:** ~65 of ~177 countries show large deviations from neighbors (Austria: -8, Canada: -567, etc.). This was a **special coverage year combining 2011 (unpublished) with 2012**, which may explain the anomalies. Pre-2013 scores are excluded from this app regardless; investigation in `rwb-book` recommended to understand the 2011+2012 combination processing.

3. **`score_evolution` NA for 2003–2021:** Intentional **by design** — year-over-year evolution across the 2013 methodology boundary (incompatible scales) would be invalid. This is not a bug; the column correctly reflects that no valid comparison can be made across this boundary. **Not relevant to this app**, which displays absolute trends over time, not year-over-year changes (unlike RSF's original analysis).

4. **`score_n_1` NA for 2022:** Likely a schema-transition artifact when dimension scores were introduced. Could optionally be backfilled for consistency with RSF's methodology, but **not required for this app**, which does not use year-over-year comparisons.

**For detailed diagnostic evidence and investigation suggestions,** see [`.posit/assistant/docs/2026-08-05-rwb-data-anomalies.md`](.posit/assistant/docs/2026-08-05-rwb-data-anomalies.md) — this serves as a reference for anyone investigating these observations in `pressfreedom.data` or `rwb-book`.

Launch the dashboard with:

```r
pressfreedom::run_app()
```

## Package Structure

```
pressfreedom/
├── R/
│   └── run_app.R       # Exported run_app() function
├── inst/app/
│   ├── app.R           # Shiny entry point: loads pressfreedom.data::rwb_standardized,
│   │                   # wires modules, shared "selected country" reactive,
│   │                   # navset wiring (5 tabs: Map, Trends, Country, Help, About)
│   └── R/
│       ├── helpers.R      # df_chart(), card_title()
│       ├── flags.R        # iso3 -> flagon flag-code mapping, <img>/emoji helpers
│       ├── mod_inputs.R   # compareSidebarUI() / inputsServer() — Trends sidebar
│       ├── mod_chart.R    # compareMainUI() / chartServer() — Trends plotly chart
│       ├── mod_map.R      # mapSidebarUI() / mapMainUI() / mapServer() — Map view
│       ├── mod_country.R  # countrySidebarUI() / countryMainUI() / countryServer()
│       ├── mod_help.R     # helpSidebarUI() / helpMainUI() — Help tab (UI-only)
│       └── mod_about.R    # aboutSidebarUI() / aboutMainUI() — About tab (UI-only)
├── man/                # Generated by roxygen2; do not edit manually
├── DESCRIPTION
├── NAMESPACE           # Generated by roxygen2; do not edit manually
├── renv.lock           # Full library snapshot (type = "all")
└── AGENTS.md           # This file
```

`R/run_app.R` includes a `requireNamespace("pressfreedom.data")` guard as a pre-flight check with a clear error message, and to satisfy R CMD check's "all declared Imports should be used" scan — the check tool can't otherwise see that the Imports entry is used inside `inst/app/app.R`, a runtime-sourced script rather than package code.

## Shiny App Architecture

The app uses a fully modular design (`inst/app/`), built on `bslib::page_navbar()` with a single `id = "view"` navset switching between three `nav_panel()`s wired in `app.R`: **Map**, **Trends**, **Country**. `page_navbar()`'s installed version (0.11.0) has no per-`nav_panel()` `sidebar =` argument — only one page-level `sidebar =`, shared across all panels — so per-view sidebar *content* is achieved with a `navset_hidden(id = "sidebar_view")` inside that single sidebar, kept in sync with the visible navbar tabs via a `nav_select("sidebar_view", input$view)` observer in the server.

- **`mod_map`** — choropleth (`plotly::plot_geo()`) colored by Score, Rank, or a 2022+ dimension. Year choices react to both `zone` and `metric` (dimensions restrict to 2022+, score to 2013+). Score-like metrics use RSF's real 5-class band classification; Rank uses percentile tiers — both exposed as independent `checkboxGroupInput` toggles that grey out (not remove) unchecked bands. See "Map score/rank bands" below.
- **`mod_chart`** (Trends) — renders a `plotly` card, reused in two contexts: the standalone Trends view (multi-country, `show_nav = TRUE`) and embedded in the Country view in compact mode for a single country (`show_nav = FALSE`). Score → scatter line chart; Rank → `ggbump` bump chart converted via `ggplotly()`. All interactive behavior (hover-dimming and click-to-navigate) is handled client-side via JavaScript (`onRender`) — see "Client-side JavaScript approach for chart interactivity" below for why and how.
- **`mod_country`** — flag/name header; an overview card with a horizontal Rank/Score stat table (current/best/worst/mean-or-median/biggest advance/biggest decline) plus two small band/tier count bar charts (score bands via `rsf_band()`, rank tiers via `rank_tier()` with a per-year `max_rank`, both reused from `mod_map.R`); and a trend row with two bespoke combined charts — Score (+ the 5 context dimensions, 2022–2026) and Rank (+ the 5 dimension-rank columns, `rank_pol` etc.) — merged via `plotly::subplot()` with one deduplicated, floating legend (dimension traces share a `legendgroup` across both panels; only the score panel's copy sets `showlegend = TRUE`). These are hand-built `plot_ly()`/`ggplot2`+`ggbump` calls local to `mod_country.R`, not a reuse of `mod_chart.R` — see "Dimension data (2022+): per-view treatment" below for why.
- **`mod_inputs`** (Trends sidebar) — `selectInput`s for variable (Score/Rank only — dimensions intentionally excluded, see below) and country (multiple selection).
- **`helpers.R`** — `df_chart()` filters/prepares data; `card_title()` builds the dynamic card header; `csv_notes()` and `write_csv_with_notes()` generate and export data with dynamic caveats (see "CSV data download per view" below).
- **`flags.R`** — maps `rwb_standardized$iso` (alpha-3) to `flagon`'s alpha-2 flag codes; see "Flags (`flagon`)" below.

`app.R` wires the modules and loads data via `pressfreedom.data::rwb_standardized`. All module files use explicit package namespacing (e.g., `shiny::`, `dplyr::`) so no additional `library()` calls are needed inside modules, except `library(ggplot2)` in `app.R` (required because `ggplotly()` resolves variables by name on the search path).

**Score scale-transition artifact (2013)**: RSF changed its scoring methodology in 2013. `score` itself exists back to 2002, but pre-2013 and 2013+ values sit on two incompatible scales — mixing them in any aggregate (mean/median, band counts, min/max) understates or overstates real standing. `score_evolution` (`score - score_n_1`) additionally compares those two scales directly for the single transition year, producing artifacts as large as +5,763 that aren't real year-over-year changes. `rank_evolution` is unaffected (rank is a same-year relative ordering in both years, regardless of the underlying score scale). **Resolution**: `mod_country.R`'s score stat block (`stat_table`) and score-band bar chart (`score_band_data`) both filter to `year_n >= 2013` before computing anything, and `score_evolution` is additionally set to `NA` for `year_n == 2013` itself (scoped locally — the underlying `rwb_standardized$score_evolution` column is untouched) since even the first comparable year's evolution is a diff against an incompatible prior value. If you use `score` or `score_evolution` elsewhere in a multi-year aggregate, apply the same `year_n >= 2013` filter (and the 2013 `score_evolution` exclusion, if using evolution) or you will surface this artifact.

### Shared navigation

Both the Map's click-to-navigate and Trends' click-to-chart point click feed into a single `selected_country` reactiveVal in `app.R`, rather than each view running its own copy of the navigation logic. One observer downstream does the actual work: `nav_select("view", "Country")` (which also drives the sidebar's `navset_hidden` via the sync observer above) and preselect the clicked country there. If you add a third click-to-navigate entry point, feed it into `selected_country` too rather than duplicating that observer.

#### Trends <-> Country selection sync (independent of the click-to-navigate flow above)

Separately from click-to-navigate, the Trends multi-country list and the Country view's single-country selector are kept in sync in **both directions**, without ever forcing a tab switch:

- **Country -> Trends:** `country_selected <- countryServer("country", ...)` is watched by an `observeEvent()` in `app.R` that appends the newly-selected country to `inputs-country` (via `updateSelectInput()`) if it isn't already present. Clearing Country's selection (the "Clear" button, or picking the blank placeholder option) runs the mirror-image action: it drops the *last* country from the Trends list via `utils::head(current_trends_selection, -1)`. If Trends still has other countries after that removal, the `last_country` resync (described next) immediately repopulates Country with the new last one — Country is always a mirror of Trends' last entry, so "clear" only leaves it blank once Trends itself becomes empty. A removal attempt against an already-empty Trends selection (e.g. when this observer fires from the echo of the Trends -> Country resync itself) is a harmless no-op.
- **Trends -> Country:** `mod_inputs.R`'s `inputsServer()` returns a `last_country` reactive — `tail(input$country, 1)` (or `NA_character_` when the list is empty), recomputed on every change to the Trends selection. An `observeEvent(sel$last_country(), ...)` in `app.R` resyncs `country-country` to that value on every change.

The Trends -> Country direction is a "keep in sync with whatever is currently last in the list" resync, not an add/remove event log — it intentionally does **not** distinguish additions from removals:

| Trends list action | New last element? | Country view changes? |
| :-- | :-- | :-- |
| Append a 6th country | Yes (the new one) | Yes — switches to it |
| Remove a *non-last* country (e.g. the 3rd of 5) | No — unchanged | No (resync fires but is a no-op) |
| Remove the *last* country | Yes (the new last, e.g. the old 4th) | Yes — switches to it |
| Clear all / Reset all (list becomes empty) | `last_country()` is `NA_character_` | Yes — Country's selection is blanked (`""`) |

`last_country` is a **plain derived `reactive()`, not a `reactiveVal` with a nonce** — unlike `selected_country` above, there's no need to defeat identical-value skipping here: `app.R`'s observer is watching a reactive expression (which re-invalidates on every upstream `input$country` change regardless of whether the computed `tail()` value actually differs), not a `reactiveVal` being reassigned. A same-value resync (the "non-last removal" row above) is simply a harmless no-op `updateSelectInput()` call, not a skipped one.

Emptying the Trends list blanks Country's selection rather than leaving a stale value behind — `last_country` is `NA_character_` in that case, and the observer maps that to `selected = ""`. This keeps Country from ever displaying a country that no longer appears anywhere in the Trends list, a state a user has no way to reach by interacting with Country directly (the standard master-detail convention: an empty source list implies an empty derived selection, not a frozen last value).

This also means the two directions above tolerate re-triggering each other harmlessly: e.g. a Country -> Trends append makes the appended country both the new last-in-Trends-list *and* already Country's current selection, so the Trends -> Country resync it triggers just reasserts the same value. Same for the Map/Trends click-to-navigate flow, which also appends to the Trends list via `inputsServer()`'s own internal `observeEvent(selected_country(), ...)`.

#### Nonce collision pitfall: identical values silently skip `reactiveVal` observers

Both the Map and Trends modules return `list(country = ..., nonce = ...)` to the app-level `selected_country` reactiveVal. The nonce is **critical** — `reactiveVal` silently skips calling observers when assigned an `identical()` value to its current one.

**Before the fix (module-local integer counters):** Each module used `click_nonce <- 0` and incremented by 1 on each click. Clicking the same country on the map (`nonce = 1`) and then on the chart (`nonce = 1`) produced `identical()` values:
```r
# map click
selected_country(list(country = "Algeria", nonce = 1))

# chart click on same country
selected_country(list(country = "Algeria", nonce = 1))  # identical(), observer skipped
```

This silently broke navigation on the first chart click in a session (before any second clicks could increment the chart nonce beyond 1).

**Fix:** Use `as.numeric(proc.time()[["elapsed"]])` instead of integer counters. The elapsed seconds since R process startup are globally unique across modules and re-executions:
```r
# map click
selected_country(list(country = "Algeria", nonce = 12345.678))

# chart click on same country
selected_country(list(country = "Algeria", nonce = 12345.789))  # not identical(), observer fires
```

Apply this pattern in any new module that feeds into `selected_country` or any other `reactiveVal` that needs to distinguish repeated values.

#### Client-side JavaScript approach for chart interactivity

All interactive behavior on the Trends chart (both click-to-navigate and hover-dimming) is now handled entirely **client-side** via JavaScript (`htmlwidgets::onRender`), rather than R-side plotly event handlers and `plotlyProxy` restyle commands.

**Why:** Early attempts used R-side `plotlyProxy()` restyle on hover to dim non-hovered traces. On the very first hover (before client-side plotly traces were fully initialized), this triggered a `coerceTraceIndices` error in plotly's JavaScript. The error ran in the same Shiny message batch as the navigation `nav_select()` triggered by a simultaneous click, and the error **aborted the entire message batch**, silently swallowing the navigation command.

**Current implementation:** In `mod_chart.R`'s `renderPlotly`, the `onRender` callback installs three event listeners:

1. **Click-to-navigate:** Extracts the country name directly from the clicked trace (`el.data[curveNumber].name`, set by `plot_ly(color=)` or `ggplot aes(color=)`), and calls `Shiny.setInputValue()` with `priority = 'event'` to ensure every click fires.

2. **Hover-dimming:** Extracts the hovered `curveNumber`, loops through all traces, and sets opacities to 1 for the hovered trace and 0.15 for all others via `Plotly.restyle()` — instant, no server round-trip.

3. **Unhover:** Restores all traces to full opacity.

This design eliminates the timing issue and makes hover-dimming snappier. Do **not** revert to `plotlyProxy` restyle in `observeEvent(event_data("plotly_hover", ...))` — the `coerceTraceIndices` error will return.

#### Trends tooltip content and the bump chart's legend dedup

Both Trends chart types show a 3-line hover tooltip — flag emoji + country name, `Year: <n>`, and `Score:`/`Rank: <value>` — built as an explicit `hover_text` column (`flag_emoji(iso)` + `country_en` + `year_n` + the metric value) rather than relying on plotly's default x/y/name hover. The **score** branch is native `plot_ly()`, so this is direct: `text = ~hover_text, hoverinfo = "text"`. The **rank** branch goes through `ggplot2` + `ggbump::geom_bump()` + `ggplotly()`, which is more constrained:

- `hover_text` is mapped via `ggplot2::aes(text = hover_text)` **only on `geom_point()`** (the real yearly data points), not on `geom_bump()` (a stat-transformed, interpolated curve whose intermediate rows aren't real year/rank pairs — mapping `text` there would show misleading values). `ggplotly(p, tooltip = "text")` then uses that mapping.
- Because `geom_bump()`'s line layer has no `text` aes, `ggplotly()` would otherwise show an empty/`NA` hover box when hovering the connecting curve between two yearly points. Fixed by identifying line-mode traces post-hoc and disabling their hover entirely: `plotly::style(p_final, hoverinfo = "none", traces = line_traces)` where `line_traces <- which(vapply(p_final$x$data, function(tr) identical(tr$mode, "lines"), logical(1)))`.
- **Legend gotcha (verified empirically):** `ggplotly()` auto-deduplicates legend entries that share a `legendgroup` (here, country) — it keeps exactly one legend entry per country regardless of each ggplot layer's own `show.legend` setting, and it's always the *first* layer's trace that keeps `showlegend = TRUE` (here, the line trace from `geom_bump()`), not necessarily the one you set `show.legend = TRUE`/left as default on. This meant the rank chart's legend swatch showed a line only, unlike the score chart's single native `plot_ly()` trace, which shows a combined line+point swatch — an inconsistency. It also had a second effect: since each country is split across two real traces (a "lines" trace from `geom_bump()` and a "markers" trace from `geom_point()`), the hover-dimming JS (keyed off `curveNumber`, see below) would dim one sub-trace while the other stayed bright, producing a visible flicker when the mouse tracked the curve between exact data points.
  - **Fix:** decouple the legend from the real traces entirely. `plotly::style(p_final, showlegend = FALSE, traces = seq_along(p_final$x$data))` hides the legend on every real trace, then one proxy `add_trace()` per country supplies a single `"lines+markers"` swatch sized to match the score chart (`marker = list(size = 20)`, `line = list(width = 4)`).
  - **Proxy trace point placement — do not use `numeric(0)` or `NA`:** an empty vector (`x = numeric(0), y = numeric(0)`) looks like the safest way to make the proxy trace invisible, but `plotly::plotly_build()` was found (empirically) to silently corrupt it — the trace's `x`/`y` end up as the literal strings `"x"`/`"y"` instead of numeric data, and the legend entry never renders. A scalar `NA` point has the opposite problem: `plot_ly()`'s trace-building drops it, along with its `name`/`legendgroup` metadata, since it looks like "no data was mapped". The fix that works: a real, far-out-of-range scalar point (`x = -1e6, y = -1e6`). `ggplotly()` already fixes this chart's axis ranges explicitly (`autorange = FALSE` on both axes, confirmed via `p_final$x$layout`), so the sentinel point is simply clipped off-canvas by the fixed range and can't perturb the visible plot or trigger autorange.
  - The hover-dimming fix (grouping by trace `name`/country rather than `curveNumber`, so a country's "lines" and "markers" sub-traces dim together) lives in the shared `onRender` script — see "Client-side JavaScript approach for chart interactivity" above.
  - If you add a third color-mapped layer to this chart, re-verify this whole proxy-trace setup — a new real trace changes which trace `ggplotly()` would otherwise pick for `showlegend = TRUE`, though the explicit `style(showlegend = FALSE, ...)` over *all* real traces should absorb it automatically.
- Legend entry **order** is sorted to match the curves' vertical position at the final year: ascending rank (best rank first, since `scale_y_reverse()` puts "best" at the top) — the rank-axis mirror of the score branch's descending-by-value sort, which was already in place before this change.
- The bump chart's start/end `geom_text(label = iso)` layers (ISO codes at both ends of each curve) were removed once the legend took over identifying which curve is which country.

## Map score/rank bands

Score-like metrics (Score + all five dimensions, all 0–100 scales) use RSF's real 5-class classification, taken from RSF's methodology page (its legend axis reads `0 40 55 70 85 100`):

| Band | Score range |
| :-- | :-- |
| Good | 85–100 |
| Satisfactory | 70–85 |
| Problematic | 55–70 |
| Difficult | 40–55 |
| Very Serious | 0–40 |

Rank uses percentile tiers instead (top 2.5% / 2.5–15% / 15–85% / 85–97.5% / bottom 2.5%), computed relative to that year's maximum rank — not a data limitation, just a different natural binning for an ordinal, single-year-relative metric. Both band sets share the same best→worst 5-color palette and the same checkbox-toggle interaction on the map.

### Band/tier checkbox state persists per metric type

Score-like metrics (Score + the five dimensions) and Rank each remember their own checkbox selection independently, via two `reactiveVal`s in `mapServer()`: `score_bands_selected` and `rank_tiers_selected` (both initialized to their full level set). Switching `input$metric` away and back restores whatever was checked before, rather than resetting to "all checked".

**Prior bug:** the band checkboxGroupInput used to live behind `output$bands_ui <- renderUI({...})`, keyed on `input$metric`, and every rebuild hard-coded `selected = levels_` (the full set). This meant checking only "Good" under Score, switching to Rank, then switching back to Score reset Score's checkboxes to fully-checked — even though nothing about Score's own selection should have changed. The renderUI rebuild had no memory of prior state.

**Fix:** the `checkboxGroupInput(ns("bands"), ...)` widget itself now lives statically in `mapSidebarUI()` (initialized to the Score bands, matching the default metric), not behind a `uiOutput`/`renderUI`. An `observeEvent(input$metric, ...)` in `mapServer()` calls `shiny::updateCheckboxGroupInput()` to swap `choiceNames`/`choiceValues`/`label` for the new metric type, sourcing `selected` from whichever of the two reactiveVals matches the type being switched *to*. A separate `observeEvent(input$bands, ...)` (which already existed, to maintain `checked_bands()` for rendering) additionally saves every change into the reactiveVal matching the *current* `input$metric` — this ordering is safe because Shiny delivers the `input$metric` change before the `input$bands` change that `updateCheckboxGroupInput()` triggers, so `input$metric` is never stale when attributing a save.

`do_reset_map()` (Clear button / app-level Reset all) resets both `score_bands_selected` and `rank_tiers_selected` back to their full default sets *before* resetting `metric`, and separately forces the checkbox group back to the Score bands directly — this covers the case where `metric` is already `"score"` when Clear is clicked, which wouldn't otherwise re-fire the metric-change observer.

If you add a third checkbox-backed grouping dimension to the map (e.g. a per-zone filter), apply the same pattern: a static widget in the sidebar UI, one reactiveVal per "type" to remember its selection, and an `updateCheckboxGroupInput()` call (not a renderUI rebuild) to switch between them.

### "Deselect all" clobbering a just-restored partial selection on metric switch

**Symptom (reported, reproduced, and fixed):** customize Score to a partial selection (e.g. only "Good"), switch to Rank and customize it too (e.g. only "Top 2.5%"), then switch back to Score — the just-restored partial selection got silently overwritten back to "everything checked" (all countries colored). Confusingly, this appeared asymmetric: sometimes the *Score* revisit failed and the *Rank* revisit succeeded, sometimes the reverse — depending only on which metric the user had most recently used the "Deselect all" checkbox on before switching away from it.

**Root cause:** the "Deselect all" checkbox (`input$deselect_all`) is a stateful toggle — checking it clears every band, unchecking it restores the full set — implemented via `observeEvent(input$deselect_all, ...)` unconditionally calling `updateCheckboxGroupInput(..., selected = if (checked) character(0) else levels_)`. Separately, the code needs to keep this toggle's *displayed* value honest as a side effect of other actions (e.g. syncing it to unchecked when the user manually re-checks one band after using "Deselect all", or resetting it when the metric-change observer restores a saved non-empty selection). Both of those side effects work by calling `shiny::updateCheckboxInput(session, "deselect_all", value = ...)`. But `updateCheckboxInput()` changing the value *is itself indistinguishable, from inside the `input$deselect_all` observer, from a genuine user click* — so a programmatic "sync the display to unchecked" call would immediately retrigger the observer's full-reset logic, overwriting the very selection that triggered the sync (e.g. the metric-change observer's own just-applied restore).

**Fix:** a `deselect_all_tracked` reactiveVal records the value this module itself most recently assigned to `input$deselect_all` (whether via a genuine user click or a programmatic sync). Every programmatic `updateCheckboxInput(session, "deselect_all", value = X)` call is preceded by `deselect_all_tracked(X)`. The `observeEvent(input$deselect_all, ...)` handler then opens with `if (identical(input$deselect_all, deselect_all_tracked())) return(invisible(NULL))` — so when the update's echo arrives from the client, it's recognised as this module's own doing and the destructive reset is skipped; only a value that differs from `deselect_all_tracked()` (a real, new user click) runs the reset logic. The `input$bands` observer also gained a matching sync block (see comment there) to fix the closely-related "Deselect all stays checked after the user manually re-checks a band" bug — same guard, same reactiveVal.

**Do not remove `deselect_all_tracked` or "unwrap" it as an unnecessary indirection** — every one of `do_reset_map()`, the metric-change observer, and the `input$bands` sync block relies on it to make their own `updateCheckboxInput()` calls silent no-ops from the `input$deselect_all` observer's point of view.

### Preserving zoom/pan across control changes

The map's zoom and pan state should persist when the user changes sidebar controls (Metric, Year, Zone, band/tier checkboxes) or switches tabs away and back. This is achieved via plotly.js's `uirevision` layout attribute: when `uirevision` remains constant across figure redraws (which Shiny triggers on every control change), plotly.js preserves user-driven view state (zoom, pan, geo projection). When `uirevision` changes, the view resets to the layout's default.

In `mapServer()`, a `reactiveVal` named `map_view_id` holds a unique token (via `proc.time()[["elapsed"]]`) that is passed to `plotly::layout(..., uirevision = map_view_id())` on every render. Under normal circumstances — metric switch, band toggle, year/zone change — `map_view_id()` never changes, so the zoom/pan sticks. Only `do_reset_map()` (called by the sidebar's "Clear" button or the app's "Reset all" button) bumps this value, triggering plotly.js to drop back to the default geo view.

**`uirevision` alone is not sufficient — also requires `transition` in the layout.** The `plotly` R package's Shiny htmlwidget binding (`renderValue()` in its JS) only calls `Plotly.react()` — the call that actually honors `uirevision` — when `layout$transition` is truthy. Without it, every `renderPlotly()` re-run instead does `Plotly.purge()` followed by `Plotly.newPlot()`, a full teardown/rebuild that discards any preserved zoom/pan state regardless of whether `uirevision` matched. The map's `plotly::layout()` call therefore also sets `transition = list(duration = 0)` (zero duration so there's no visible animation, just to route through the `react()` code path). This was verified empirically: with `uirevision` alone, zoom/pan still reset on every control change; switching tabs and back "worked" only because that path never re-executes `renderPlotly()` at all, so it never exercised the purge/newPlot bug.

**Important:** Do not mutate `map_view_id()` elsewhere in the module, and do not remove either the `uirevision` or `transition` entries from the `plotly::layout()` call — both are required together. Future changes to band/tier logic or the control-change reactive chain should not affect this mechanism.

**Do not route band/tier color changes through `plotlyProxy()` restyle calls as a "lighter-weight" alternative to a full `renderPlotly()` re-render.** This was tried (reading `checked_bands()` only in a separate `observeEvent()` that restyled trace colors by index, while `output$map` itself ignored checkbox state) on the theory that skipping the full re-render would help preserve zoom/pan. It's unnecessary now that `uirevision`/`transition` already make full re-renders preserve zoom/pan, and it actively broke color rendering: the proxy restyle's trace-index bookkeeping (built by re-walking `levels_`/`map_data()` and skipping empty bands) can race with a concurrent full re-render triggered in the same reactive flush (e.g. `do_reset_map()` changing metric/zone/year and band selection together), targeting stale or mismatched trace indices and leaving the map uncolored — intermittently on "Clear", reliably enough to look "random". `output$map`'s `renderPlotly()` reads `checked_bands()` directly and rebuilds all traces on every relevant change instead; this is the correct, current design — keep it that way.

## Dimension data (2022+): per-view treatment

Dimension scores (`political_context`, `economic_context`, `legal_context`, `social_context`, `safety`) exist for only 5 of the dataset's 24 years (2022–2026), so each view treats them differently rather than forcing them into a multi-year picker they don't suit yet:

| View | Treatment | Why |
| :-- | :-- | :-- |
| **Map** | Coloring option, single year at a time (year choices restrict to 2022–2025 when picked) | Already single-year by construction — a snapshot is the natural unit regardless of series length. |
| **Trends** (multi-country) | Dropped from variable picker (charts show Score/Rank only); exported in CSV with all 5 dimension columns (NA-padded pre-2022) | Charts: Comparing 5 dimensions × countries over 4 years, shared with 23 years of Score/Rank, is unreadable. CSV: Export includes dimensions for data completeness; users can filter/ignore NAs. |
| **Country** (single country) | Overlaid onto the Score/Rank trend charts as 5 thin lines each (2022–2026 only, naturally), sharing a deduplicated legend via `legendgroup` — see `mod_country`'s bullet above | With one country, 5 years × 5 lines is legible and shows a genuine short trend — the complexity-vs-information ratio that's bad in Trends is fine here because both the country count (1) and the axis (each panel's own natural range: 2013–2026 for score, ~2003–2026 for rank) are scoped correctly. |

**Trends CSV exports:** The downloaded CSV files from the Trends view include all five dimension columns (`political_context`, `economic_context`, `legal_context`, `social_context`, `safety`) in addition to Score or Rank. Dimension values are `NA` for all years before 2022 (when the methodology changed); this is annotated in the CSV header. Filenames are contextual: `pressfreedom_trends_{variable}_{country}.csv` for a single country, or `pressfreedom_trends_{variable}_compare_countries.csv` when comparing multiple countries. The exported data is not charted in Trends — dimension trends remain available in the Country view (single-country focus, 5 years of data, much more legible than a multi-country dimension scatter).

**Revisit at a future annual update**: as dimensions accumulate more years — a decade's worth by ~2032 — reconsider whether they've earned a slot in the Trends variable picker too. Not done as of this writing (2026 is the 5th year of dimension data).

## Flags (`flagon`)

Flags are served via [`flagon`](https://github.com/coolbutuseless/flagon) (GitHub-only; `Remotes:` in `DESCRIPTION`), which installs PNG/SVG files on disk indexed by **2-letter ISO 3166-1 alpha-2** codes. `app.R` calls `shiny::addResourcePath("flags", system.file("png", package = "flagon"))` once at startup so `<img src="flags/xx.png">` works anywhere in the app.

`rwb_standardized$iso` is **3-letter** and is **not a clean 1:1 country mapping** — `flags.R`'s `iso3_to_flag_code()` resolves the ~190 standard cases via `countrycode::countrycode(iso3, "iso3c", "iso2c")` and applies a manual override table for the rest:

| Issue | Example `iso` value(s) | Resolution |
| :-- | :-- | :-- |
| Kosovo uses two different non-standard codes across years | `XKX`, `XKO` | Mapped to `xk` (flagon has this code) |
| Northern Cyprus | `CTU` | No flag (no ISO flag code exists) |
| OECS (a regional organization, not a country) | `CSS`, `XCD` | No flag (no single national flag applies) |
| Israel territory sub-entries | `ISR1`, `ISR2`, `ISR3` | No flag (ambiguous — unlike the US splits below) |
| US territory sub-entries | `USA1`, `USA2`, `USA_I` | Mapped to `us` (unambiguous, unlike the Israel splits) |
| Defunct historical states (old years only) | `YUG`, `SCG` | No flag (not in flagon's source) |

Anything else unmapped falls back to `NA` → no flag image / no emoji, rather than a broken image or an error. Plotly hover templates only support a small HTML subset and don't reliably render `<img>`, so the map tooltip uses `flag_emoji()` (Unicode regional-indicator emoji) instead of `flag_img_tag()`; the Country view header and Trends' click popover use the real `<img>` version since they render actual HTML.

## Help tab

A dedicated user-facing reference for navigating the dashboard and using its interactive features. Like the About tab, it's a static, UI-only tab that serves content from a markdown file.

- **`mod_help.R`** — UI-only, no server; loads markdown content from
  `inst/app/www/help.md` at runtime and renders it: `helpMainUI()`
  builds the main content (an intro paragraph always visible, plus a
  `bslib::accordion()` with five collapsible panels parsed directly from
  the markdown file and all collapsed by default), and `helpSidebarUI(id)`
  builds the sidebar's "Back to Dashboard" button (the tab has no filters).
  There's no `helpServer()` — nothing here is reactive — so the "Back to
  Dashboard" button's `observeEvent()` is wired directly in `app.R`'s server
  alongside the About tab handler, reading `input[["help-back_to_dashboard"]]`
  manually rather than through `moduleServer()` scoping. The
  `parse_help_sections()` helper splits the markdown by `## ` level-2 headings
  and renders each section to HTML via `shiny::markdown()`.
- **Text content lives in `inst/app/www/help.md`**: all Help-page prose
  (dashboard overview, per-view navigation, chart interaction, toolbar icons,
  download procedures, and FAQ) is maintained as plain markdown text, separate
  from R code. To update the Help page, simply edit `help.md` — no R coding
  needed. The markdown file's five level-2 headings (`## Navigating the
  dashboard`, `## Reading the charts`, `## The chart toolbar`,
  `## Downloading data`, `## Frequently asked questions`) automatically become
  the accordion panel titles; everything before the first heading is the
  always-visible intro paragraph.
- **Plotly modebar and CSV download notes are explained here**: the Help tab
  explicitly addresses the small toolbar icons (camera, zoom, pan, autoscale,
  reset) with icons sketched in plain language, and provides detailed guidance
  on CSV exports (specifically that downloaded files start with 1–3 comment
  lines prefixed with `#`, so the real column headers appear at row 3 or 4,
  not row 1). This is the main user-facing documentation for these
  less-intuitive features.
- **Sidebar behavior**: entering/leaving the Help tab does **not**
  toggle the sidebar's open/closed state — whatever the user had it set to
  is left untouched, exactly like switching between any other pair of tabs.
  The sidebar's `navset_hidden()` still needs a matching
  `nav_panel_hidden("Help", helpSidebarUI("help"))` purely so the
  existing "view" -> "sidebar_view" sync observer has a panel to select.

## About tab

A permanent `page_navbar(footer = ...)` attribution line was tried first but
was dropped — it permanently consumed vertical space on every tab (worst on
the space-constrained Map view) for a single line of content. Replaced with
a 5th `nav_panel("About", aboutMainUI(rwb_standardized))`, which costs no
space unless a user visits it and has room for much richer content
(methodology, limitations, citation).

- **`mod_about.R`** — UI-only, no server; loads markdown content from
  `inst/app/www/about.md` at runtime and renders it: `aboutMainUI(data)`
  builds the main content (a provenance paragraph always visible, plus a
  `bslib::accordion()` with "Data & Methodology", "Limitations & Caveats",
  and "Citation & Contact" panels parsed directly from the markdown file
  and all collapsed by default), and `aboutSidebarUI(id)` builds the
  sidebar's "Back to Dashboard" button (the tab has no filters). There's no
  `aboutServer()` — nothing here is reactive — so the "Back to Dashboard"
  button's `observeEvent()` is wired directly in `app.R`'s server
  alongside the Help tab and title-click handlers, reading
  `input[["about-back_to_dashboard"]]` manually rather than through
  `moduleServer()` scoping. The `parse_about_sections()` helper splits the
  markdown by `## ` level-2 headings and renders each section to HTML via
  `shiny::markdown()`.
- **Text content lives in `inst/app/www/about.md`**: all About-page prose
  (intro paragraph, methodology bullets, limitations, citations, contact
  info) is maintained as plain markdown text, separate from R code. To
  update the About page, simply edit `about.md` — no R coding needed. The
  markdown file's three level-2 headings (`## Data & Methodology`,
  `## Limitations & Caveats`, `## Citation & Contact`) automatically become
  the accordion panel titles; everything before the first heading is the
  always-visible intro paragraph.
- **Dashboard version and data-year coverage are computed, not hand-typed**:
  `tryCatch(utils::packageVersion("pressfreedom"), ...)` (falls back to
  "development version" under `devtools::load_all()`, which has no
  installed version to read) and `range(data$year_n)`, so neither can go
  stale as the package version bumps or new data years are added. These
  appear at the bottom of the "Citation & Contact" accordion panel.
- **Sidebar behavior**: entering/leaving the About tab does **not**
  toggle the sidebar's open/closed state — whatever the user had it set to
  is left untouched, exactly like switching between any other pair of tabs.
  The sidebar's `navset_hidden()` still needs a matching
  `nav_panel_hidden("About", aboutSidebarUI("about"))` purely so the
  existing "view" -> "sidebar_view" sync observer has a panel to select.

## Image download (plotly modebar)

All plotly charts across the three data views (Map, Trends, Country) use
plotly's default modebar (`displayModeBar` left at its default of `TRUE`),
which includes the camera icon for exporting the current view as a PNG.
Country's charts (`band_bar_chart()`'s two small bar charts, and the
combined trend `subplot()`) previously disabled this via
`plotly::config(displayModeBar = FALSE)`, which was an inconsistency with
Map/Trends rather than a deliberate design decision — fixed by removing/
flipping those calls. The combined trend chart's `plotly::config()` call
is still needed even with the modebar back on: `plot_ly()` and
`ggplotly()` each stamp a top-level `$x$config` that `subplot()` can't
merge cleanly, so exactly one panel's config is kept and explicitly set
(`displayModeBar = TRUE`) rather than stripped from both — see the inline
comment above `p_rank$x$config <- NULL` in `mod_country.R`.

## CSV data download per view

Each of the three views (Map, Trends, Country) includes a "Download CSV" button that exports that view's **current filtered slice**, not the entire `rwb_standardized` table:

- **Map**: sidebar button below "Clear" (disabled with "No countries available for this selection." message when no bands/tiers are checked or the selected Zone+band combination matches zero countries); exports the single-year snapshot filtered by Metric, Zone, and checked bands/tiers only; **drops the 5 dimension columns for pre-2022 years** (they exist only from 2022 onward, so pre-2022 values are all-NA anyway, and removing them shrinks empty exports); filename: `pressfreedom_map_<metric>_<year>_<zone_slug>.csv` (e.g., `pressfreedom_map_score_2025_world.csv` or `pressfreedom_map_rank_2025_americas.csv`).
- **Trends**: sidebar button below "Clear" (only visible when countries are selected); exports all selected countries' Score/Rank history for the selected metric **including all 5 dimension columns** (NA-padded pre-2022); filename is contextual: `pressfreedom_trends_<variable>_<country>.csv` for a single country (e.g., `pressfreedom_trends_rank_austria.csv`), or `pressfreedom_trends_<variable>_compare_countries.csv` when multiple countries are selected (e.g., `pressfreedom_trends_score_compare_countries.csv`).
- **Country**: sidebar button below "Clear" (only visible when a country is selected); exports the full history (all years) for the selected country **minus the previous-year comparison columns** (`rank_n_1`, `rank_evolution`, `score_n_1`, `score_evolution` — kept internal to the stat-table calculations but excluded from exports, consistent with the app's principle of showing absolute trends, never year-over-year changes); filename: `pressfreedom_country_<country>.csv` (spaces replaced with underscores).

### Dynamic caveats on exports

Each view generates its own notes for CSV exports:

**Map view:**
- Exports a single-year snapshot, so the generic score/2011 caveats are inapplicable.
- Instead, a single **custom descriptive line** is generated by `map_download_note()` (local to `inst/app/R/mod_map.R`), listing the metric, region, year, and the checked bands/tiers with their numeric ranges. Examples:
  - `Scores of the Region 'World' for 2025: Selected range Good (85-100), Satisfactory (70-85), Problematic (55-70), Difficult (40-55), Serious (0-40).`
  - `Ranks of the Region 'Americas' for 2025: Selected tiers Top 2.5%, 2.5%-15%.`
  - `Political Context scores of the Region 'Africa' for 2024: Selected range Good (85-100).`

**Trends and Country views:**
- Use the generic, **automatic, content-driven caveat comments** (prefixed with `#`) via the `csv_notes()` helper in `inst/app/R/helpers.R`:

1. **Score methodology caveat** — appears when the export contains `score` values (Country view only; Trends view skips this since data is always 2013+): "RSF changed its scoring methodology in 2013 — score values from 2002–2012 are on a different, non-comparable scale to 2013–present scores. Do not average or compare scores across that boundary."

2. **Dimension availability caveat** — appears when the export includes dimension columns (both Trends and Country views, always; dimensions are always present in `df_chart()` output): "Context factors (political, economic, legal, social context, and safety) are not available (NA) before 2022."

3. **2011 data gap caveat** — appears when the export spans a year range that straddles 2011 (i.e., `min(year_n) ≤ 2010` AND `max(year_n) ≥ 2012`): "2011 has no published index and is absent from this data — a gap in RSF's own release history, not a data-cleaning artifact."

Both helpers (`csv_notes()` and `write_csv_with_notes()`) live in `inst/app/R/helpers.R`. `csv_notes()` now accepts an optional `for_trends` parameter (default FALSE) to conditionally suppress the score methodology caveat when called from the Trends view (where it's always moot). `write_csv_with_notes()` accepts both `notes =` and `for_trends =` parameters: when `notes` is provided, it bypasses auto-detection entirely (Map uses this for custom descriptive lines); when `for_trends = TRUE`, it passes that flag to `csv_notes()` for Trends-specific logic. This ensures notes remain correct if view filtering changes later.

**Specific note applicability per view:**
- **Map**: Single custom descriptive line (metric, region, year, selected bands/tiers with ranges).
- **Trends Score**: Dimension note + 2011 note (if spanning it); filtered to 2013+ (no score methodology note, data never crosses 2013 boundary).
- **Trends Rank**: Dimension note + 2011 note (if spanning it); full history back to ~2002 (no score methodology note; rank unaffected by 2013 break).
- **Country**: Score note (if data spans pre-2013) + Dimension note + 2011 note (if spanning it); full history 2002–2025.

### Map Metric dropdown: Year-based restriction

The Map's Metric dropdown normally offers all 7 options (Score, Rank, 5 dimensions). When a pre-2022 year is selected, the dropdown is restricted to Score/Rank only (dimensions exist only from 2022 onward), via a new `observeEvent(input$year, ...)` in `mapServer()`. This is the reverse direction of the existing **metric → year** restriction (picking a dimension metric restricts years to 2022+).

The two-way sync is safe against feedback loops: the year observer only changes the metric when the currently-selected metric becomes invalid under the new constraint — an unreachable case in normal use, since pre-2022 years are available only when a dimension metric wasn't already selected. `do_reset_map()` needs no special handling: it resets year to the dataset's max (currently 2026, ≥ 2022), which automatically restores the full metric option set via the year observer.

### Country CSV export: Internal vs. external column usage

`country_data()` (the module's internal data source for stat-table calculations) retains all columns including `rank_evolution` and `score_evolution` — these are needed for the stat block's "Biggest advance/decline" figures. A separate `country_download_data()` reactive drops these 4 comparison columns before passing to `write_csv_with_notes()` for export, so the exported CSV shows absolute values only while internal displays still have access to the evolution metrics they require.

**Modebar/border overlap on the combined trend chart:** turning the
modebar back on exposed a separate issue — the plotly R package's own
default top margin is only 25px, too little clearance for the modebar to
sit above the rank panel's top border line (`showline`/`mirror`, set in
`set_axis_font()`) without visibly overlapping it. Fixed by setting an
explicit `margin = list(t = 40, ...)` in the combined chart's final
`plotly::layout()` call. The two small band/tier bar charts
(`band_bar_chart()`) don't need this — they draw no panel border at all,
so their modebar can overlap empty space at the default margin without
being noticeable.

## Favicon (`inst/app/www/`)

`inst/app/www/favicon.ico` and `inst/app/www/favicon.png` are generated artifacts, not source files — regenerate them from `man/figures/logo.png` if the logo ever changes, rather than hand-editing. Shiny serves `inst/app/www/` automatically as static content because it's a `www/` folder sitting next to `app.R`; no `addResourcePath()` call is needed for it (unlike `flagon`'s flags above). `app.R`'s `header` `tagList` links both formats via `tags$head(tags$link(rel = "icon", ...))` — `.ico` for broad/legacy browser support, `.png` as the modern fallback.

Regeneration command (requires the `magick` package — install with `install.packages("magick")` if missing):

```r
library(magick)
img <- image_read("man/figures/logo.png")

sizes <- c(16, 32, 48, 64)
favicon <- image_join(lapply(sizes, function(s) image_scale(img, paste0(s, "x", s))))
image_write(favicon, path = "inst/app/www/favicon.ico", format = "ico")

image_write(image_scale(img, "32x32"), path = "inst/app/www/favicon.png", format = "png")
```

## Dependencies

`pressfreedom.data` and `shiny` are the only packages in `Imports` — `pressfreedom.data` supplies the `rwb_standardized` dataset (loaded live at app startup, not bundled), and `shiny` is used directly in `R/run_app.R`. All visualization/data-support packages are in `Suggests`:

| Package | Role |
| :--- | :--- |
| `pressfreedom.data` | Source of the `rwb_standardized` dataset (Imports) |
| `shiny` | Web framework (Imports) |
| `bslib` | Bootstrap UI (`page_navbar`, `card`, `navset_hidden`) |
| `dplyr` | Data filtering in modules |
| `ggplot2` | Bump chart base layer (Trends' Rank view) |
| `ggbump` | `geom_bump()` for the rank bump chart (GitHub: `davidsjoberg/ggbump`) |
| `plotly` | Interactive charts (Trends, Map, Country's stat-bar and combined trend charts) |
| `RColorBrewer` | Color palettes (Trends line colors, Country's dimension colors) |
| `flagon` | Flag PNG/SVG assets (GitHub: `coolbutuseless/flagon`) |
| `countrycode` | iso3 → iso2 lookups for flags |
| `htmlwidgets` | Client-side JS hooks (`onRender`) for chart interactivity |

`ggbump` and `flagon` are not on CRAN; both are listed under `Remotes:` in `DESCRIPTION`, which `remotes::install_github()` and `pak::pak()` read automatically to pull in GitHub-only dependencies — no separate manual install step should be needed for end users.

**Temporary: `petzi53/pressfreedom.data` in `Remotes:` (remove once CRAN accepts it).** `pressfreedom.data` was submitted to CRAN but is still pending review as of this writing (2026-08-02). Verified via `remotes::install_github("petzi53/pressfreedom")` on 2026-08-02: with no `Remotes:` entry for it, the dependency resolver printed `Skipping 1 packages not available: pressfreedom.data` and silently continued — the install only "worked" because a satisfying local copy (0.2.0) already existed from prior dev work. On a genuinely clean library this would leave `pressfreedom.data` uninstalled and `run_app()`'s `requireNamespace()` guard would then fail. Added `petzi53/pressfreedom.data` to `Remotes:` as a stopgap so `install_github()`/`pak::pak()` can fetch it from GitHub in the meantime. **Once `pressfreedom.data` is live on CRAN, remove this line from `Remotes:`** — `Remotes:` entries take priority over CRAN sources, so leaving it in place would keep forcing a GitHub install even after the simpler CRAN path becomes available.

**Clean-library verification note (2026-08-02):** after adding the `Remotes:` line above, a first re-test of `remotes::install_github("petzi53/pressfreedom")` still failed with `pressfreedom.data` skipped/not found. This turned out to be an unpushed-commit issue, not a limitation of `remotes` or `pak`: the fix existed only in local commits, so `install_github()` was fetching a stale `DESCRIPTION` from GitHub (still requiring `pressfreedom.data (>= 0.1.0)` with no `Remotes:` entry for it). After `git push`, both `remotes::install_github()` and `pak::pak()`/`pak::pkg_install()` resolved and installed the full GitHub dependency chain (`pressfreedom.data`, `flagon`, `ggbump`) correctly on a genuinely clean library. `remotes::install_github()` may print benign `skipping pax global extended headers` warnings from `untar2` when unpacking GitHub-generated tarballs — a well-known cosmetic quirk unrelated to this package's configuration (`pak` doesn't show it because it uses a different, libarchive-based extraction path). Takeaway: when a `Remotes:`/dependency-resolution fix appears not to work, check that local commits were actually pushed before suspecting the tooling.

## Annual Update Workflow

Each May, RWB publishes a new index. To update the dashboard:

1. `pressfreedom.data` re-runs its own data pipeline (via `rwb-book`) and releases a new version with the updated `rwb_standardized`.
2. In this package's `DESCRIPTION`, bump the `pressfreedom.data (>= x.y.z)` version floor to the new release.
3. Increment this package's own version in `DESCRIPTION`.
4. Run `devtools::document()` and `devtools::check()`.
5. Run `renv::snapshot(type = "all")`.
6. Once dimension data (2022+) reaches roughly a decade of history (~2032), revisit whether Score/Rank-only scoping in the Trends variable picker (see "Dimension data (2022+): per-view treatment" above) should be relaxed.

## Coding and Workflow Standards

* **Environment:** Managed via `renv` (snapshot type `"all"`).
* **Language:** R only.
* **Documentation:** `roxygen2`; rebuild with `devtools::document()`.
* **Check:** `devtools::check()` should produce 0 errors, 0 warnings, 0 notes.
* **Standards:** Refer to the `peter-global` skill for R coding style and communication preferences.
