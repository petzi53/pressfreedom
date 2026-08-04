## inst/app/R/mod_about.R
## About tab: loads content from inst/app/www/about.md, renders it as HTML,
## and builds an accordion with three sections. UI-only — no reactivity
## needed for static content, so there is no aboutServer().
##
## Text content is maintained separately in about.md for easy editing without
## touching R code; see that file for how to customize the About page.

#' Split markdown content into accordion sections
#'
#' Parses about.md to extract the main intro text (before the first ## heading)
#' and three accordion sections (## Data & Methodology, ## Limitations & Caveats,
#' ## Citation & Contact). Returns a list for use in accordion_panel().
#'
#' @param md_text character vector of markdown lines (as from readLines())
#'
#' @return list with $intro (intro HTML), $data_methods (HTML), $limitations (HTML),
#'   $citation_contact (HTML), $version (character), $year_range (character)
parse_about_sections <- function(md_text) {
  md_full <- paste(md_text, collapse = "\n")

  # Split by ## headings (level-2 markdown headers)
  sections <- strsplit(md_full, "\n## ")[[1]]

  # sections[1] is everything before the first ##, sections[2+] are the labeled sections
  intro <- if (length(sections) > 0) sections[1] else ""

  # Extract named sections by finding their position in the split result
  find_section <- function(name) {
    idx <- grep(paste0("^", name), sections)
    if (length(idx) == 0) return("")
    # Remove the section title (first line) and paste the rest
    lines <- strsplit(sections[idx[1]], "\n")[[1]]
    paste(lines[-1], collapse = "\n")
  }

  data_methods <- find_section("Data & Methodology")
  limitations <- find_section("Limitations & Caveats")
  citation_contact <- find_section("Citation & Contact")

  # Render each section from markdown to HTML
  list(
    intro = shiny::markdown(intro),
    data_methods = shiny::markdown(data_methods),
    limitations = shiny::markdown(limitations),
    citation_contact = shiny::markdown(citation_contact),
    version = tryCatch(
      as.character(utils::packageVersion("pressfreedom")),
      error = function(e) "development version"
    ),
    year_range = NA_character_  # Will be filled by aboutMainUI() from data
  )
}

aboutSidebarUI <- function(id) {
  ns <- shiny::NS(id)
  shiny::tagList(
    shiny::p(shiny::tags$em("No filters on this tab.")),
    shiny::actionButton(
      ns("back_to_dashboard"),
      "Back to Dashboard",
      icon = shiny::icon("arrow-left"),
      width = "100%"
    )
  )
}

aboutMainUI <- function(data) {
  year_range <- paste(
    min(data$year_n, na.rm = TRUE), max(data$year_n, na.rm = TRUE),
    sep = "\u2013"
  )

  # Load and parse about.md
  about_path <- system.file("app/www/about.md", package = "pressfreedom")
  if (about_path == "") {
    # Fallback if the file is not found (e.g., during development with load_all())
    about_path <- "inst/app/www/about.md"
  }

  if (file.exists(about_path)) {
    about_md <- readLines(about_path, encoding = "UTF-8")
    sections <- parse_about_sections(about_md)
  } else {
    # Emergency fallback if file truly doesn't exist
    sections <- list(
      intro = shiny::tags$p("About page content unavailable."),
      data_methods = shiny::tags$p("Error: about.md not found."),
      limitations = shiny::tags$p(""),
      citation_contact = shiny::tags$p("")
    )
  }

  pkg_version <- sections$version

  bslib::card(
    height = "calc(100vh - 105px)",
    shiny::div(
      style = "overflow-y: auto; height: 100%; padding: 0.5rem 1rem; font-size: 0.9rem;",
      shiny::div(
        style = "max-width: 900px; margin: 0 auto;",
        shiny::h2("About the Press Freedom Dashboard", style = "font-size: 1.4rem; margin-top: 0;"),
        sections$intro,
        bslib::accordion(
          open = FALSE,
          bslib::accordion_panel(
            "Data & Methodology",
            sections$data_methods
          ),
          bslib::accordion_panel(
            "Limitations & Caveats",
            sections$limitations
          ),
          bslib::accordion_panel(
            "Citation & Contact",
            sections$citation_contact,
            shiny::p(shiny::tags$small(
              "Dashboard version ", pkg_version, " \u00b7 Data coverage: ", year_range
            ))
          )
        )
      )
    )
  )
}
