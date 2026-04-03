*! inei_docs.ado — Descargar documentacion del INEI
*! Cuestionarios, diccionarios, fichas tecnicas
*! version 1.0.0  2026-04-02

program define inei_docs
    version 14.0
    syntax , SURVEY(string) [DEST(string) YEARMIN(integer 0) ///
        YEARMAX(integer 9999) PERIOD(string) LAYOUT(string) DRYRUN]

    if "`dest'" == ""   local dest "."
    if "`layout'" == "" local layout "default"

    preserve

    * Buscar directorio de datos
    _inei_find_data_dir
    local datadir "`s(datadir)'"

    * Cargar tabla de docs
    local docs_dta "`datadir'/inei_docs.dta"
    capture confirm file "`docs_dta'"
    if _rc != 0 {
        * Importar desde CSV
        local docs_csv "`datadir'/inei_docs.csv"
        capture confirm file "`docs_csv'"
        if _rc != 0 {
            di as error "No se encontro tabla de documentos."
            di as error "Ejecute: inei crawl"
            restore
            exit 601
        }
        import delimited using "`docs_csv'", clear encoding("utf-8") ///
            stringcols(_all)
        destring year, replace
        compress
        save "`docs_dta'", replace
    }
    else {
        use "`docs_dta'", clear
    }

    * Resolver alias
    _inei_cat_resolve_alias `survey'
    local survey_resolved "`s(resolved)'"

    * Filtrar
    local survey_lower = strlower("`survey_resolved'")
    qui gen __match = strpos(strlower(category), "`survey_lower'") > 0
    qui keep if __match == 1
    qui drop __match

    if `yearmin' > 0 {
        qui keep if year >= `yearmin'
    }
    if `yearmax' < 9999 {
        qui keep if year <= `yearmax'
    }
    if "`period'" != "" {
        local period_lower = strlower("`period'")
        qui gen __pmatch = strpos(strlower(period), "`period_lower'") > 0
        qui keep if __pmatch == 1
        qui drop __pmatch
    }

    qui count
    local n_total = r(N)

    if `n_total' == 0 {
        di as error "No se encontraron documentos para: `survey'"
        restore
        exit 111
    }

    local base_url "https://proyectos.inei.gob.pe/iinei/srienaho/descarga/DocumentosZIP"

    di as text ""
    di as text "{bf:Descarga de documentacion INEI}"
    di as text "{hline 60}"
    di as text "  Encuesta:    `survey'"
    di as text "  Destino:     `dest'"
    di as text "  Documentos:  `n_total'"
    di as text "{hline 60}"

    if "`dryrun'" != "" {
        di as text ""
        di as text "{bf:MODO PREVIEW (dry-run)}"
        di as text ""
    }

    local n_ok = 0
    local n_skip = 0
    local n_fail = 0

    forvalues i = 1/`n_total' {
        local cat   = category[`i']
        local yr    = year[`i']
        local per   = period[`i']
        local dname = doc_name[`i']
        local zpath = zip_path[`i']

        if "`zpath'" == "" {
            local ++n_skip
            continue
        }

        local url "`base_url'/`zpath'"

        * Ruta destino
        if "`layout'" == "default" {
            local outpath "`dest'/`cat'/`yr'/docs"
        }
        else {
            local outpath "`dest'/`cat'/docs"
        }

        * Nombre del archivo
        local fname = subinstr("`zpath'", "/", "_", .)
        local outfile "`outpath'/`fname'"

        if "`dryrun'" != "" {
            di as text "  [`i'/`n_total'] `dname' (`yr')"
            di as text "           -> `outfile'"
            local ++n_ok
            continue
        }

        * Verificar si ya existe
        capture confirm file "`outfile'"
        if _rc == 0 {
            local ++n_skip
            continue
        }

        _inei_mkdir_p "`outpath'"

        di as text "  [`i'/`n_total'] `dname' (`yr')..." _continue

        capture copy "`url'" "`outfile'", replace
        if _rc != 0 {
            capture shell curl -s -k -L --max-time 120 -o "`outfile'" "`url'"
            if _rc != 0 {
                di as error " FALLO"
                local ++n_fail
                continue
            }
        }

        capture confirm file "`outfile'"
        if _rc != 0 {
            di as error " FALLO"
            local ++n_fail
            continue
        }

        di as result " OK"
        local ++n_ok
    }

    di as text ""
    di as text "{hline 60}"
    di as text "  Exitosos: " as result `n_ok'
    di as text "  Omitidos: " as result `n_skip'
    if `n_fail' > 0 {
        di as error "  Fallidos: `n_fail'"
    }
    di as text "{hline 60}"

    restore
end
