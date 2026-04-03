*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! version 1.0.2  2026-04-02

program define inei_crawl
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        REFRESH DEST(string) DELAY(real 0.2)]

    if "`dest'" == "" {
        _inei_find_data_dir
        local dest "`s(datadir)'"
    }

    capture mkdir "`dest'"

    di as text ""
    di as text "{bf:Crawling portal INEI de microdatos}"
    di as text "{hline 60}"
    di as text "  URL: https://proyectos.inei.gob.pe/microdatos/"
    di as text "  Delay entre requests: `delay's"
    di as text "  Destino: `dest'"
    di as text "{hline 60}"
    di as text ""

    * --- Paso 1: Iniciar sesion ---
    di as text "Paso 1: Iniciando sesion con el portal..."

    * Usar directorios temporales con rutas cortas (sin espacios)
    local tmpdir "`c(tmpdir)'"
    local cookiefile "`tmpdir'/inei_cookies.txt"
    local tmphtml "`tmpdir'/inei_tmp.html"

    local base_url "https://proyectos.inei.gob.pe/microdatos"
    local init_url "`base_url'/Consulta_por_Encuesta.asp?CU=19558"

    quietly ! curl -s -k -L -c "`cookiefile'" -o "`tmphtml'" "`init_url'"

    capture confirm file "`tmphtml'"
    if _rc != 0 {
        di as error "Error: no se pudo conectar al portal INEI"
        di as error "Verifique que curl esta instalado y tiene conexion a internet"
        exit 601
    }

    * Verificar que el archivo no esta vacio
    qui checksum "`tmphtml'"
    if r(filelen) < 100 {
        di as error "Error: respuesta vacia del portal INEI"
        exit 601
    }

    * --- Paso 2: Extraer lista de encuestas ---
    di as text "Paso 2: Extrayendo lista de encuestas..."

    preserve
    capture _inei_parse surveys, file("`tmphtml'")

    * Verificar que se parsearon encuestas
    capture confirm variable opt_value
    if _rc != 0 {
        di as error "Error: no se pudieron extraer encuestas del portal"
        di as error "El formato del portal puede haber cambiado"
        restore
        exit 601
    }

    qui drop if opt_value == "" | opt_value == "0"

    qui count
    local n_surveys = r(N)

    if `n_surveys' == 0 {
        di as error "Error: no se encontraron encuestas"
        restore
        exit 601
    }

    di as text "  Encontradas: `n_surveys' encuestas"

    tempfile survey_list
    qui save "`survey_list'"

    * --- Paso 3: Iterar encuestas ---
    di as text "Paso 3: Crawleando encuestas..."

    * Inicializar catalogo vacio
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
    tempfile catalog_building
    qui save "`catalog_building'"

    * Inicializar docs vacio
    clear
    gen str244 category = ""
    gen str100 survey_value = ""
    gen int year = .
    gen str244 period = ""
    gen str244 doc_name = ""
    gen str244 zip_path = ""
    tempfile docs_building
    qui save "`docs_building'"

    local total_modules = 0
    local total_docs = 0
    local delay_ms = round(`delay' * 1000)

    forvalues s = 1/`n_surveys' {
        qui use "`survey_list'", clear
        local sv = opt_value[`s']
        local sl = opt_label[`s']

        if "`survey'" != "" {
            _inei_cat_resolve_alias `survey'
            local survey_filter "`s(resolved)'"
            local sl_lower = strlower("`sl'")
            local sf_lower = strlower("`survey_filter'")
            if strpos("`sl_lower'", "`sf_lower'") == 0 {
                continue
            }
        }

        di as text ""
        di as text "  [`s'/`n_surveys'] `sl'"

        local category "`sl'"

        * --- Obtener anios ---
        _inei_encode "`sv'"
        local sv_encoded "`s(encoded)'"

        local post_data "bandera=1&_cmbEncuesta=`sv_encoded'"
        quietly ! curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/CambiaEnc.asp"
        sleep `delay_ms'

        capture _inei_parse options, file("`tmphtml'")
        capture confirm variable opt_value
        if _rc != 0 {
            di as text "    Error obteniendo anios, saltando..."
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
            if `year_num' == . {
                local year_num = real("`yl'")
            }

            if `year_num' != . {
                if `year_num' < `yearmin' | `year_num' > `yearmax' {
                    continue
                }
            }

            di as text "    Anio `yl'..." _continue

            * --- Obtener periodos ---
            _inei_encode "`sv'"
            local sv_enc "`s(encoded)'"
            _inei_encode "`yv'"
            local yv_enc "`s(encoded)'"

            local post_data "bandera=1&_cmbEncuesta=`sv_enc'&_cmbAnno=`yv_enc'&_cmbEncuesta0=`sv_enc'"
            quietly ! curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/CambiaAnio.asp"
            sleep `delay_ms'

            capture _inei_parse options, file("`tmphtml'")
            capture confirm variable opt_value
            if _rc != 0 {
                di as text " error"
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

                * --- Obtener modulos ---
                _inei_encode "`sv'"
                local sv_e "`s(encoded)'"
                _inei_encode "`yv'"
                local yv_e "`s(encoded)'"
                _inei_encode "`pv'"
                local pv_e "`s(encoded)'"

                local post_data "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbTrimestre=`pv_e'"
                quietly ! curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/cambiaPeriodo.asp"
                sleep `delay_ms'

                capture _inei_parse modules, file("`tmphtml'")
                capture confirm variable module_name
                if _rc != 0 {
                    continue
                }

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

                    qui append using "`catalog_building'"
                    qui save "`catalog_building'", replace

                    local yr_modules = `yr_modules' + `n_mods'
                    local total_modules = `total_modules' + `n_mods'
                }

                * --- Obtener documentacion ---
                quietly ! curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`tmphtml'" "`base_url'/CambiaPeriodoDoc.asp"
                sleep `delay_ms'

                capture _inei_parse docs, file("`tmphtml'")
                capture confirm variable doc_name
                if _rc != 0 {
                    continue
                }

                qui count
                local n_docs_found = r(N)

                if `n_docs_found' > 0 {
                    qui gen str244 category = "`category'"
                    qui gen str100 survey_value = "`sv'"
                    qui gen int year = `year_num'
                    qui gen str244 period = "`pl'"

                    qui append using "`docs_building'"
                    qui save "`docs_building'", replace

                    local total_docs = `total_docs' + `n_docs_found'
                }
            }

            di as text " `yr_modules' modulos"
        }
    }

    * --- Paso 4: Guardar catalogo ---
    di as text ""
    di as text "Paso 4: Guardando catalogo..."

    qui use "`catalog_building'", clear
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

    qui use "`docs_building'", clear
    qui count
    if r(N) > 0 {
        qui drop if category == "" & survey_value == ""
        compress
        sort category year period doc_name
        save "`dest'/inei_docs.dta", replace
        di as text "  Docs:     `dest'/inei_docs.dta (`total_docs' documentos)"
    }

    * Limpiar archivos temporales
    capture erase "`cookiefile'"
    capture erase "`tmphtml'"

    di as text ""
    di as text "{hline 60}"
    di as text "{bf:Crawling completado}"
    di as text "  Modulos:    `total_modules'"
    di as text "  Documentos: `total_docs'"
    di as text "{hline 60}"

    restore
end
