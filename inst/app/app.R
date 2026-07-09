## inst/app/app.R
## Entry point for the Press Freedom Dashboard.
##
## File layout:
##   app.R           — entry point: load data, wire modules, run app
##   R/helpers.R     — df_chart(), card_title()
##   R/mod_inputs.R  — inputsUI() / inputsServer()
##   R/mod_chart.R   — chartUI()  / chartServer()

# ggplot2 must be attached: ggplotly() resolves vars() by name on the search path
library(ggplot2)

# Source all module and helper files from R/
invisible(lapply(list.files("R", full.names = TRUE, pattern = "\\.R$"), source))

# Use the dataset bundled with the package
rwb <- pressfreedom::rwb

##############################################################
ui <- bslib::page_sidebar(
    shiny::titlePanel("World Press Freedom Indices (WPFI)"),
    sidebar = bslib::sidebar(
        inputsUI("inputs", rwb)
    ),
    chartUI("chart")
)

##############################################################
server <- function(input, output, session) {
    # Inputs module returns list(var, country) as reactives
    sel <- inputsServer("inputs")

    # Chart module receives those reactives and the raw data
    chartServer("chart", rwb, sel$var, sel$country)
}

shiny::shinyApp(ui, server)
