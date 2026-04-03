*! _inei_catalog_utils.ado — Utilidades para cargar y filtrar catalogo INEI
*! version 1.0.0  2026-04-02

program define _inei_catalog_utils
    version 14.0
    syntax anything(name=action), [SURVEY(string) YEARMIN(integer 0) ///
        YEARMAX(integer 9999) PERIOD(string) CATALOG(string)]

    local action = `action'

    if "`action'" == "load" {
        _inei_cat_load, catalog(`catalog')
    }
    else if "`action'" == "filter" {
        _inei_cat_filter, survey(`survey') yearmin(`yearmin') ///
            yearmax(`yearmax') period(`period')
    }
    else if "`action'" == "resolve_alias" {
        _inei_cat_resolve_alias `survey'
    }
    else {
        di as error "_inei_catalog_utils: accion desconocida '`action''"
        exit 198
    }
end

/* -----------------------------------------------------------------
   Cargar catalogo .dta o importar desde CSV si no existe .dta
   Preserva datos actuales usando frames (Stata 16+) o tempfile
   ----------------------------------------------------------------- */
program define _inei_cat_load
    syntax , [CATALOG(string)]

    * Encontrar directorio del paquete
    if "`catalog'" == "" {
        _inei_find_data_dir
        local datadir "`s(datadir)'"
        local catalog "`datadir'/inei_catalog.dta"
    }

    * Si existe .dta, cargar directamente
    capture confirm file "`catalog'"
    if _rc == 0 {
        use "`catalog'", clear
        exit
    }

    * Si no existe .dta, buscar CSV e importar
    local csv_path = subinstr("`catalog'", ".dta", ".csv", 1)
    capture confirm file "`csv_path'"
    if _rc == 0 {
        di as text "Importando catalogo desde CSV (primera vez)..."
        import delimited using "`csv_path'", clear encoding("utf-8") ///
            stringcols(_all)
        destring year, replace
        compress
        save "`catalog'", replace
        di as text "Catalogo guardado como .dta para futuras cargas"
        exit
    }

    di as error "No se encontro catalogo. Ejecute: inei crawl"
    exit 601
end

/* -----------------------------------------------------------------
   Filtrar catalogo ya cargado en memoria
   ----------------------------------------------------------------- */
program define _inei_cat_filter
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        PERIOD(string)]

    * Resolver alias de encuesta
    if "`survey'" != "" {
        _inei_cat_resolve_alias `survey'
        local survey "`s(resolved)'"

        * Filtrar por encuesta (busqueda parcial, case-insensitive)
        local survey_lower = strlower("`survey'")
        gen __match = strpos(strlower(category), "`survey_lower'") > 0 | ///
                      strpos(strlower(survey_label), "`survey_lower'") > 0
        keep if __match == 1
        drop __match

        if _N == 0 {
            di as error "No se encontro encuesta: `survey'"
            exit 111
        }
    }

    * Filtrar por rango de anios
    if `yearmin' > 0 {
        keep if year >= `yearmin'
    }
    if `yearmax' < 9999 {
        keep if year <= `yearmax'
    }

    * Filtrar por periodo
    if "`period'" != "" {
        local period_lower = strlower("`period'")
        gen __pmatch = strpos(strlower(period), "`period_lower'") > 0
        keep if __pmatch == 1
        drop __pmatch
    }

    if _N == 0 {
        di as error "No se encontraron resultados con los filtros especificados"
        exit 111
    }
end

/* -----------------------------------------------------------------
   Resolver alias de encuesta a nombre completo
   ----------------------------------------------------------------- */
program define _inei_cat_resolve_alias, sclass
    args alias_input

    local alias_lower = strlower("`alias_input'")

    * Aliases hardcoded (los mas comunes)
    * Se podrian cargar de inei_aliases.dta pero esto es mas rapido

    if "`alias_lower'" == "enaho" {
        sreturn local resolved "ENAHO"
    }
    else if "`alias_lower'" == "endes" {
        sreturn local resolved "ENDES"
    }
    else if "`alias_lower'" == "epen" {
        sreturn local resolved "EPEN"
    }
    else if "`alias_lower'" == "cenagro" {
        sreturn local resolved "CENAGRO"
    }
    else if "`alias_lower'" == "eea" {
        sreturn local resolved "EEA"
    }
    else if "`alias_lower'" == "enapres" {
        sreturn local resolved "ENAPRES"
    }
    else if "`alias_lower'" == "enaho_anterior" | "`alias_lower'" == "enaho-anterior" {
        sreturn local resolved "ENAHO Anterior"
    }
    else if "`alias_lower'" == "enaho_actualizada" | "`alias_lower'" == "enaho-actualizada" {
        sreturn local resolved "ENAHO Actualizada"
    }
    else if "`alias_lower'" == "censo" {
        sreturn local resolved "Censo"
    }
    else if "`alias_lower'" == "sisfoh" {
        sreturn local resolved "SISFOH"
    }
    else if "`alias_lower'" == "enh" {
        sreturn local resolved "ENH"
    }
    else if "`alias_lower'" == "enacom" {
        sreturn local resolved "ENACOM"
    }
    else if "`alias_lower'" == "enahur" {
        sreturn local resolved "ENAHUR"
    }
    else if "`alias_lower'" == "enniv" {
        sreturn local resolved "ENNIV"
    }
    else if "`alias_lower'" == "encuesta_demografica" {
        sreturn local resolved "Demografica"
    }
    else if "`alias_lower'" == "enssa" {
        sreturn local resolved "ENSSA"
    }
    else if "`alias_lower'" == "enesem" {
        sreturn local resolved "ENESEM"
    }
    else {
        * No es alias conocido, devolver tal cual
        sreturn local resolved "`alias_input'"
    }
end

/* -----------------------------------------------------------------
   Encontrar directorio de datos del paquete
   ----------------------------------------------------------------- */
program define _inei_find_data_dir, sclass
    * Buscar en adopath
    capture findfile inei.ado
    if _rc == 0 {
        local ado_path "`r(fn)'"
        * Extraer directorio
        mata: st_local("ado_dir", pathbasename(st_local("ado_path")))

        * El directorio data/ esta junto al .ado
        local datadir = subinstr("`ado_path'", "inei.ado", "data", 1)
        capture confirm file "`datadir'/inei_catalog.dta"
        if _rc == 0 {
            sreturn local datadir "`datadir'"
            exit
        }
        capture confirm file "`datadir'/inei_catalog.csv"
        if _rc == 0 {
            sreturn local datadir "`datadir'"
            exit
        }
    }

    * Fallback: buscar en directorio actual
    capture confirm file "data/inei_catalog.dta"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }
    capture confirm file "data/inei_catalog.csv"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }

    * Fallback: directorio de usuario
    local userdir "~/.inei-microdatos"
    capture confirm file "`userdir'/inei_catalog.dta"
    if _rc == 0 {
        sreturn local datadir "`userdir'"
        exit
    }

    * No encontrado
    sreturn local datadir "data"
end
