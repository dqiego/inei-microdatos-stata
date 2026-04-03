*! inei_search.ado — Buscar variables en el indice pre-construido
*! 525,000+ variables indexadas de 67 encuestas INEI
*! version 1.0.2  2026-04-02

program define inei_search
    version 14.0
    syntax anything(name=query), [SURVEY(string) YEAR(integer 0) ///
        YEARMIN(integer 0) YEARMAX(integer 9999) ///
        MODULE(string) EXACT LIMIT(integer 20)]

    local query `query'

    if `year' == 0 & `yearmin' > 0 {
        local year `yearmin'
    }

    preserve

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

    * Buscar query
    local query_lower = strlower("`query'")

    if "`exact'" != "" {
        qui gen __qmatch = strlower(var_name) == "`query_lower'"
    }
    else {
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
        di as text ""
        di as text "Sugerencias:"
        di as text "  - Intente con un termino mas corto"
        di as text "  - Use sin la opcion {bf:exact}"
        di as text "  - Verifique la encuesta con: inei aliases"
        restore
        exit
    }

    sort survey year module_name var_name

    * --- Mostrar resultados (formato limpio, 2 lineas por resultado) ---
    di as text ""
    di as text "{bf:Resultados de busqueda: {it:`query'}} ({result:`n_found'} encontrados)"
    di as text ""

    local show_n = min(`n_found', `limit')

    * Mostrar resultados usando Mata (evita problemas con chars especiales)
    mata: _inei_show_search_results(`show_n')

    di as text ""

    if `n_found' > `limit' {
        di as text "{hline 72}"
        di as text "  Mostrando `limit' de `n_found' resultados."
        di as text "  Use {bf:limit(`n_found')} para ver todos."
    }

    * Resumen por encuesta
    di as text ""
    di as text "{bf:Resumen:}"

    qui levelsof survey, local(surveys)
    foreach sv of local surveys {
        qui count if survey == "`sv'"
        local sv_count = r(N)
        qui levelsof year if survey == "`sv'", local(sv_years)
        local n_sv_years : word count `sv_years'
        local first_year : word 1 of `sv_years'
        local last_year  : word `n_sv_years' of `sv_years'

        if `n_sv_years' > 1 {
            di as text "  `sv': " as result "`sv_count'" ///
                as text " coincidencias (" as result "`first_year'-`last_year'" as text ")"
        }
        else {
            di as text "  `sv': " as result "`sv_count'" ///
                as text " coincidencias (" as result "`first_year'" as text ")"
        }
    }

    * Hint de uso
    local first_sv = survey[1]
    local first_yr = year[1]
    local first_mc = module_code[1]
    di as text ""
    di as text "  {it:Tip: inei use, survey(`survey') year(`first_yr') module(`first_mc') clear}"
    di as text ""

    restore
end

/* _inei_load_variables is defined in its own .ado file */

mata:
void _inei_show_search_results(real scalar show_n)
{
    string scalar vname, vlabel, vsurvey, vmod, vcode, prev_survey
    string scalar remaining, chunk, line
    real scalar i, vyear, line_len, break_pos, j

    prev_survey = ""
    line_len = 66

    for (i = 1; i <= show_n; i++) {
        vname   = st_sdata(i, "var_name")
        vlabel  = st_sdata(i, "var_label")
        vsurvey = st_sdata(i, "survey")
        vyear   = st_data(i, "year")
        vmod    = st_sdata(i, "module_name")
        vcode   = st_sdata(i, "module_code")

        if (vsurvey != prev_survey) {
            if (prev_survey != "") printf("\n")
            printf("  %s\n", vsurvey)
            printf("  ----------------------------------------------------------------------\n")
        }
        prev_survey = vsurvey

        printf("    %s (%g) [%s] %s\n", vname, vyear, vcode, vmod)

        // Word-wrap del label
        remaining = vlabel
        while (strlen(remaining) > 0) {
            if (strlen(remaining) <= line_len) {
                printf("      %s\n", remaining)
                remaining = ""
            }
            else {
                chunk = substr(remaining, 1, line_len)
                break_pos = line_len
                for (j = line_len; j >= 1; j--) {
                    if (substr(chunk, j, 1) == " ") {
                        break_pos = j
                        break
                    }
                }
                line = substr(remaining, 1, break_pos)
                remaining = strtrim(substr(remaining, break_pos + 1, .))
                printf("      %s\n", line)
            }
        }
    }

    printf("\n")
}
end
