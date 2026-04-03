*! inei_append.ado — Apilar un mismo modulo a traves de multiples anios
*! Util para construir paneles o series longitudinales
*! version 1.0.0  2026-04-03

program define inei_append
    version 14.0
    syntax , SURVEY(string) MODULE(string) YEARMIN(integer) YEARMAX(integer) ///
        [CLEAR GEN(string) FORMAT(string) DEST(string)]

    if "`clear'" == "" {
        if c(changed) == 1 {
            di as error "datos en memoria no guardados; use la opcion {bf:clear}"
            exit 4
        }
    }

    if `yearmin' > `yearmax' {
        di as error "yearmin debe ser menor o igual a yearmax"
        exit 198
    }

    di as text ""
    di as text "{bf:Append de modulo INEI entre anios}"
    di as text "  Encuesta:  `survey'"
    di as text "  Modulo:    `module'"
    di as text "  Rango:     `yearmin' - `yearmax'"
    di as text ""

    * --- Identificar anios disponibles ---
    preserve
    _inei_cat_load
    _inei_cat_filter, survey(`survey') yearmin(`yearmin') yearmax(`yearmax')

    * Filtrar por modulo (con/sin ceros iniciales + stata_code)
    local mod_lower = strlower("`module'")
    local mod_nozero = "`mod_lower'"
    while substr("`mod_nozero'", 1, 1) == "0" & strlen("`mod_nozero'") > 1 {
        local mod_nozero = substr("`mod_nozero'", 2, .)
    }
    qui gen __mmatch = strlower(module_code) == "`mod_lower'" | ///
                       strlower(module_code) == "`mod_nozero'" | ///
                       regexm(strlower(stata_code), "modulo0*`mod_nozero'$")
    capture confirm integer number `module'
    if _rc != 0 {
        qui replace __mmatch = 1 if ///
            strpos(strlower(module_name), "`mod_lower'") > 0
    }
    qui keep if __mmatch == 1
    qui drop __mmatch

    qui count
    if r(N) == 0 {
        di as error "No se encontro modulo '`module'' en `survey' `yearmin'-`yearmax'"
        restore
        exit 111
    }

    * Obtener lista de anios unicos
    qui levelsof year, local(years_avail)
    local n_years : word count `years_avail'
    restore

    di as text "  Anios disponibles: `n_years' (`years_avail')"
    di as text ""

    * --- Cargar primer anio ---
    local first_year : word 1 of `years_avail'
    local yr_count = 0

    di as text "  [1/`n_years'] Cargando `first_year'..."
    capture inei_use, survey(`survey') year(`first_year') module(`module') ///
        clear format(`format') dest(`dest')

    if _rc != 0 {
        di as error "Error cargando `survey' `first_year' modulo `module'"
        exit _rc
    }

    if "`gen'" != "" {
        qui gen int `gen' = `first_year'
    }

    local yr_count = `yr_count' + 1
    tempfile append_data
    qui save "`append_data'"

    * Recordar variables del primer anio
    qui describe, varlist short
    local vars_base "`r(varlist)'"
    local n_vars_base : word count `vars_base'

    * --- Apilar anios restantes ---
    forvalues i = 2/`n_years' {
        local yr : word `i' of `years_avail'
        di as text "  [`i'/`n_years'] Cargando `yr'..."

        capture inei_use, survey(`survey') year(`yr') module(`module') ///
            clear format(`format') dest(`dest')

        if _rc != 0 {
            di as text "    {it:Error, saltando anio `yr'}"
            continue
        }

        * Verificar si las variables son las mismas
        qui describe, varlist short
        local vars_yr "`r(varlist)'"
        local n_vars_yr : word count `vars_yr'

        if `n_vars_yr' != `n_vars_base' {
            di as text "    {it:Nota: `n_vars_yr' vars vs `n_vars_base' en anio base (posible cambio metodologico)}"
        }

        if "`gen'" != "" {
            capture confirm variable `gen'
            if _rc != 0 {
                qui gen int `gen' = `yr'
            }
            else {
                qui replace `gen' = `yr'
            }
        }

        qui append using "`append_data'"
        qui save "`append_data'", replace
        local yr_count = `yr_count' + 1
    }

    * Cargar resultado final
    qui use "`append_data'", clear

    * Estampar metadata
    char define _dta[inei_survey]      "`survey'"
    char define _dta[inei_module]      "`module'"
    char define _dta[inei_yearmin]     "`yearmin'"
    char define _dta[inei_yearmax]     "`yearmax'"
    char define _dta[inei_append_date] "`c(current_date)'"
    char define _dta[inei_n_years]     "`yr_count'"

    di as text ""
    di as text "{bf:Append completado}"
    di as text "  Anios:      `yr_count' de `n_years'"
    di as text "  Obs:        " as result c(N) as text "  Variables: " as result c(k)
    if "`gen'" != "" {
        di as text "  Variable anio: `gen'"
    }
    di as text ""
end
