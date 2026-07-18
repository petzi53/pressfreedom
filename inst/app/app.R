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
    bslib::nav_panel(
        "Map",
        sidebar = mapSidebarUI("map", rwb),
        mapMainUI("map")
    ),
    bslib::nav_panel(
        "Trends",
        sidebar = compareSidebarUI("inputs", rwb),
        compareMainUI("chart")
    ),
    bslib::nav_panel(
        "Country",
        sidebar = countrySidebarUI("country", rwb),
        countryMainUI("country")
    ),
    header = shiny::tags$style("
        /* Dashboard should never scroll — fixes the scrollbar issue */
        html, body { overflow: hidden; height: 100%; }

        /* Title acts as a home link — inherit navbar colour, underline on hover */
        #reset_app { color: inherit !important; text-decoration: none !important; }
        #reset_app:hover { text-decoration: underline !important; }
    ")
)

##############################################################
server <- function(input, output, session) {
    # Title click: navigate to Map and signal the map module to reset
    reset_trigger <- shiny::reactiveVal(0)
    shiny::observeEvent(input$reset_app, {
        bslib::nav_select("view", "Map")
        reset_trigger(reset_trigger() + 1)
    })

    # Shared "selected country" reactive: both the Map's click-to-navigate
    # (mapServer()'s returned reactive) and Trends' click-to-inspect
    # popover (chartServer()'s returned reactive) feed into this single
    # reactiveVal. One observer downstream does the actual navigation +
    # selection, so that logic exists in exactly one place regardless of
    # which view triggered it.
    selected_country <- shiny::reactiveVal(NULL)

    # mapServer() returns a reactive holding the most recently clicked
    # country (or NULL).
    map_click <- mapServer("map", rwb, reset = reset_trigger)
    shiny::observeEvent(map_click(), {
        shiny::req(map_click())
        selected_country(map_click())
    })

    # Inputs module returns list(var, country) as reactives
    sel <- inputsServer("inputs")

    # Chart module receives those reactives and the raw data, and returns
    # a reactive holding the country confirmed via its click popover's
    # "Go to Country view" button (or NULL).
    chart_click <- chartServer("chart", rwb, sel$var, sel$country)
    shiny::observeEvent(chart_click(), {
        shiny::req(chart_click())
        selected_country(chart_click())
    })

    # The one place a click from either view actually navigates: switch
    # to the Country tab and preselect the clicked country there.
    shiny::observeEvent(selected_country(), {
        shiny::req(selected_country())
        bslib::nav_select("view", "Country")
        shiny::updateSelectInput(session, "country-country", selected = selected_country())
    })

    countryServer("country", rwb)
}

shiny::shinyApp(ui, server)
