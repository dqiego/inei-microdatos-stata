*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! Navega la interfaz AJAX del portal para extraer todas las encuestas,
*! anios, periodos, modulos y documentacion
*! version 1.0.0  2026-04-02

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
    di as text "{hline 60}"
    di as text ""

    * Verificar que curl esta disponible
    capture shell curl --version > /dev/null 2>&1
    if _rc != 0 {
        di as error "Error: curl es requerido para crawlear el portal."
        di as error "Instale curl: https://curl.se/download.html"
        exit 601
    }

    * --- Paso 1: Iniciar sesion ---
    di as text "Paso 1: Iniciando sesion con el portal..."

    tempfile cookiefile inithtml
    local base_url "https://proyectos.inei.gob.pe/microdatos"

    shell curl -s -k -L -c "`cookiefile'" -o "`inithtml'" "`base_url'/Consulta_por_Encuesta.asp?CU=19558"

    capture confirm file "`inithtml'"
    if _rc != 0 {
        di as error "Error: no se pudo conectar al portal INEI"
        exit 601
    }

    * --- Paso 2: Extraer lista de encuestas ---
    di as text "Paso 2: Extrayendo lista de encuestas..."

    preserve
    _inei_parse surveys, file(`inithtml')

    * Remover primera opcion si es "Seleccionar..."
    qui drop if opt_value == "" | opt_value == "0"

    qui count
    local n_surveys = r(N)
    di as text "  Encontradas: `n_surveys' encuestas"

    * Guardar lista de encuestas
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

    * Iterar cada encuesta
    forvalues s = 1/`n_surveys' {
        qui use "`survey_list'", clear
        local sv = opt_value[`s']
        local sl = opt_label[`s']

        * Filtrar por encuesta si se especifico
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

        * Determinar categoria (para ENAHO split)
        local category "`sl'"

        * --- Obtener anios ---
        tempfile years_html
        _inei_encode "`sv'"
        local sv_encoded "`s(encoded)'"

        local post_data "bandera=1&_cmbEncuesta=`sv_encoded'"
        shell curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`years_html'" "`base_url'/CambiaEnc.asp"
        sleep `= round(`delay' * 1000)'

        _inei_parse options, file(`years_html')
        qui drop if opt_value == "" | opt_value == "0"

        qui count
        local n_years = r(N)

        if `n_years' == 0 {
            di as text "    Sin anios disponibles"
            continue
        }

        tempfile year_list
        qui save "`year_list'"

        * --- Iterar anios ---
        forvalues y = 1/`n_years' {
            qui use "`year_list'", clear
            local yv = opt_value[`y']
            local yl = opt_label[`y']

            * Extraer anio numerico
            local year_num = real("`yv'")
            if `year_num' == . {
                local year_num = real("`yl'")
            }

            * Filtrar por rango de anios
            if `year_num' != . {
                if `year_num' < `yearmin' | `year_num' > `yearmax' {
                    continue
                }
            }

            di as text "    Anio `yl'..." _continue

            * --- Obtener periodos ---
            tempfile periods_html
            _inei_encode "`sv'"
            local sv_enc "`s(encoded)'"
            _inei_encode "`yv'"
            local yv_enc "`s(encoded)'"

            local post_data "bandera=1&_cmbEncuesta=`sv_enc'&_cmbAnno=`yv_enc'&_cmbEncuesta0=`sv_enc'"
            shell curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`periods_html'" "`base_url'/CambiaAnio.asp"
            sleep `= round(`delay' * 1000)'

            _inei_parse options, file(`periods_html')
            qui drop if opt_value == "" | opt_value == "0"

            qui count
            local n_periods = r(N)

            if `n_periods' == 0 {
                di as text " sin periodos"
                continue
            }

            tempfile period_list
            qui save "`period_list'"

            * --- Iterar periodos ---
            local yr_modules = 0

            forvalues p = 1/`n_periods' {
                qui use "`period_list'", clear
                local pv = opt_value[`p']
                local pl = opt_label[`p']

                * --- Obtener modulos ---
                tempfile modules_html
                _inei_encode "`sv'"
                local sv_e "`s(encoded)'"
                _inei_encode "`yv'"
                local yv_e "`s(encoded)'"
                _inei_encode "`pv'"
                local pv_e "`s(encoded)'"

                local post_data "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbTrimestre=`pv_e'"
                shell curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`modules_html'" "`base_url'/cambiaPeriodo.asp"
                sleep `= round(`delay' * 1000)'

                _inei_parse modules, file(`modules_html')

                qui count
                local n_mods = r(N)

                if `n_mods' > 0 {
                    * Agregar metadata
                    qui gen str244 category = "`category'"
                    qui gen str100 survey_value = "`sv'"
                    qui gen str244 survey_label = "`sl'"
                    qui gen int year = `year_num'
                    qui gen str244 period = "`pl'"
                    qui gen str100 period_value = "`pv'"

                    * Generar module_code desde los codigos de descarga
                    qui gen str100 module_code = ""
                    qui replace module_code = regexs(2) ///
                        if regexm(stata_code, "^([0-9]+)-Modulo(.+)$")

                    * Append al catalogo
                    qui append using "`catalog_building'"
                    qui save "`catalog_building'", replace

                    local yr_modules = `yr_modules' + `n_mods'
                    local total_modules = `total_modules' + `n_mods'
                }

                * --- Obtener documentacion ---
                tempfile docs_html
                shell curl -s -k -L -b "`cookiefile'" -c "`cookiefile'" -X POST -d "`post_data'" -H "Content-Type: application/x-www-form-urlencoded" -o "`docs_html'" "`base_url'/CambiaPeriodoDoc.asp"
                sleep `= round(`delay' * 1000)'

                _inei_parse docs, file(`docs_html')

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

    di as text ""
    di as text "{hline 60}"
    di as text "{bf:Crawling completado}"
    di as text "  Modulos:    `total_modules'"
    di as text "  Documentos: `total_docs'"
    di as text "{hline 60}"

    restore
end
