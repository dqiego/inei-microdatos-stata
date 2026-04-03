*! inei_merge.ado — Combinar modulos de una misma encuesta-anio
*! Hace merge automatico usando keys de identificacion conocidos
*! version 1.0.0  2026-04-03

program define inei_merge
    version 14.0
    syntax , SURVEY(string) YEAR(integer) MODULES(string) ///
        [CLEAR ON(string) FORMAT(string) DEST(string)]

    if "`clear'" == "" {
        if c(changed) == 1 {
            di as error "datos en memoria no guardados; use la opcion {bf:clear}"
            exit 4
        }
    }

    * Parsear lista de modulos
    local n_modules : word count `modules'
    if `n_modules' < 2 {
        di as error "Necesita al menos 2 modulos para merge"
        di as text "Ejemplo: inei merge, survey(enaho) year(2024) modules(01 34) clear"
        exit 198
    }

    di as text ""
    di as text "{bf:Merge de modulos INEI}"
    di as text "  Encuesta: `survey' `year'"
    di as text "  Modulos:  `modules'"
    di as text ""

    * --- Cargar primer modulo ---
    local mod1 : word 1 of `modules'
    di as text "  [1/`n_modules'] Cargando modulo `mod1'..."
    inei_use, survey(`survey') year(`year') module(`mod1') clear ///
        format(`format') dest(`dest')

    * Detectar keys de merge
    _inei_merge_keys, survey(`survey') on(`on')
    local merge_keys "`s(keys)'"
    local merge_level "`s(level)'"

    di as text ""
    di as text "  Keys de merge: `merge_keys' (nivel: `merge_level')"
    di as text ""

    * Guardar primer modulo
    tempfile base_data
    qui save "`base_data'"
    local base_n = c(N)

    * --- Iterar modulos restantes ---
    forvalues i = 2/`n_modules' {
        local modi : word `i' of `modules'
        di as text "  [`i'/`n_modules'] Merge con modulo `modi'..."

        * Cargar modulo en tempfile
        tempfile merge_data
        inei_use, survey(`survey') year(`year') module(`modi') clear ///
            format(`format') dest(`dest')
        qui save "`merge_data'"

        * Cargar base y hacer merge
        qui use "`base_data'", clear
        qui merge 1:1 `merge_keys' using "`merge_data'", nogenerate

        * Reportar resultado
        qui count
        di as text "    Obs despues de merge: " as result r(N)

        * Guardar resultado como nueva base
        qui save "`base_data'", replace
    }

    * Cargar resultado final
    qui use "`base_data'", clear

    * Estampar metadata del merge
    char define _dta[inei_survey]     "`survey'"
    char define _dta[inei_year]       "`year'"
    char define _dta[inei_modules]    "`modules'"
    char define _dta[inei_merge_keys] "`merge_keys'"
    char define _dta[inei_merge_date] "`c(current_date)'"

    di as text ""
    di as text "{bf:Merge completado}"
    di as text "  Modulos:    `modules'"
    di as text "  Keys:       `merge_keys'"
    di as text "  Obs:        " as result c(N) as text "  Variables: " as result c(k)
    di as text ""
end
