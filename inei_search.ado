*! inei_search.ado — Buscar variables en el indice pre-construido
*! 525,000+ variables indexadas de 67 encuestas INEI
*! version 1.0.0  2026-04-02

program define inei_search
    version 14.0
    syntax anything(name=query), [SURVEY(string) YEAR(integer 0) ///
        YEARMIN(integer 0) YEARMAX(integer 9999) ///
        MODULE(string) EXACT LIMIT(integer 50)]

    local query `query'

    * Compatibilidad: yearmin/yearmax como alternativa a year
    if `year' == 0 & `yearmin' > 0 {
        local year `yearmin'
    }

    preserve

    * Cargar indice de variables
    _inei_load_variables

    qui count
    local n_total = r(N)

    * Filtrar por encuesta
    if "`survey'" != "" {
        _inei_cat_resolve_alias `survey'
        local survey_resolved "`s(resolved)'"
        local sv_lower = strlower("`survey_resolved'")
        qui gen __smatch = strpos(strlower(survey), "`sv_lower'") > 0 | ///
                           strpos(strlower(category), "`sv_lower'") > 0
        qui keep if __smatch == 1
        qui drop __smatch
    }

    * Filtrar por anio/rango
    qui destring year, replace force
    if `year' > 0 {
        qui keep if year == `year'
    }
    if `yearmin' > 0 {
        qui keep if year >= `yearmin'
    }
    if `yearmax' < 9999 {
        qui keep if year <= `yearmax'
    }

    * Filtrar por modulo
    if "`module'" != "" {
        local mod_lower = strlower("`module'")
        qui gen __mmatch = strpos(strlower(module_name), "`mod_lower'") > 0 | ///
                           strpos(strlower(module_code), "`mod_lower'") > 0
        qui keep if __mmatch == 1
        qui drop __mmatch
    }

    * Buscar query en nombre y label de variable
    local query_lower = strlower("`query'")

    if "`exact'" != "" {
        * Busqueda exacta por nombre (case-insensitive)
        qui gen __qmatch = strlower(var_name) == "`query_lower'"
    }
    else {
        * Busqueda por substring en nombre y label
        qui gen __qmatch = strpos(strlower(var_name), "`query_lower'") > 0 | ///
                           strpos(strlower(var_label), "`query_lower'") > 0
    }

    qui keep if __qmatch == 1
    qui drop __qmatch

    qui count
    local n_found = r(N)

    if `n_found' == 0 {
        di as text ""
        di as text "No se encontraron variables para: {bf:`query'}"
        di as text "  Total de variables en indice: `n_total'"
        di as text ""
        di as text "Sugerencias:"
        di as text "  - Intente con un termino mas corto"
        di as text "  - Use sin la opcion {bf:exact}"
        di as text "  - Verifique la encuesta con: inei aliases"
        restore
        exit
    }

    * Ordenar resultados
    sort survey year module_name var_name

    * Mostrar resultados
    di as text ""
    di as text "{bf:Resultados de busqueda: {it:`query'}}"
    di as text "{hline 90}"
    di as text %~12s "Variable" " " %~30s "Label" " " %~15s "Encuesta" " " ///
        %5s "Anio" " " %~20s "Modulo"
    di as text "{hline 90}"

    local show_n = min(`n_found', `limit')

    forvalues i = 1/`show_n' {
        local vname  = var_name[`i']
        local vlabel = var_label[`i']
        local vsurvey = survey[`i']
        local vyear  = year[`i']
        local vmod   = module_name[`i']

        * Truncar si es largo
        if strlen("`vlabel'") > 30 {
            local vlabel = substr("`vlabel'", 1, 27) + "..."
        }
        if strlen("`vsurvey'") > 15 {
            local vsurvey = substr("`vsurvey'", 1, 12) + "..."
        }
        if strlen("`vmod'") > 20 {
            local vmod = substr("`vmod'", 1, 17) + "..."
        }

        di as result %~12s "`vname'" " " as text %~30s "`vlabel'" " " ///
            %~15s "`vsurvey'" " " %5s "`vyear'" " " %~20s "`vmod'"
    }

    di as text "{hline 90}"

    if `n_found' > `limit' {
        local remaining = `n_found' - `limit'
        di as text "  Mostrando `limit' de `n_found' resultados"
        di as text "  Use {bf:limit(`n_found')} para ver todos"
    }
    else {
        di as text "  `n_found' resultados encontrados"
    }

    * Mostrar resumen por encuesta/anio
    di as text ""
    di as text "{bf:Resumen por encuesta:}"

    qui levelsof survey, local(surveys)
    foreach sv of local surveys {
        qui count if survey == "`sv'"
        local sv_count = r(N)
        qui levelsof year if survey == "`sv'", local(sv_years)
        local n_sv_years : word count `sv_years'
        local first_year : word 1 of `sv_years'
        local last_year  : word `n_sv_years' of `sv_years'

        if `n_sv_years' > 1 {
            di as text "  `sv': `sv_count' coincidencias (`first_year'-`last_year')"
        }
        else {
            di as text "  `sv': `sv_count' coincidencias (`first_year')"
        }
    }

    di as text ""

    restore
end

/* _inei_load_variables is defined in its own .ado file */
