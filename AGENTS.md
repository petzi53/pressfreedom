# Agents

This file provides context and guidance for AI agents working on the `rwb-book` project.

## Project Overview

This project is a book focused on data science workflows using Reporters Without Borders (RWB) Press Freedom Index data. The workflows cover data acquisition, cleaning, standardization, geographic integration, and interactive visualization using Quarto and Shiny.

## Data Overview

The project uses a multi-temporal dataset of press freedom rankings spanning from 2002 to 2025 (noting that 2011 data is missing).

### Data Directory Structure

The `data/` directory is organized by chapter to mirror the book's progression:

| Directory | Description | Key Formats |
| :--- | :--- | :--- |
| `chap011/rsf/` | Raw RWB Press Freedom Index files (one per year) | `.rds` |
| `chap011/rsf_rec/` | Standardized/recoded RWB files with corrected scores and encoding | `.rds` |
| `chap011/rwb/` | Intermediate working datasets for RWB processing | `.rds` |
| `chap021/` | Cleaned M49 geographic/political classification data | `.rds` |
| `chap031/` | Consolidated RWB data for the 2022-2025 period | `.rds` |
| `chap013/` | Raw Natural Earth geographic boundary data | `.rds` |
| `chap023/` | Processed map data (geometries merged with RWB scores) | `.rds` |
| `chap062/` | World cities and capital data for location-based visualizations | `.rds`, `.csv` |
| `chap091/` | Supporting data for specific visualizations (e.g., bump charts) | `.rds` |

### Key Data Characteristics

* **Temporal Scope:** 2002–2025 (excluding 2011).
* **Dimensions:** Includes a global score and, for more recent years (2022+), six context dimension scores (Political, Economic, Legal, Social, Safety).
* **Hierarchical Geography:** Data is integrated with M49 classifications (Global $\rightarrow$ Region $\rightarrow$ Sub-region $\rightarrow$ Country).
* **Data Standardization:** Historical data undergoes multiple recoding iterations to normalize score formats (e.g., correcting decimal positions) and character encoding.

## Coding and Workflow Standards

* **Environment:** Managed via `renv`.
* **Language:** Primarily R, with Quarto (`.qmd`) for book content and Shiny for interactive applications.
* **Standards:** Refer to the `peter-global` skill for specific R coding standards and communication preferences. Do not duplicate those instructions here.
