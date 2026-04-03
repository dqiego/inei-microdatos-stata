*! inei_track.ado — Seguir una variable a traves de los anios
*! Muestra en que anios/modulos aparece una variable especifica
*! version 1.0.2  2026-04-02

program define inei_track
    version 14.0
    syntax anything(name=variable), [SURVEY(string)]

    local variable `variable'

    preserve

    _inei_load_variables

    if "`survey'" != "" {
        _inei_cat_resolve_alias `survey'
        local survey_resolved "`s(resolved)'"
        local sv_lower = strlower("`survey_resolved'")
        qui gen __smatch = strpos(strlower(survey), "`sv_lower'") > 0 | ///
                           strpos(strlower(category), "`sv_lower'") > 0
        qui keep if __smatch == 1
        qui drop __smatch
    }

    * Match exacto por nombre
    local var_lower = strlower("`variable'")
    qui gen __vmatch = strlower(var_name) == "`var_lower'"
    qui keep if __vmatch == 1
    qui drop __vmatch

    qui count
    local n_found = r(N)

    if `n_found' == 0 {
        di as text ""
        di as text "Variable {bf:`variable'} no encontrada en el indice."
        di as text ""
        di as text "Sugerencias:"
        di as text "  - Verifique el nombre exacto"
        di as text "  - Use {bf:inei search `variable'} para busqueda parcial"
        restore
        exit
    }

    local var_label = var_label[1]

    qui destring year, replace force
    sort survey year module_name

    * --- Mostrar ---
    di as text ""
    di as text "{bf:Tracking: `variable'}"
    if "`var_label'" != "" {
        _inei_display_wrapped "  " "`var_label'" 72
    }
    di as text ""

    local prev_survey ""
    local prev_year = .

    local N = _N
    forvalues i = 1/`N' {
        local vsurvey = survey[`i']
        local vyear   = year[`i']
        local vmod    = module_name[`i']
        local vcode   = module_code[`i']

        * Header cuando cambia encuesta
        if "`vsurvey'" != "`prev_survey'" {
            if "`prev_survey'" != "" {
                di as text ""
            }
            di as text "  {bf:`vsurvey'}"
            di as text "  {hline 50}"
            local prev_year = .
        }

        * Detectar gaps
        if "`vsurvey'" == "`prev_survey'" & `prev_year' != . {
            local gap = `vyear' - `prev_year'
            if `gap' > 1 {
                di as text "    {it:... gap `prev_year'-`vyear'}"
            }
        }

        local prev_survey "`vsurvey'"
        local prev_year = `vyear'

        * Truncar modulo
        if strlen("`vmod'") > 35 {
            local vmod = substr("`vmod'", 1, 32) + "..."
        }

        di as result "    `vyear'" as text "  `vmod'" as text "  {it:`vcode'}"
    }

    * Resumen
    qui levelsof survey, local(surveys)
    local n_surveys : word count `surveys'

    qui levelsof year, local(years)
    local n_years : word count `years'
    local first_year : word 1 of `years'
    local last_year  : word `n_years' of `years'

    di as text ""
    di as text "{hline 50}"
    di as text "  Encuestas: " as result "`n_surveys'" ///
        as text "  |  Anios: " as result "`n_years'" ///
        as text " (" as result "`first_year'" as text "-" as result "`last_year'" as text ")"
    di as text ""

    restore
end
