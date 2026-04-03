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

    qui destring year, replace force
    sort survey year module_name

    * --- Mostrar todo via Mata ---
    di as text ""
    di as text "{bf:Tracking: `variable'}"
    mata: _inei_show_track_results()

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

mata:
void _inei_show_track_results()
{
    string scalar vlabel, vsurvey, vmod, vcode, prev_survey
    real scalar i, n, vyear, prev_year, gap_yrs

    n = st_nobs()
    vlabel = st_sdata(1, "var_label")

    // Word-wrap del label
    {
        string scalar remaining, chunk, line
        real scalar line_len, break_pos, j
        line_len = 70
        remaining = vlabel
        while (strlen(remaining) > 0) {
            if (strlen(remaining) <= line_len) {
                printf("  %s\n", remaining)
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
                printf("  %s\n", line)
            }
        }
    }
    printf("\n")

    prev_survey = ""
    prev_year = .

    for (i = 1; i <= n; i++) {
        vsurvey = st_sdata(i, "survey")
        vyear   = st_data(i, "year")
        vmod    = st_sdata(i, "module_name")
        vcode   = st_sdata(i, "module_code")

        // Header cuando cambia encuesta
        if (vsurvey != prev_survey) {
            if (prev_survey != "") printf("\n")
            printf("  %s\n", vsurvey)
            printf("  %s\n", "--------------------------------------------------")
            prev_year = .
        }

        // Detectar gaps
        if (vsurvey == prev_survey & prev_year != .) {
            if (vyear - prev_year > 1) {
                gap_yrs = vyear - prev_year - 1
                printf("    (%g anios sin datos: %g-%g)\n",
                    gap_yrs, prev_year + 1, vyear - 1)
            }
        }

        prev_survey = vsurvey
        prev_year = vyear

        // Truncar modulo
        if (strlen(vmod) > 35) {
            vmod = substr(vmod, 1, 32) + "..."
        }

        printf("    %g  %s  %s\n", vyear, vmod, vcode)
    }

    printf("\n")
}
end
