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

##############################################################
ui <- bslib::page_sidebar(
    title = "World Press Freedom Index",
    fillable = TRUE,
    sidebar = bslib::sidebar(
        width = 260,
        bslib::navset_pill(
            id = "view",
            bslib::nav_panel("World Map",        mapSidebarUI("map")),
            bslib::nav_panel("Compare Countries", compareSidebarUI("inputs", rwb)),
            bslib::nav_panel("Country Details",  countrySidebarUI("country", rwb))
        )
    ),
    bslib::navset_hidden(
        id = "main_view",
        selected = "World Map",
        bslib::nav_panel("World Map",         mapMainUI("map", rwb)),
        bslib::nav_panel("Compare Countries", compareMainUI("chart")),
        bslib::nav_panel("Country Details",   countryMainUI("country"))
    ),
    shiny::tags$style("
        /* Dashboard should never scroll — fixes the scrollbar issue */
        html, body { overflow: hidden; height: 100%; }

        /* Stack nav pills vertically in the sidebar */
        .bslib-sidebar-layout > .sidebar > .sidebar-content .nav-pills {
            flex-direction: column;
        }
        /* Remove border and background from pill content area inside sidebar */
        .bslib-sidebar-layout > .sidebar > .sidebar-content .tab-content {
            border: none;
            background: transparent;
            padding-top: 0.75rem;
        }
    ")
)

##############################################################
server <- function(input, output, session) {
    # Keep main content in sync with sidebar pill selection
    shiny::observe({
        bslib::nav_select("main_view", input$view)
    })

    mapServer("map", rwb)

    # Inputs module returns list(var, country) as reactives
    sel <- inputsServer("inputs")

    # Chart module receives those reactives and the raw data
    chartServer("chart", rwb, sel$var, sel$country)

    countryServer("country", rwb)
}

shiny::shinyApp(ui, server)
