*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! version 1.0.6  2026-04-03

program define inei_crawl
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        REFRESH DEST(string) DELAY(real 0.3)]

    if "`dest'" == "" {
        _inei_find_data_dir
        local dest "`s(datadir)'"
    }

    capture mkdir "`dest'"

    local ck "`c(tmpdir)'/inei_ck.txt"
    local th "`c(tmpdir)'/inei_th.html"
    local base "https://proyectos.inei.gob.pe/microdatos"

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
    _inei_curl, cmd(`"curl -s -k -L -c "`ck'" -o "`th'" "`base'/Consulta_por_Encuesta.asp?CU=19558""')

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

        * Usar scalar para proteger strings con chars especiales
        scalar __sv = opt_value[`s']
        scalar __sl = opt_label[`s']
        local sl = scalar(__sl)

        if "`survey'" != "" {
            _inei_cat_resolve_alias `survey'
            local sf = strlower("`s(resolved)'")
            if strpos(strlower("`sl'"), "`sf'") == 0 {
                scalar drop __sv __sl
                continue
            }
        }

        di as text ""
        di as text "  [`s'/`n_surveys'] `sl'"

        * Encode via Mata (lee scalar directamente)
        mata: _inei_js_escape(st_strscalar("__sv"))
        local sv_e "${_inei_encoded}"
        macro drop _inei_encoded

        * GET years
        _inei_curl, cmd(`"curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaEnc.asp""') delay(`dms')

        capture _inei_parse options, file("`th'")
        capture confirm variable opt_value
        if _rc != 0 {
            di as text "    Sin anios"
            scalar drop __sv __sl
            continue
        }
        qui drop if opt_value == "" | opt_value == "0"
        qui count
        local ny = r(N)
        if `ny' == 0 {
            di as text "    Sin anios"
            scalar drop __sv __sl
            continue
        }

        tempfile ylist
        qui save "`ylist'"

        forvalues y = 1/`ny' {
            qui use "`ylist'", clear
            scalar __yv = opt_value[`y']
            scalar __yl = opt_label[`y']
            local yl = scalar(__yl)
            local yn = real(scalar(__yv))
            if `yn' == . local yn = real("`yl'")
            if `yn' != . {
                if `yn' < `yearmin' | `yn' > `yearmax' {
                    scalar drop __yv __yl
                    continue
                }
            }

            di as text "    `yl'..." _continue

            * Encode year value
            mata: _inei_js_escape(st_strscalar("__yv"))
            local yv_e "${_inei_encoded}"
            macro drop _inei_encoded

            * GET periods
            _inei_curl, cmd(`"curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbEncuesta0=`sv_e'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaAnio.asp""') delay(`dms')

            capture _inei_parse options, file("`th'")
            capture confirm variable opt_value
            if _rc != 0 {
                di as text " sin periodos"
                scalar drop __yv __yl
                continue
            }
            qui drop if opt_value == "" | opt_value == "0"
            qui count
            local np = r(N)
            if `np' == 0 {
                di as text " sin periodos"
                scalar drop __yv __yl
                continue
            }

            tempfile plist
            qui save "`plist'"
            local ym = 0

            forvalues p = 1/`np' {
                qui use "`plist'", clear
                scalar __pv = opt_value[`p']
                scalar __pl = opt_label[`p']
                local pl = scalar(__pl)

                * Encode period value
                mata: _inei_js_escape(st_strscalar("__pv"))
                local pv_e "${_inei_encoded}"
                macro drop _inei_encoded

                local pd "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbTrimestre=`pv_e'"

                * GET modules
                _inei_curl, cmd(`"curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "`pd'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/cambiaPeriodo.asp""') delay(`dms')

                capture _inei_parse modules, file("`th'")
                capture confirm variable module_name
                if _rc == 0 {
                    qui count
                    local nm = r(N)
                    if `nm' > 0 {
                        qui gen str244 category = "`sl'"
                        scalar __svstr = scalar(__sv)
                        qui gen str100 survey_value = scalar(__svstr)
                        qui gen str244 survey_label = "`sl'"
                        qui gen int year = `yn'
                        qui gen str244 period = "`pl'"
                        qui gen str100 period_value = scalar(__pv)
                        qui gen str100 module_code = ""
                        capture qui replace module_code = regexs(2) ///
                            if regexm(stata_code, "^([0-9]+)-Modulo(.+)$")
                        qui append using "`cat_build'"
                        qui save "`cat_build'", replace
                        local ym = `ym' + `nm'
                        local total_mod = `total_mod' + `nm'
                        scalar drop __svstr
                    }
                }

                * GET docs
                _inei_curl, cmd(`"curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "`pd'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaPeriodoDoc.asp""') delay(`dms')

                capture _inei_parse docs, file("`th'")
                capture confirm variable doc_name
                if _rc == 0 {
                    qui count
                    local nd = r(N)
                    if `nd' > 0 {
                        qui gen str244 category = "`sl'"
                        qui gen str100 survey_value = scalar(__sv)
                        qui gen int year = `yn'
                        qui gen str244 period = "`pl'"
                        qui append using "`doc_build'"
                        qui save "`doc_build'", replace
                        local total_doc = `total_doc' + `nd'
                    }
                }

                scalar drop __pv __pl
            }

            di as text " `ym' modulos"
            scalar drop __yv __yl
        }

        scalar drop __sv __sl
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
