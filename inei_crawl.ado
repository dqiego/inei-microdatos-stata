*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! version 1.0.7  2026-04-03

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
    local bf "`c(tmpdir)'/inei_cmd.bat"
    local base "https://proyectos.inei.gob.pe/microdatos"

    capture erase "`ck'"
    capture erase "`th'"

    di as text ""
    di as text "{bf:Crawling portal INEI de microdatos}"
    di as text "{hline 60}"
    di as text "  Destino: `dest'"
    di as text "{hline 60}"
    di as text ""

    * --- Paso 1 ---
    di as text "Paso 1: Iniciando sesion..."
    mata: _inei_run_curl("`bf'", "`ck'", "`th'", ///
        "GET", "`base'/Consulta_por_Encuesta.asp?CU=19558", "")

    capture confirm file "`th'"
    if _rc != 0 {
        di as error "Error: no se pudo conectar"
        exit 601
    }

    * --- Paso 2 ---
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

    * --- Paso 3 ---
    di as text "Paso 3: Crawleando..."

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
        scalar __sl = opt_label[`s']
        local sl = scalar(__sl)

        if "`survey'" != "" {
            _inei_cat_resolve_alias `survey'
            local sf = strlower("`s(resolved)'")
            if strpos(strlower("`sl'"), "`sf'") == 0 {
                scalar drop __sl
                continue
            }
        }

        di as text ""
        di as text "  [`s'/`n_surveys'] `sl'"

        * Encode survey value via Mata y hacer POST
        mata: _inei_crawl_post("`bf'", "`ck'", "`th'", "`base'", ///
            "CambiaEnc.asp", "bandera=1&_cmbEncuesta=", `s', "opt_value")
        sleep `dms'

        capture _inei_parse options, file("`th'")
        capture confirm variable opt_value
        if _rc != 0 {
            di as text "    Sin anios"
            scalar drop __sl
            continue
        }
        qui drop if opt_value == "" | opt_value == "0"
        qui count
        local ny = r(N)
        if `ny' == 0 {
            di as text "    Sin anios"
            scalar drop __sl
            continue
        }

        * Guardar encoded survey value para reuso
        local sv_e "${_inei_enc_sv}"

        tempfile ylist
        qui save "`ylist'"

        forvalues y = 1/`ny' {
            qui use "`ylist'", clear
            scalar __yl = opt_label[`y']
            local yl = scalar(__yl)
            scalar __yv = opt_value[`y']
            local yn = real(scalar(__yv))
            if `yn' == . local yn = real("`yl'")
            if `yn' != . {
                if `yn' < `yearmin' | `yn' > `yearmax' {
                    scalar drop __yl __yv
                    continue
                }
            }

            di as text "    `yl'..." _continue

            * Encode year y hacer POST para periodos
            mata: _inei_crawl_post2("`bf'", "`ck'", "`th'", "`base'", ///
                "CambiaAnio.asp", "`sv_e'", `y', "opt_value")
            sleep `dms'

            capture _inei_parse options, file("`th'")
            capture confirm variable opt_value
            if _rc != 0 {
                di as text " sin periodos"
                scalar drop __yl __yv
                continue
            }
            qui drop if opt_value == "" | opt_value == "0"
            qui count
            local np = r(N)
            if `np' == 0 {
                di as text " sin periodos"
                scalar drop __yl __yv
                continue
            }

            local yv_e "${_inei_enc_yv}"
            tempfile plist
            qui save "`plist'"
            local ym = 0

            forvalues p = 1/`np' {
                qui use "`plist'", clear

                * Encode period y hacer POST para modulos
                mata: _inei_crawl_post3("`bf'", "`ck'", "`th'", "`base'", ///
                    "cambiaPeriodo.asp", "`sv_e'", "`yv_e'", `p', "opt_value")
                sleep `dms'

                local pv_e "${_inei_enc_pv}"
                scalar __pl = opt_label[`p']
                local pl = scalar(__pl)

                capture _inei_parse modules, file("`th'")
                capture confirm variable module_name
                if _rc == 0 {
                    qui count
                    local nm = r(N)
                    if `nm' > 0 {
                        qui gen str244 category = "`sl'"
                        qui gen str100 survey_value = ""
                        qui gen str244 survey_label = "`sl'"
                        qui gen int year = `yn'
                        qui gen str244 period = "`pl'"
                        qui gen str100 period_value = ""
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
                mata: _inei_crawl_post3("`bf'", "`ck'", "`th'", "`base'", ///
                    "CambiaPeriodoDoc.asp", "`sv_e'", "`yv_e'", `p', "opt_value")
                sleep `dms'

                capture _inei_parse docs, file("`th'")
                capture confirm variable doc_name
                if _rc == 0 {
                    qui count
                    local nd = r(N)
                    if `nd' > 0 {
                        qui gen str244 category = "`sl'"
                        qui gen str100 survey_value = ""
                        qui gen int year = `yn'
                        qui gen str244 period = "`pl'"
                        qui append using "`doc_build'"
                        qui save "`doc_build'", replace
                        local total_doc = `total_doc' + `nd'
                    }
                }

                scalar drop __pl
            }

            di as text " `ym' modulos"
            scalar drop __yl __yv
        }

        scalar drop __sl
    }

    * --- Paso 4 ---
    di as text ""
    di as text "Paso 4: Guardando..."

    qui use "`cat_build'", clear
    qui count
    if r(N) > 0 {
        qui drop if category == "" & module_name == ""
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
        qui drop if category == "" & doc_name == ""
        compress
        sort category year period doc_name
        save "`dest'/inei_docs.dta", replace
        di as text "  `dest'/inei_docs.dta (`total_doc' docs)"
    }

    capture erase "`ck'"
    capture erase "`th'"
    capture erase "`bf'"

    di as text ""
    di as text "{hline 60}"
    di as text "{bf:Completado:} `total_mod' modulos, `total_doc' docs"
    di as text "{hline 60}"

    restore
end

* ================================================================
* MATA: todas las funciones de crawl en un solo bloque
* ================================================================
mata:

/* JS-style URL encode para Latin-1 */
string scalar _inei_crawl_encode(string scalar s)
{
    string scalar result, hex
    real scalar i, n, b1, b2, b3, cp

    result = ""
    n = strlen(s)
    i = 1

    while (i <= n) {
        b1 = ascii(substr(s, i, 1))

        if ((b1 >= 65 & b1 <= 90) | (b1 >= 97 & b1 <= 122) |
            (b1 >= 48 & b1 <= 57) |
            b1 == 64 | b1 == 42 | b1 == 95 | b1 == 43 |
            b1 == 45 | b1 == 46 | b1 == 47) {
            result = result + substr(s, i, 1)
            i++
        }
        else if (b1 == 32) {
            result = result + "%20"
            i++
        }
        else if (b1 < 128) {
            hex = strupper(inbase(16, b1))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i++
        }
        else if (b1 >= 192 & b1 <= 223 & i + 1 <= n) {
            b2 = ascii(substr(s, i + 1, 1))
            cp = (b1 - 192) * 64 + (b2 - 128)
            hex = strupper(inbase(16, cp))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i = i + 2
        }
        else if (b1 >= 224 & b1 <= 239 & i + 2 <= n) {
            b2 = ascii(substr(s, i + 1, 1))
            b3 = ascii(substr(s, i + 2, 1))
            cp = (b1 - 224) * 4096 + (b2 - 128) * 64 + (b3 - 128)
            hex = strupper(inbase(16, cp))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i = i + 3
        }
        else {
            hex = strupper(inbase(16, b1))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i++
        }
    }
    return(result)
}

/* Write bat file and execute curl */
void _inei_run_curl(string scalar bf, string scalar ck, string scalar th,
    string scalar method, string scalar url, string scalar postdata)
{
    real scalar fh

    unlink(bf)
    fh = fopen(bf, "w")
    fput(fh, "@echo off")
    if (method == "GET") {
        fput(fh, `"curl -s -k -L -c ""' + ck + `"" -o ""' + th + `"" ""' + url + `"""')
    }
    else {
        fput(fh, `"curl -s -k -L -b ""' + ck + `"" -c ""' + ck + `"" -X POST -d ""' + postdata + `"" -H "Content-Type: application/x-www-form-urlencoded" -o ""' + th + `"" ""' + url + `"""')
    }
    fclose(fh)

    stata(`"quietly ! cmd.exe /c ""' + bf + `"""')
}

/* POST with encoded survey value from obs */
void _inei_crawl_post(string scalar bf, string scalar ck, string scalar th,
    string scalar base, string scalar endpoint,
    string scalar param_prefix,
    real scalar obs, string scalar varname)
{
    string scalar val, encoded, postdata, url

    val = st_sdata(obs, varname)
    encoded = _inei_crawl_encode(val)

    st_global("_inei_enc_sv", encoded)

    postdata = param_prefix + encoded
    url = base + "/" + endpoint

    _inei_run_curl(bf, ck, th, "POST", url, postdata)
}

/* POST for periods (needs encoded survey + year) */
void _inei_crawl_post2(string scalar bf, string scalar ck, string scalar th,
    string scalar base, string scalar endpoint,
    string scalar sv_enc,
    real scalar obs, string scalar varname)
{
    string scalar val, encoded, postdata, url

    val = st_sdata(obs, varname)
    encoded = _inei_crawl_encode(val)

    st_global("_inei_enc_yv", encoded)

    postdata = "bandera=1&_cmbEncuesta=" + sv_enc + "&_cmbAnno=" + encoded + "&_cmbEncuesta0=" + sv_enc
    url = base + "/" + endpoint

    _inei_run_curl(bf, ck, th, "POST", url, postdata)
}

/* POST for modules/docs (needs encoded survey + year + period) */
void _inei_crawl_post3(string scalar bf, string scalar ck, string scalar th,
    string scalar base, string scalar endpoint,
    string scalar sv_enc, string scalar yv_enc,
    real scalar obs, string scalar varname)
{
    string scalar val, encoded, postdata, url

    val = st_sdata(obs, varname)
    encoded = _inei_crawl_encode(val)

    st_global("_inei_enc_pv", encoded)

    postdata = "bandera=1&_cmbEncuesta=" + sv_enc + "&_cmbAnno=" + yv_enc + "&_cmbTrimestre=" + encoded
    url = base + "/" + endpoint

    _inei_run_curl(bf, ck, th, "POST", url, postdata)
}

end
