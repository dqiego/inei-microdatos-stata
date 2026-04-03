*! inei_download.ado — Descargar microdatos del INEI
*! Soporta formatos CSV, STATA, SPSS con fallback automatico
*! version 1.0.0  2026-04-02

program define inei_download
    version 14.0
    syntax , SURVEY(string) [FORMAT(string) DEST(string) ///
        YEARMIN(integer 0) YEARMAX(integer 9999) PERIOD(string) ///
        LAYOUT(string) NOFALLBACK DRYRUN DOCS CATALOG(string)]

    * Valores por defecto
    if "`format'" == "" local format "STATA"
    if "`dest'" == ""   local dest "."
    if "`layout'" == "" local layout "default"

    * Validar formato
    local format = strupper("`format'")
    if !inlist("`format'", "CSV", "STATA", "SPSS") {
        di as error "Formato invalido: `format'. Use CSV, STATA o SPSS"
        exit 198
    }

    * Preservar datos
    preserve

    * Cargar y filtrar catalogo
    _inei_catalog_utils load, catalog(`catalog')
    _inei_catalog_utils filter, survey(`survey') yearmin(`yearmin') ///
        yearmax(`yearmax') period(`period')

    qui count
    local n_total = r(N)

    if `n_total' == 0 {
        di as error "No se encontraron modulos con los filtros especificados"
        restore
        exit 111
    }

    * Base URL de descarga
    local base_url "https://proyectos.inei.gob.pe/iinei/srienaho/descarga"

    * Crear directorio destino
    capture mkdir "`dest'"

    * Determinar columna de codigo segun formato
    local code_var "stata_code"
    if "`format'" == "CSV"  local code_var "csv_code"
    if "`format'" == "SPSS" local code_var "spss_code"

    * Contar modulos con codigo disponible
    qui count if `code_var' != ""
    local n_available = r(N)

    di as text ""
    di as text "{bf:Descarga de microdatos INEI}"
    di as text "{hline 60}"
    di as text "  Encuesta:    `survey'"
    di as text "  Formato:     `format'"
    di as text "  Destino:     `dest'"
    di as text "  Modulos:     `n_available' de `n_total' disponibles"
    if `yearmin' > 0 | `yearmax' < 9999 {
        di as text "  Anios:       `yearmin' - `yearmax'"
    }
    di as text "{hline 60}"

    if "`dryrun'" != "" {
        di as text ""
        di as text "{bf:MODO PREVIEW (dry-run) — no se descargara nada}"
        di as text ""
    }

    * Iterar modulos y descargar
    local n_ok = 0
    local n_skip = 0
    local n_fail = 0
    local n_fallback = 0

    forvalues i = 1/`n_total' {
        local cat  = category[`i']
        local yr   = year[`i']
        local per  = period[`i']
        local mname = module_name[`i']
        local code = `code_var'[`i']
        local csv_c = csv_code[`i']
        local sta_c = stata_code[`i']
        local sps_c = spss_code[`i']

        * Si no hay codigo para el formato preferido, intentar fallback
        local dl_format "`format'"
        local dl_code "`code'"

        if "`dl_code'" == "" & "`nofallback'" == "" {
            * Fallback chain
            if "`format'" == "STATA" {
                if "`csv_c'" != "" {
                    local dl_code "`csv_c'"
                    local dl_format "CSV"
                    local ++n_fallback
                }
                else if "`sps_c'" != "" {
                    local dl_code "`sps_c'"
                    local dl_format "SPSS"
                    local ++n_fallback
                }
            }
            else if "`format'" == "CSV" {
                if "`sta_c'" != "" {
                    local dl_code "`sta_c'"
                    local dl_format "STATA"
                    local ++n_fallback
                }
                else if "`sps_c'" != "" {
                    local dl_code "`sps_c'"
                    local dl_format "SPSS"
                    local ++n_fallback
                }
            }
            else if "`format'" == "SPSS" {
                if "`csv_c'" != "" {
                    local dl_code "`csv_c'"
                    local dl_format "CSV"
                    local ++n_fallback
                }
                else if "`sta_c'" != "" {
                    local dl_code "`sta_c'"
                    local dl_format "STATA"
                    local ++n_fallback
                }
            }
        }

        if "`dl_code'" == "" {
            local ++n_skip
            if "`dryrun'" != "" {
                di as text "  SKIP  [`i'/`n_total'] `mname' (`yr') — no disponible"
            }
            continue
        }

        * Construir URL
        local url "`base_url'/`dl_format'/`dl_code'.zip"

        * Construir ruta destino segun layout
        local outpath ""
        if "`layout'" == "default" {
            local outpath "`dest'/`cat'/`yr'/`per'"
        }
        else if "`layout'" == "flat" {
            local outpath "`dest'/`cat'"
        }
        else if "`layout'" == "by-year" {
            local outpath "`dest'/`cat'/`yr'"
        }
        else if "`layout'" == "by-format" {
            local outpath "`dest'/`dl_format'/`cat'/`yr'"
        }
        else {
            * Layout personalizado
            local outpath "`layout'"
            local outpath = subinstr("`outpath'", "{survey}", "`cat'", .)
            local outpath = subinstr("`outpath'", "{year}", "`yr'", .)
            local outpath = subinstr("`outpath'", "{period}", "`per'", .)
            local outpath = subinstr("`outpath'", "{format}", "`dl_format'", .)
            local outpath "`dest'/`outpath'"
        }

        local outfile "`outpath'/`dl_code'.zip"

        if "`dryrun'" != "" {
            * Solo mostrar que se descargaria
            local fb_tag ""
            if "`dl_format'" != "`format'" {
                local fb_tag " [fallback: `dl_format']"
            }
            di as text "  [`i'/`n_total'] `mname' (`yr')`fb_tag'"
            di as text "           URL: `url'"
            di as text "           -> `outfile'"
            local ++n_ok
            continue
        }

        * Verificar si ya existe
        capture confirm file "`outfile'"
        if _rc == 0 {
            * Verificar que es ZIP valido (al menos tiene contenido)
            local ++n_skip
            di as text "  SKIP  [`i'/`n_total'] `dl_code'.zip (ya existe)"
            continue
        }

        * Crear directorios
        _inei_mkdir_p "`outpath'"

        * Descargar
        local fb_tag ""
        if "`dl_format'" != "`format'" {
            local fb_tag " [fallback: `dl_format']"
        }
        di as text "  [`i'/`n_total'] Descargando `dl_code'.zip`fb_tag'..." _continue

        * Intentar con copy primero, fallback a curl
        capture copy "`url'" "`outfile'", replace
        if _rc != 0 {
            * Fallback a curl
            capture shell curl -s -k -L --max-time 120 -o "`outfile'" "`url'"
            if _rc != 0 {
                di as error " FALLO"
                local ++n_fail
                continue
            }
        }

        * Verificar que se descargo
        capture confirm file "`outfile'"
        if _rc != 0 {
            di as error " FALLO"
            local ++n_fail
            continue
        }

        * Verificar tamano (no vacio)
        qui checksum "`outfile'"
        if r(filelen) == 0 {
            di as error " VACIO"
            capture erase "`outfile'"
            local ++n_fail
            continue
        }

        di as result " OK"
        local ++n_ok
    }

    * Resumen
    di as text ""
    di as text "{hline 60}"
    di as text "{bf:Resumen de descarga}"
    di as text "  Exitosos:    " as result `n_ok'
    di as text "  Omitidos:    " as result `n_skip'
    if `n_fallback' > 0 {
        di as text "  Con fallback:" as result `n_fallback'
    }
    if `n_fail' > 0 {
        di as error "  Fallidos:    `n_fail'"
    }
    di as text "{hline 60}"

    * Descargar docs si se pidio
    if "`docs'" != "" {
        di as text ""
        di as text "Descargando documentacion..."
        inei_docs, survey(`survey') dest(`dest') yearmin(`yearmin') ///
            yearmax(`yearmax')
    }

    restore

    * Retornar en r()
    return scalar n_ok = `n_ok'
    return scalar n_skip = `n_skip'
    return scalar n_fail = `n_fail'
    return scalar n_total = `n_total'
end

/* -----------------------------------------------------------------
   Crear directorios recursivamente (mkdir -p)
   ----------------------------------------------------------------- */
program define _inei_mkdir_p
    args path

    * Reemplazar backslash por forward slash
    local path = subinstr("`path'", "\", "/", .)

    * Crear cada nivel
    local parts ""
    local current ""

    tokenize "`path'", parse("/")
    while "`1'" != "" {
        if "`1'" != "/" {
            if "`current'" == "" {
                local current "`1'"
            }
            else {
                local current "`current'/`1'"
            }
            capture mkdir "`current'"
        }
        macro shift
    }
end
