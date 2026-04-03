*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! version 1.0.5  2026-04-02

program define inei_crawl
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        REFRESH DEST(string) DELAY(real 0.3)]

    if "`dest'" == "" {
        _inei_find_data_dir
        local dest "`s(datadir)'"
    }

    capture mkdir "`dest'"

    * Usar rutas cortas fijas en TEMP (sin espacios)
    local ck "`c(tmpdir)'/inei_ck.txt"
    local th "`c(tmpdir)'/inei_th.html"
    local base "https://proyectos.inei.gob.pe/microdatos"

    * Limpiar archivos previos
    capture erase "`ck'"
    capture erase "`th'"

    di as text ""
    di as text "{bf:Crawling portal INEI de microdatos}"
    di as text "{hline 60}"
    di as text "  Destino: `dest'"
    di as text "{hline 60}"
    di as text ""

    * --- Paso 1: Sesion ---
    di as text "Paso 1: Iniciando sesion..."
    quietly ! curl -s -k -L -c "`ck'" -o "`th'" "`base'/Consulta_por_Encuesta.asp?CU=19558"

    capture confirm file "`th'"
    if _rc != 0 {
        di as error "Error: no se pudo conectar al portal INEI"
        exit 601
    }

    * --- Paso 2: Encuestas ---
    di as text "Paso 2: Extrayendo encuestas..."

    preserve
    capture _inei_parse surveys, file("`th'")
    capture confirm variable opt_value
    if _rc != 0 {
        di as error "Error: no se pudieron extraer encuestas"
        restore
        exit 601
    }

    qui drop if opt_value == "" | opt_value == "0"
    qui count
    local n_surveys = r(N)
    di as text "  `n_surveys' encuestas encontradas"

    tempfile survey_list
    qui save "`survey_list'"

    * --- Paso 3: Iterar ---
    di as text "Paso 3: Crawleando..."

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
    tempfile cat_build
    qui save "`cat_build'"

    clear
    gen str244 category = ""
    gen str100 survey_value = ""
    gen int year = .
    gen str244 period = ""
    gen str244 doc_name = ""
    gen str244 zip_path = ""
    tempfile doc_build
    qui save "`doc_build'"

    local total_mod = 0
    local total_doc = 0
    local dms = round(`delay' * 1000)

    forvalues s = 1/`n_surveys' {
        qui use "`survey_list'", clear
        local sv = opt_value[`s']
        local sl = opt_label[`s']

        if "`survey'" != "" {
            _inei_cat_resolve_alias `survey'
            local sf = strlower("`s(resolved)'")
            if strpos(strlower("`sl'"), "`sf'") == 0 continue
        }

        di as text ""
        di as text "  [`s'/`n_surveys'] `sl'"

        * Encode survey value
        _inei_encode "`sv'"
        local sv_e "`s(encoded)'"

        * GET years
        quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaEnc.asp"
        sleep `dms'

        capture _inei_parse options, file("`th'")
        capture confirm variable opt_value
        if _rc != 0 {
            di as text "    Sin anios"
            continue
        }
        qui drop if opt_value == "" | opt_value == "0"
        qui count
        local ny = r(N)
        if `ny' == 0 {
            di as text "    Sin anios"
            continue
        }

        tempfile ylist
        qui save "`ylist'"

        forvalues y = 1/`ny' {
            qui use "`ylist'", clear
            local yv = opt_value[`y']
            local yl = opt_label[`y']
            local yn = real("`yv'")
            if `yn' == . local yn = real("`yl'")
            if `yn' != . {
                if `yn' < `yearmin' | `yn' > `yearmax' continue
            }

            di as text "    `yl'..." _continue

            _inei_encode "`sv'"
            local sv2 "`s(encoded)'"
            _inei_encode "`yv'"
            local yv2 "`s(encoded)'"

            * GET periods
            quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "bandera=1&_cmbEncuesta=`sv2'&_cmbAnno=`yv2'&_cmbEncuesta0=`sv2'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaAnio.asp"
            sleep `dms'

            capture _inei_parse options, file("`th'")
            capture confirm variable opt_value
            if _rc != 0 {
                di as text " sin periodos"
                continue
            }
            qui drop if opt_value == "" | opt_value == "0"
            qui count
            local np = r(N)
            if `np' == 0 {
                di as text " sin periodos"
                continue
            }

            tempfile plist
            qui save "`plist'"
            local ym = 0

            forvalues p = 1/`np' {
                qui use "`plist'", clear
                local pv = opt_value[`p']
                local pl = opt_label[`p']

                _inei_encode "`sv'"
                local sv3 "`s(encoded)'"
                _inei_encode "`yv'"
                local yv3 "`s(encoded)'"
                _inei_encode "`pv'"
                local pv3 "`s(encoded)'"

                local pd "bandera=1&_cmbEncuesta=`sv3'&_cmbAnno=`yv3'&_cmbTrimestre=`pv3'"

                * GET modules
                quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "`pd'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/cambiaPeriodo.asp"
                sleep `dms'

                capture _inei_parse modules, file("`th'")
                capture confirm variable module_name
                if _rc == 0 {
                    qui count
                    local nm = r(N)
                    if `nm' > 0 {
                        qui gen str244 category = "`sl'"
                        qui gen str100 survey_value = "`sv'"
                        qui gen str244 survey_label = "`sl'"
                        qui gen int year = `yn'
                        qui gen str244 period = "`pl'"
                        qui gen str100 period_value = "`pv'"
                        qui gen str100 module_code = ""
                        capture qui replace module_code = regexs(2) ///
                            if regexm(stata_code, "^([0-9]+)-Modulo(.+)$")
                        qui append using "`cat_build'"
                        qui save "`cat_build'", replace
                        local ym = `ym' + `nm'
                        local total_mod = `total_mod' + `nm'
                    }
                }

                * GET docs
                quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "`pd'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaPeriodoDoc.asp"
                sleep `dms'

                capture _inei_parse docs, file("`th'")
                capture confirm variable doc_name
                if _rc == 0 {
                    qui count
                    local nd = r(N)
                    if `nd' > 0 {
                        qui gen str244 category = "`sl'"
                        qui gen str100 survey_value = "`sv'"
                        qui gen int year = `yn'
                        qui gen str244 period = "`pl'"
                        qui append using "`doc_build'"
                        qui save "`doc_build'", replace
                        local total_doc = `total_doc' + `nd'
                    }
                }
            }

            di as text " `ym' modulos"
        }
    }

    * --- Paso 4: Guardar ---
    di as text ""
    di as text "Paso 4: Guardando..."

    qui use "`cat_build'", clear
    qui count
    if r(N) > 0 {
        qui drop if category == "" & survey_value == ""
        compress
        sort category year period module_name
        save "`dest'/inei_catalog.dta", replace
        di as text "  `dest'/inei_catalog.dta (`total_mod' modulos)"
    }
    else {
        di as error "  No se encontraron modulos"
    }

    qui use "`doc_build'", clear
    qui count
    if r(N) > 0 {
        qui drop if category == "" & survey_value == ""
        compress
        sort category year period doc_name
        save "`dest'/inei_docs.dta", replace
        di as text "  `dest'/inei_docs.dta (`total_doc' docs)"
    }

    capture erase "`ck'"
    capture erase "`th'"

    di as text ""
    di as text "{hline 60}"
    di as text "{bf:Completado:} `total_mod' modulos, `total_doc' docs"
    di as text "{hline 60}"

    restore
end
