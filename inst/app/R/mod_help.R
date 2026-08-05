## inst/app/R/mod_help.R
## Help tab: loads content from inst/app/www/help.md, renders it as HTML,
## and builds an accordion with multiple sections. UI-only — no reactivity
## needed for static content, so there is no helpServer().
##
## Text content is maintained separately in help.md for easy editing without
## touching R code; see that file for how to customize the Help page.

#' Split markdown content into accordion sections
#'
#' Parses help.md to extract the main intro text (before the first ## heading)
#' and accordion sections (each ## level-2 heading becomes a panel).
#' Returns a list for use in accordion_panel().
#'
#' @param md_text character vector of markdown lines (as from readLines())
#'
#' @return list with $intro (intro HTML) and $sections (list of section HTML by name)
parse_help_sections <- function(md_text) {
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

  # Expected section names (update this if help.md changes)
  section_names <- c(
    "Navigating the dashboard",
    "Reading the charts",
    "The chart toolbar",
    "Downloading data",
    "Frequently asked questions"
  )

  section_html <- lapply(section_names, function(name) {
    content <- find_section(name)
    if (content == "") return(NULL)
    shiny::markdown(content)
  })
  names(section_html) <- section_names

  list(
    intro = shiny::markdown(intro),
    sections = section_html
  )
}

helpSidebarUI <- function(id) {
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

helpMainUI <- function() {
  # Load and parse help.md
  help_path <- system.file("app/www/help.md", package = "pressfreedom")
  if (help_path == "") {
    # Fallback if the file is not found (e.g., during development with load_all())
    help_path <- "inst/app/www/help.md"
  }

  if (file.exists(help_path)) {
    help_md <- readLines(help_path, encoding = "UTF-8")
    sections <- parse_help_sections(help_md)
  } else {
    # Emergency fallback if file truly doesn't exist
    sections <- list(
      intro = shiny::tags$p("Help page content unavailable."),
      sections = list(
        "Error" = shiny::tags$p("help.md not found.")
      )
    )
  }

  bslib::card(
    height = "calc(100vh - 105px)",
    shiny::div(
      style = "overflow-y: auto; height: 100%; padding: 0.5rem 1rem; font-size: 0.9rem;",
      shiny::div(
        style = "max-width: 900px; margin: 0 auto;",
        shiny::h2("Help", style = "font-size: 1.4rem; margin-top: 0;"),
        sections$intro,
        bslib::accordion(
          open = FALSE,
          # Build accordion panels from parsed sections, skipping empty ones
          lapply(names(sections$sections), function(name) {
            content <- sections$sections[[name]]
            if (is.null(content)) return(NULL)
            bslib::accordion_panel(name, content)
          })
        )
      )
    )
  )
}
