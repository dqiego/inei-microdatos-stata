*! inei_track.ado — Seguir una variable a traves de los anios
*! Muestra en que anios/modulos aparece una variable especifica
*! version 1.0.0  2026-04-02

program define inei_track
    version 14.0
    syntax anything(name=variable), [SURVEY(string)]

    local variable = `variable'

    preserve

    * Cargar indice
    _inei_load_variables

    * Filtrar por encuesta si se especifico
    if "`survey'" != "" {
        _inei_cat_resolve_alias `survey'
        local survey_resolved "`s(resolved)'"
        local sv_lower = strlower("`survey_resolved'")
        qui gen __smatch = strpos(strlower(survey), "`sv_lower'") > 0 | ///
                           strpos(strlower(category), "`sv_lower'") > 0
        qui keep if __smatch == 1
        qui drop __smatch
    }

    * Buscar variable (match exacto por nombre, case-insensitive)
    local var_lower = strlower("`variable'")
    qui gen __vmatch = strlower(var_name) == "`var_lower'"
    qui keep if __vmatch == 1
    qui drop __vmatch

    qui count
    local n_found = r(N)

    if `n_found' == 0 {
        di as text ""
        di as text "Variable {bf:`variable'} no encontrada en el indice"
        di as text ""
        di as text "Sugerencias:"
        di as text "  - Verifique el nombre exacto de la variable"
        di as text "  - Use {bf:inei search `variable'} para busqueda parcial"
        di as text "  - Especifique encuesta: {bf:inei track `variable', survey(enaho)}"
        restore
        exit
    }

    * Obtener label (usar el primero encontrado)
    local var_label = var_label[1]

    * Ordenar por encuesta y anio
    qui destring year, replace force
    sort survey year module_name

    di as text ""
    di as text "{bf:Tracking de variable: `variable'}"
    if "`var_label'" != "" {
        di as text "  Label: `var_label'"
    }
    di as text "{hline 75}"
    di as text %~20s "Encuesta" " " %5s "Anio" " " %~30s "Modulo" " " ///
        %10s "Codigo"
    di as text "{hline 75}"

    local prev_survey ""
    local prev_year = .

    local N = _N
    forvalues i = 1/`N' {
        local vsurvey = survey[`i']
        local vyear   = year[`i']
        local vmod    = module_name[`i']
        local vcode   = module_code[`i']

        * Separador cuando cambia encuesta
        if "`vsurvey'" != "`prev_survey'" & "`prev_survey'" != "" {
            di as text "{hline 75}"
        }

        * Detectar gaps en anios
        if "`vsurvey'" == "`prev_survey'" & `prev_year' != . {
            local gap = `vyear' - `prev_year'
            if `gap' > 1 {
                di as text %~20s "" " " as error %5s "..." " " ///
                    as text "(gap: `prev_year'-`vyear')"
            }
        }

        local prev_survey "`vsurvey'"
        local prev_year = `vyear'

        * Truncar
        if strlen("`vsurvey'") > 20 {
            local vsurvey = substr("`vsurvey'", 1, 17) + "..."
        }
        if strlen("`vmod'") > 30 {
            local vmod = substr("`vmod'", 1, 27) + "..."
        }

        di as result %~20s "`vsurvey'" " " as text %5.0f `vyear' " " ///
            %~30s "`vmod'" " " %10s "`vcode'"
    }

    di as text "{hline 75}"

    * Resumen
    qui levelsof survey, local(surveys)
    local n_surveys : word count `surveys'

    qui levelsof year, local(years)
    local n_years : word count `years'
    local first_year : word 1 of `years'
    local last_year  : word `n_years' of `years'

    di as text ""
    di as text "{bf:Resumen:}"
    di as text "  Encuestas:      `n_surveys'"
    di as text "  Anios:          `n_years' (`first_year' - `last_year')"
    di as text "  Apariciones:    `n_found'"
    di as text ""

    restore
end
