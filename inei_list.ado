*! inei_list.ado — Listar encuestas y modulos disponibles del INEI
*! version 1.0.2  2026-04-02

program define inei_list
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        PERIOD(string) MODULES CATALOG(string)]

    preserve

    _inei_catalog_utils load, catalog(`catalog')
    _inei_catalog_utils filter, survey(`survey') yearmin(`yearmin') ///
        yearmax(`yearmax') period(`period')

    if "`modules'" != "" {
        _inei_list_modules
    }
    else {
        _inei_list_surveys
    }

    restore
end

program define _inei_list_surveys
    collapse (min) year_min=year (max) year_max=year ///
        (count) n_modules=year, by(category survey_label)

    sort category year_min

    di as text ""
    di as text "{bf:Encuestas disponibles}"
    di as text ""

    local N = _N
    local prev_cat ""

    forvalues i = 1/`N' {
        local cat  = category[`i']
        local lab  = survey_label[`i']
        local ymin = year_min[`i']
        local ymax = year_max[`i']
        local nmod = n_modules[`i']

        * Header cuando cambia categoria
        if "`cat'" != "`prev_cat'" {
            if "`prev_cat'" != "" {
                di as text ""
            }
            di as text "  {bf:`cat'}"
            di as text "  {hline 65}"
        }
        local prev_cat "`cat'"

        * Truncar label
        if strlen("`lab'") > 45 {
            local lab = substr("`lab'", 1, 42) + "..."
        }

        di as text "    `lab'"
        di as text "      " as result "`ymin'" as text "-" ///
            as result "`ymax'" as text "  |  " ///
            as result "`nmod'" as text " modulos"
    }

    di as text ""
    di as text "{hline 65}"
    di as text "  Total: " as result _N as text " encuestas"
    di as text ""
end

program define _inei_list_modules
    sort category year period module_name

    di as text ""
    di as text "{bf:Modulos disponibles}"
    di as text ""

    local N = _N
    local prev_cat ""
    local prev_year = .

    forvalues i = 1/`N' {
        local cat   = category[`i']
        local yr    = year[`i']
        local per   = period[`i']
        local mname = module_name[`i']
        local scode = stata_code[`i']

        * Header cuando cambia encuesta
        if "`cat'" != "`prev_cat'" {
            if "`prev_cat'" != "" {
                di as text ""
            }
            di as text "  {bf:`cat'}"
            di as text "  {hline 65}"
            local prev_year = .
        }
        local prev_cat "`cat'"

        * Sub-header cuando cambia anio
        if `yr' != `prev_year' {
            di as text ""
            di as text "    {bf:`yr'} - `per'"
        }
        local prev_year = `yr'

        * Truncar modulo
        if strlen("`mname'") > 45 {
            local mname = substr("`mname'", 1, 42) + "..."
        }

        di as result "      `mname'" as text "  [`scode']"
    }

    di as text ""
    di as text "{hline 65}"
    di as text "  Total: " as result _N as text " modulos"
    di as text ""
end
