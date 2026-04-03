*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! Usa un script .bat para mantener cookies entre requests curl
*! version 1.0.4  2026-04-02

program define inei_crawl
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        REFRESH DEST(string) DELAY(real 0.3)]

    if "`dest'" == "" {
        _inei_find_data_dir
        local dest "`s(datadir)'"
    }

    capture mkdir "`dest'"

    local tmpdir "`c(tmpdir)'"
    local cookiefile "`tmpdir'/inei_cookies.txt"
    local tmphtml "`tmpdir'/inei_resp.html"
    local batfile "`tmpdir'/inei_curl.bat"
    local base_url "https://proyectos.inei.gob.pe/microdatos"

    di as text ""
    di as text "{bf:Crawling portal INEI de microdatos}"
    di as text "{hline 60}"
    di as text "  URL: `base_url'/"
    di as text "  Destino: `dest'"
    di as text "{hline 60}"
    di as text ""

    * --- Paso 1: Iniciar sesion ---
    di as text "Paso 1: Iniciando sesion con el portal..."

    * Escribir script bat para init
    capture erase "`cookiefile'"
    _inei_write_bat "`batfile'" ///
        `"curl -s -k -L -c "`cookiefile'" -o "`tmphtml'" "`base_url'/Consulta_por_Encuesta.asp?CU=19558""'
    quietly ! "`batfile'"

    capture confirm file "`tmphtml'"
    if _rc != 0 {
        di as error "Error: no se pudo conectar al portal INEI"
        exit 601
    }
    qui checksum "`tmphtml'"
    if r(filelen) < 100 {
        di as error "Error: respuesta vacia del portal"
        exit 601
    }

    di as text "  Sesion iniciada"

    * --- Paso 2: Extraer encuestas ---
    di as text "Paso 2: Extrayendo lista de encuestas..."

    preserve
    capture _inei_parse surveys, file("`tmphtml'")
    capture confirm variable opt_value
    if _rc != 0 {
        di as error "Error: no se pudieron extraer encuestas"
        restore
        exit 601
    }

    qui drop if opt_value == "" | opt_value == "0"
    qui count
    local n_surveys = r(N)
    di as text "  Encontradas: `n_surveys' encuestas"

    tempfile survey_list
    qui save "`survey_list'"

    * --- Paso 3: Iterar ---
    di as text "Paso 3: Crawleando encuestas..."

    * Catalogo vacio
    clear
    gen str244 category = ""
    gen str100 survey_value = ""
    gen str244 survey_label = ""
    gen int year = .
    gen str244 period = ""
    gen str100 period_value = ""
    gen str100 module_code = ""
    gen str244 module_name = ""
    gen str100 csv_code = ""
    gen str100 stata_code = ""
    gen str100 spss_code = ""
    tempfile catalog_build
    qui save "`catalog_build'"

    * Docs vacio
    clear
    gen str244 category = ""
    gen str100 survey_value = ""
    gen int year = .
    gen str244 period = ""
    gen str244 doc_name = ""
    gen str244 zip_path = ""
    tempfile docs_build
    qui save "`docs_build'"

    local total_modules = 0
    local total_docs = 0
    local delay_ms = round(`delay' * 1000)

    forvalues s = 1/`n_surveys' {
        qui use "`survey_list'", clear
        local sv = opt_value[`s']
        local sl = opt_label[`s']

        * Filtrar por encuesta
        if "`survey'" != "" {
            _inei_cat_resolve_alias `survey'
            local sf = strlower("`s(resolved)'")
            if strpos(strlower("`sl'"), "`sf'") == 0 {
                continue
            }
        }

        di as text ""
        di as text "  [`s'/`n_surveys'] `sl'"
        local category "`sl'"

        * --- Obtener anios ---
        _inei_encode "`sv'"
        local sv_enc "`s(encoded)'"

        _inei_write_bat "`batfile'" ///
            `"curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "bandera=1&_cmbEncuesta=`sv_enc'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/CambiaEnc.asp""'
        quietly ! "`batfile'"
        sleep `delay_ms'

        capture _inei_parse options, file("`tmphtml'")
        capture confirm variable opt_value
        if _rc != 0 {
            di as text "    Sin anios disponibles"
            continue
        }

        qui drop if opt_value == "" | opt_value == "0"
        qui count
        local n_years = r(N)
        if `n_years' == 0 {
            di as text "    Sin anios disponibles"
            continue
        }

        tempfile year_list
        qui save "`year_list'"

        forvalues y = 1/`n_years' {
            qui use "`year_list'", clear
            local yv = opt_value[`y']
            local yl = opt_label[`y']

            local year_num = real("`yv'")
            if `year_num' == . local year_num = real("`yl'")

            if `year_num' != . {
                if `year_num' < `yearmin' | `year_num' > `yearmax' continue
            }

            di as text "    `yl'..." _continue

            * --- Obtener periodos ---
            _inei_encode "`sv'"
            local sv_e "`s(encoded)'"
            _inei_encode "`yv'"
            local yv_e "`s(encoded)'"

            _inei_write_bat "`batfile'" ///
                `"curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbEncuesta0=`sv_e'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/CambiaAnio.asp""'
            quietly ! "`batfile'"
            sleep `delay_ms'

            capture _inei_parse options, file("`tmphtml'")
            capture confirm variable opt_value
            if _rc != 0 {
                di as text " sin periodos"
                continue
            }

            qui drop if opt_value == "" | opt_value == "0"
            qui count
            local n_periods = r(N)
            if `n_periods' == 0 {
                di as text " sin periodos"
                continue
            }

            tempfile period_list
            qui save "`period_list'"

            local yr_modules = 0

            forvalues p = 1/`n_periods' {
                qui use "`period_list'", clear
                local pv = opt_value[`p']
                local pl = opt_label[`p']

                _inei_encode "`sv'"
                local sv_e2 "`s(encoded)'"
                _inei_encode "`yv'"
                local yv_e2 "`s(encoded)'"
                _inei_encode "`pv'"
                local pv_e2 "`s(encoded)'"

                * --- Modulos ---
                _inei_write_bat "`batfile'" ///
                    `"curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e2'&_cmbAnno=`yv_e2'&_cmbTrimestre=`pv_e2'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/cambiaPeriodo.asp""'
                quietly ! "`batfile'"
                sleep `delay_ms'

                capture _inei_parse modules, file("`tmphtml'")
                capture confirm variable module_name
                if _rc == 0 {
                    qui count
                    local n_mods = r(N)
                    if `n_mods' > 0 {
                        qui gen str244 category = "`category'"
                        qui gen str100 survey_value = "`sv'"
                        qui gen str244 survey_label = "`sl'"
                        qui gen int year = `year_num'
                        qui gen str244 period = "`pl'"
                        qui gen str100 period_value = "`pv'"
                        qui gen str100 module_code = ""
                        capture qui replace module_code = regexs(2) ///
                            if regexm(stata_code, "^([0-9]+)-Modulo(.+)$")

                        qui append using "`catalog_build'"
                        qui save "`catalog_build'", replace

                        local yr_modules = `yr_modules' + `n_mods'
                        local total_modules = `total_modules' + `n_mods'
                    }
                }

                * --- Documentacion ---
                _inei_write_bat "`batfile'" ///
                    `"curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e2'&_cmbAnno=`yv_e2'&_cmbTrimestre=`pv_e2'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/CambiaPeriodoDoc.asp""'
                quietly ! "`batfile'"
                sleep `delay_ms'

                capture _inei_parse docs, file("`tmphtml'")
                capture confirm variable doc_name
                if _rc == 0 {
                    qui count
                    local n_d = r(N)
                    if `n_d' > 0 {
                        qui gen str244 category = "`category'"
                        qui gen str100 survey_value = "`sv'"
                        qui gen int year = `year_num'
                        qui gen str244 period = "`pl'"

                        qui append using "`docs_build'"
                        qui save "`docs_build'", replace

                        local total_docs = `total_docs' + `n_d'
                    }
                }
            }

            di as text " `yr_modules' modulos"
        }
    }

    * --- Paso 4: Guardar ---
    di as text ""
    di as text "Paso 4: Guardando catalogo..."

    qui use "`catalog_build'", clear
    qui count
    if r(N) > 0 {
        qui drop if category == "" & survey_value == ""
        compress
        sort category year period module_name
        save "`dest'/inei_catalog.dta", replace
        di as text "  Catalogo: `dest'/inei_catalog.dta (`total_modules' modulos)"
    }
    else {
        di as error "  No se encontraron modulos"
    }

    qui use "`docs_build'", clear
    qui count
    if r(N) > 0 {
        qui drop if category == "" & survey_value == ""
        compress
        sort category year period doc_name
        save "`dest'/inei_docs.dta", replace
        di as text "  Docs: `dest'/inei_docs.dta (`total_docs' docs)"
    }

    capture erase "`cookiefile'"
    capture erase "`tmphtml'"
    capture erase "`batfile'"

    di as text ""
    di as text "{hline 60}"
    di as text "{bf:Crawling completado}"
    di as text "  Modulos:    `total_modules'"
    di as text "  Documentos: `total_docs'"
    di as text "{hline 60}"

    restore
end

/* -----------------------------------------------------------------
   Escribir un .bat con un solo comando curl
   Esto asegura que cmd.exe ejecute curl con las comillas correctas
   ----------------------------------------------------------------- */
program define _inei_write_bat
    args batfile curl_cmd

    tempname fh
    file open `fh' using "`batfile'", write replace
    file write `fh' "@echo off" _n
    file write `fh' `"`curl_cmd'"' _n
    file close `fh'
end
