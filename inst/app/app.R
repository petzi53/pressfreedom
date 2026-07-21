## inst/app/app.R
## Entry point for the Press Freedom Dashboard.
##
## File layout:
##   app.R           — entry point: load data, wire modules, run app
##   R/helpers.R     — df_chart(), card_title()
##   R/mod_inputs.R  — compareSidebarUI() / inputsServer()
##   R/mod_chart.R   — compareMainUI()    / chartServer()
##   R/mod_map.R     — mapSidebarUI() / mapMainUI() / mapServer()
##   R/mod_country.R — countrySidebarUI() / countryMainUI() / countryServer()

# ggplot2 must be attached: ggplotly() resolves vars() by name on the search path
library(ggplot2)

# Source all module and helper files from R/
invisible(lapply(list.files("R", full.names = TRUE, pattern = "\\.R$"), source))

# Use the dataset bundled with the package
rwb <- pressfreedom::rwb

# flagon installs flag images on disk rather than as package data; serve
# them under /flags so <img src="flags/xx.png"> works anywhere in the app
# (see R/flags.R for the iso3 -> flagon-code mapping).
shiny::addResourcePath("flags", system.file("png", package = "flagon"))

##############################################################
ui <- bslib::page_navbar(
    title = shiny::actionLink(
        "reset_app",
        "World Press Freedom Index",
        style = "color: inherit; text-decoration: none;"
    ),
    id = "view",
    fillable = TRUE,
    # bslib's installed version (0.11.0) has no per-nav_panel() `sidebar =`
    # argument — page_navbar() only supports one page-level `sidebar =`,
    # shared across all panels. Per-view sidebar *content* is achieved with
    # a navset_hidden() inside that single sidebar, kept in sync with the
    # visible navbar tabs via the "view" -> "sidebar_view" nav_select() in
    # the server below (mirrors the old view/main_view sync, just applied
    # to the sidebar instead of the main content now that the switcher
    # itself lives in the navbar).
    sidebar = bslib::sidebar(
        id = "app_sidebar",
        width = 260,
        # Explicit open= sets the sidebar's state at *initial page load*
        # (based on window width at that moment) to "closed" if narrow —
        # page_navbar()'s sidebar otherwise defaults to
        # data-open-mobile="always" (permanently open, no toggle at all).
        # It does NOT, on its own, make the sidebar collapse on a live
        # window resize after that: bslib's sidebar.js only re-reads its
        # window-size CSS variable at construction time when both
        # desktop and mobile are collapsible (our case, and the
        # default) — by design, it assumes a user's manual toggle
        # should survive a resize rather than being silently overridden.
        # The JS matchMedia listener in the header script (section 1)
        # is what actually makes it collapse/reopen live as the
        # window crosses 992px, using bslib's own Sidebar.toggle().
        open = list(desktop = "open", mobile = "closed"),
        bslib::navset_hidden(
            id = "sidebar_view",
            bslib::nav_panel_hidden("Map",    mapSidebarUI("map", rwb)),
            bslib::nav_panel_hidden("Trends", compareSidebarUI("inputs", rwb)),
            bslib::nav_panel_hidden("Country", countrySidebarUI("country", rwb))
        )
    ),
    bslib::nav_panel("Map",    mapMainUI("map")),
    bslib::nav_panel("Trends", compareMainUI("chart")),
    bslib::nav_panel("Country", countryMainUI("country")),
    header = shiny::tagList(
      shiny::tags$script(shiny::HTML("
        (function() {
          // --- 1. Sidebar live collapse/reopen at 992px ---
          // Uses matchMedia — its 'change' event fires exactly once
          // each time the viewport crosses the breakpoint, so it's
          // inherently debounced and doesn't interfere with the
          // user's manual open/close toggle.
          var mql = window.matchMedia('(max-width: 992px)');
          mql.addEventListener('change', function(e) {
            var layout = document.querySelector('.bslib-sidebar-layout');
            if (!layout) return;
            var sb = window.bslib && window.bslib.Sidebar &&
                     window.bslib.Sidebar.getInstance(layout);
            if (!sb) return;
            sb.toggle(e.matches ? 'close' : 'open');
          });

          // --- 2. Country content-pane width -> drives the trend
          // chart's subplot layout (see countryServer()'s `narrow`
          // reactive in mod_country.R). Deliberately NOT window width:
          // the pane is ~260px narrower than the window whenever the
          // sidebar happens to be open, so window width alone can't
          // tell the chart when it's actually been squeezed. A
          // ResizeObserver on the width_probe div (the Country view's
          // own outer content wrapper, in mod_country.R's
          // countryMainUI() — so it always shares its width) reports
          // the real number whenever it changes, for any reason
          // (window resize, sidebar toggle, ...).
          function observeCountryProbe() {
            var el = document.getElementById('country-width_probe');
            if (!el) { requestAnimationFrame(observeCountryProbe); return; }
            new ResizeObserver(function(entries) {
              // Guard: the observer fires once immediately on .observe(),
              // which can happen before Shiny is fully connected.
              if (typeof Shiny !== 'undefined' && Shiny.setInputValue) {
                Shiny.setInputValue(
                  'country-width_probe_val', entries[0].contentRect.width,
                  {priority: 'event'}
                );
              }
            }).observe(el);
          }
          observeCountryProbe();

          // --- 3. Force Plotly resize when a tab becomes shown ---
          // Plotly widgets rendered while their tab is hidden can
          // have stale zero-size layouts. A window resize after
          // the tab becomes visible triggers Plotly's responsive
          // layout recalculation.
          document.addEventListener('shown.bs.tab', function() {
            window.dispatchEvent(new Event('resize'));
          });
        })();
      ")),
      shiny::tags$style("
        /* Dashboard should never scroll — fixes the scrollbar issue */
        html, body { overflow: hidden; height: 100%; }

        /* Title acts as a home link — inherit navbar colour, underline on hover */
        #reset_app { color: inherit !important; text-decoration: none !important; }
        #reset_app:hover { text-decoration: underline !important; }

        /* Matches Bootstrap's own 'lg' breakpoint, where our navbar's
           nav-links already collapse to a hamburger by default — this
           just aligns the sidebar's *initial page-load* open/closed
           state (bslib's sidebar.js reads this custom property once,
           at construction) with that same width, instead of bslib's
           built-in (much narrower, ~576px) mobile threshold. The
           sidebar's LIVE collapse/reopen as the window is dragged past
           992px is driven by the JS matchMedia listener in section 1
           of the header script above. */
        @media (max-width: 992px) {
            /* Set as an INLINE style by bslib's JS, which otherwise
               always wins over a plain stylesheet rule regardless of
               selector specificity — !important is the one thing that
               outranks an inline style lacking !important itself. */
            .bslib-sidebar-layout {
                --bslib-sidebar-js-window-size: mobile !important;
            }
        }

        /* The Country view's own layout responds to a CSS *container*
           query on its content pane (see the country-body container
           set up in mod_country.R), not a viewport @media query —
           deliberately decoupled from window width, since the pane's
           available width also depends on whether the sidebar happens
           to be open (see the JS above). Keep the 700px threshold in
           sync with the matching `narrow` reactive in mod_country.R. */
        @container country-body (max-width: 700px) {
            .country-overview-row {
                flex-direction: column !important;
                align-items: stretch !important;
            }
            .country-overview-stats,
            .country-overview-chart {
                flex-basis: 100% !important;
            }
            /* A definite flex-basis (not `auto` + min-height) so the
               wrapper has a real, immediately-resolvable height as
               soon as the container query matches — the Plotly widget
               inside (see mod_country.R's trend_plot_or_placeholder)
               relies on that being true synchronously, since its own
               height is a CSS percentage that can only resolve against
               a parent with a definite size. `auto` + `min-height`
               previously left the *actual* resolved height dependent
               on content, which raced against the R-side subplot
               relayout (triggered separately, over a Shiny round trip,
               by the `narrow` reactive) and could produce a wildly
               wrong Plotly-computed height (observed: tens of
               thousands of px) for the brief window before both sides
               agreed — see AGENTS.md's 'Responsive behavior' note. */
            .country-trend-wrapper {
                flex: 0 0 850px !important;
                min-height: 850px !important;
            }
        }
      ")
    )
)

##############################################################
server <- function(input, output, session) {
    # Keep the sidebar's hidden navset in sync with the visible navbar tabs
    # (see the `sidebar =` comment in the UI above for why this exists).
    shiny::observe({
        bslib::nav_select("sidebar_view", input$view)
    })

    # NOTE: sidebar live collapse/reopen is handled entirely in JS
    # (section 1 of the header script) via a matchMedia listener that
    # calls bslib's Sidebar.toggle() when the viewport crosses 992px.

    # Title click: navigate to Map and signal the map module to reset
    reset_trigger <- shiny::reactiveVal(0)
    shiny::observeEvent(input$reset_app, {
        bslib::nav_select("view", "Map")
        reset_trigger(reset_trigger() + 1)
    })

    # Shared "selected country" reactive: both the Map's click-to-navigate
    # (mapServer()'s returned reactive) and Trends' click-to-navigate
    # (chartServer()'s returned reactive) feed into this single
    # reactiveVal. One observer downstream does the actual navigation +
    # selection, so that logic exists in exactly one place regardless of
    # which view triggered it.
    #
    # Both source reactives return list(country=, nonce=), not a bare
    # string: reactiveVal() (this one, and each source module's own
    # internal one) skips invalidating dependents when set to a value
    # identical() to its current one. Without a nonce, re-clicking the
    # country already active in the Country view would be silently
    # swallowed at every reactiveVal hop in the chain and never navigate.
    # See mod_map.R / mod_chart.R for where the nonce originates.
    selected_country <- shiny::reactiveVal(NULL)

    # mapServer() returns a reactive holding the most recently clicked
    # country (or NULL).
    map_click <- mapServer("map", rwb, reset = reset_trigger)
    shiny::observeEvent(map_click(), {
        shiny::req(map_click())
        selected_country(map_click())
    })

    # Inputs module returns list(var, country) as reactives
    sel <- inputsServer("inputs", selected_country = shiny::reactive({
        shiny::req(selected_country())
        selected_country()$country
    }))

    # Chart module receives those reactives and the raw data, and returns
    # a reactive holding the country most recently clicked on a chart point
    # (or NULL).
    chart_click <- chartServer("chart", rwb, sel$var, sel$country)
    shiny::observeEvent(chart_click(), {
        shiny::req(chart_click())
        selected_country(chart_click())
    })

    # The one place a click from either view actually navigates: switch
    # to the Country tab and preselect the clicked country there. The
    # nonce in selected_country() (see comment above) ensures this fires
    # even when the same country is clicked again in a row.
    shiny::observeEvent(selected_country(), {
        shiny::req(selected_country())
        bslib::nav_select("view", "Country")
        shiny::updateSelectInput(
            session, "country-country",
            selected = selected_country()$country
        )
    })

    # Capture the Country module's selected country reactive so we can
    # add it to Trends when the user selects a country in the Country view
    country_selected <- countryServer("country", rwb)
    shiny::observeEvent(country_selected(), {
        # Only add to Trends if a country is actually selected (non-empty string)
        if (country_selected() != "") {
            current_trends_selection <- sel$country()
            new_country <- country_selected()
            # Add the country if not already selected in Trends
            if (!new_country %in% current_trends_selection) {
                updated_selection <- c(current_trends_selection, new_country)
                shiny::updateSelectInput(session, "inputs-country", selected = updated_selection)
            }
        }
    })
}

shiny::shinyApp(ui, server)
