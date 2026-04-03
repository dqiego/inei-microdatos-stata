*! inei_stats.ado — Mostrar estadisticas del catalogo INEI
*! version 1.0.0  2026-04-02

program define inei_stats
    version 14.0
    syntax , [CATALOG(string)]

    preserve

    * Cargar catalogo
    _inei_catalog_utils load, catalog(`catalog')

    * Calcular estadisticas
    qui count
    local n_modules = r(N)

    qui levelsof survey_label, local(cats) clean
    local n_surveys : word count `cats'
    * levelsof may undercount with spaces in values, use egen instead
    tempvar stag
    qui egen `stag' = group(category survey_label)
    qui summarize `stag'
    local n_surveys = r(max)

    qui summarize year
    local year_min = r(min)
    local year_max = r(max)

    qui levelsof year, local(years)
    local n_years : word count `years'

    * Contar formatos disponibles
    qui count if stata_code != ""
    local n_stata = r(N)
    qui count if csv_code != ""
    local n_csv = r(N)
    qui count if spss_code != ""
    local n_spss = r(N)

    * Mostrar
    di as text ""
    di as text "{bf:Estadisticas del catalogo INEI}"
    di as text "{hline 45}"
    di as text "  Encuestas:        " as result %8.0f `n_surveys'
    di as text "  Modulos totales:  " as result %8.0f `n_modules'
    di as text "  Rango de anios:   " as result %8.0f `year_min' ///
        as text " - " as result `year_max'
    di as text "  Anios distintos:  " as result %8.0f `n_years'
    di as text "{hline 45}"
    di as text "  {bf:Modulos por formato:}"
    di as text "    CSV:            " as result %8.0f `n_csv'
    di as text "    STATA:          " as result %8.0f `n_stata'
    di as text "    SPSS:           " as result %8.0f `n_spss'
    di as text "{hline 45}"

    * Verificar docs
    _inei_find_data_dir
    local datadir "`s(datadir)'"
    capture confirm file "`datadir'/inei_docs.dta"
    if _rc == 0 {
        qui use "`datadir'/inei_docs.dta", clear
        qui count
        di as text "  Documentos:       " as result %8.0f r(N)
    }
    else {
        capture confirm file "`datadir'/inei_docs.csv"
        if _rc == 0 {
            qui import delimited using "`datadir'/inei_docs.csv", clear ///
                encoding("utf-8")
            qui count
            di as text "  Documentos:       " as result %8.0f r(N)
        }
    }

    * Verificar indice de variables
    capture confirm file "`datadir'/inei_variables.dta"
    if _rc == 0 {
        qui use "`datadir'/inei_variables.dta", clear
        qui count
        di as text "  Variables:        " as result %8.0f r(N)
    }
    else {
        capture confirm file "`datadir'/inei_variables.csv"
        if _rc == 0 {
            di as text "  Variables:        " as text "(CSV disponible, ejecute inei search para indexar)"
        }
    }

    di as text "{hline 45}"

    * Mostrar fecha de crawl si existe
    _inei_find_data_dir
    local datadir2 "`s(datadir)'"
    capture {
        qui use "`datadir2'/inei_catalog.dta", clear
        local crawl_date : char _dta[crawl_date]
    }
    if "`crawl_date'" != "" {
        di as text "  Ultima actualizacion: " as result "`crawl_date'"

        * Warning si tiene mas de 90 dias (aproximado)
        local today_y = year(date("`c(current_date)'", "DMY"))
        local today_m = month(date("`c(current_date)'", "DMY"))
        local crawl_y = year(date("`crawl_date'", "DMY"))
        local crawl_m = month(date("`crawl_date'", "DMY"))
        local months_diff = (`today_y' - `crawl_y') * 12 + (`today_m' - `crawl_m')
        if `months_diff' >= 3 {
            di as text "  {err:Nota: el catalogo tiene mas de 3 meses.}"
            di as text "  {err:Considere actualizar con: inei crawl}"
        }
    }

    di as text "{hline 45}"
    di as text ""

    restore
end
