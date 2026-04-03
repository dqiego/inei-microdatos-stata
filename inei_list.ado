*! inei_list.ado — Listar encuestas y modulos disponibles del INEI
*! version 1.0.0  2026-04-02

program define inei_list
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        PERIOD(string) MODULES CATALOG(string)]

    * Preservar datos actuales
    preserve

    * Cargar catalogo
    _inei_catalog_utils load, catalog(`catalog')

    * Aplicar filtros
    _inei_catalog_utils filter, survey(`survey') yearmin(`yearmin') ///
        yearmax(`yearmax') period(`period')

    if "`modules'" != "" {
        * Mostrar detalle de modulos
        _inei_list_modules
    }
    else {
        * Mostrar resumen por encuesta
        _inei_list_surveys
    }

    restore
end

/* -----------------------------------------------------------------
   Mostrar resumen por encuesta
   ----------------------------------------------------------------- */
program define _inei_list_surveys
    * Crear tabla resumen
    tempvar tag
    egen `tag' = tag(category), by(category)

    * Calcular estadisticas por encuesta
    tempfile summary
    preserve

    collapse (min) year_min=year (max) year_max=year ///
        (count) n_modules=year, by(category survey_label)

    * Ordenar
    sort category year_min

    * Mostrar header
    di as text ""
    di as text "{bf:Encuestas disponibles en el catalogo INEI}"
    di as text "{hline 80}"
    di as text %~30s "Encuesta" " " %~15s "Categoria" " " ///
        %6s "Desde" " " %6s "Hasta" " " %8s "Modulos"
    di as text "{hline 80}"

    * Mostrar filas
    local N = _N
    forvalues i = 1/`N' {
        local cat = category[`i']
        local lab = survey_label[`i']
        local ymin = year_min[`i']
        local ymax = year_max[`i']
        local nmod = n_modules[`i']

        * Truncar label si es muy largo
        if strlen("`lab'") > 30 {
            local lab = substr("`lab'", 1, 27) + "..."
        }
        if strlen("`cat'") > 15 {
            local cat = substr("`cat'", 1, 12) + "..."
        }

        di as result %~30s "`lab'" " " as text %~15s "`cat'" " " ///
            as result %6.0f `ymin' " " %6.0f `ymax' " " %8.0f `nmod'
    }

    di as text "{hline 80}"
    di as text "Total: " as result _N as text " encuestas"
    di as text ""

    restore
end

/* -----------------------------------------------------------------
   Mostrar detalle de modulos
   ----------------------------------------------------------------- */
program define _inei_list_modules
    sort category year period module_name

    di as text ""
    di as text "{bf:Modulos disponibles}"
    di as text "{hline 90}"
    di as text %~20s "Encuesta" " " %5s "Anio" " " %~20s "Periodo" " " ///
        %~30s "Modulo" " " %10s "Codigo"
    di as text "{hline 90}"

    local N = _N
    local prev_cat ""

    forvalues i = 1/`N' {
        local cat = category[`i']
        local yr = year[`i']
        local per = period[`i']
        local mname = module_name[`i']
        local scode = stata_code[`i']

        * Separador cuando cambia encuesta
        if "`cat'" != "`prev_cat'" & "`prev_cat'" != "" {
            di as text "{hline 90}"
        }
        local prev_cat "`cat'"

        * Truncar si es muy largo
        if strlen("`cat'") > 20 {
            local cat = substr("`cat'", 1, 17) + "..."
        }
        if strlen("`per'") > 20 {
            local per = substr("`per'", 1, 17) + "..."
        }
        if strlen("`mname'") > 30 {
            local mname = substr("`mname'", 1, 27) + "..."
        }

        di as result %~20s "`cat'" " " as text %5.0f `yr' " " ///
            %~20s "`per'" " " as result %~30s "`mname'" " " ///
            as text %10s "`scode'"
    }

    di as text "{hline 90}"
    di as text "Total: " as result _N as text " modulos"
    di as text ""
end
