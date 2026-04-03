*! inei_crawl.ado — Crawlear portal INEI para construir/actualizar catalogo
*! version 1.0.8  2026-04-03

program define inei_crawl
    version 14.0
    syntax , [SURVEY(string) YEARMIN(integer 0) YEARMAX(integer 9999) ///
        REFRESH DEST(string) DELAY(real 0.3) DEBUG]

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

    * --- Paso 1 ---
    di as text "Paso 1: Iniciando sesion..."
    quietly ! curl -s -k -L -c "`ck'" -o "`th'" "`base'/Consulta_por_Encuesta.asp?CU=19558"

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

        * Encode survey value via Mata -> write to global
        mata: st_global("_inei_enc_sv", _inei_crawl_encode(st_sdata(`s', "opt_value")))
        local sv_e "${_inei_enc_sv}"

        if "`debug'" != "" {
            di as text "    DEBUG sv_e = `sv_e'"
        }

        * POST para obtener anios
        quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaEnc.asp"
        sleep `dms'

        if "`debug'" != "" {
            qui checksum "`th'"
            di as text "    DEBUG response size = `r(filelen)'"
        }

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

        tempfile ylist
        qui save "`ylist'"

        forvalues y = 1/`ny' {
            qui use "`ylist'", clear
            scalar __yl = opt_label[`y']
            local yl = scalar(__yl)

            mata: st_global("_inei_enc_yv", _inei_crawl_encode(st_sdata(`y', "opt_value")))
            local yv_e "${_inei_enc_yv}"

            local yn = real("`yv_e'")
            if `yn' == . local yn = real("`yl'")
            if `yn' != . {
                if `yn' < `yearmin' | `yn' > `yearmax' {
                    scalar drop __yl
                    continue
                }
            }

            di as text "    `yl'..." _continue

            * POST para periodos
            quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbEncuesta0=`sv_e'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaAnio.asp"
            sleep `dms'

            capture _inei_parse options, file("`th'")
            capture confirm variable opt_value
            if _rc != 0 {
                di as text " sin periodos"
                scalar drop __yl
                continue
            }
            qui drop if opt_value == "" | opt_value == "0"
            qui count
            local np = r(N)
            if `np' == 0 {
                di as text " sin periodos"
                scalar drop __yl
                continue
            }

            tempfile plist
            qui save "`plist'"
            local ym = 0

            forvalues p = 1/`np' {
                qui use "`plist'", clear
                scalar __pl = opt_label[`p']
                local pl = scalar(__pl)

                mata: st_global("_inei_enc_pv", _inei_crawl_encode(st_sdata(`p', "opt_value")))
                local pv_e "${_inei_enc_pv}"

                local pd "bandera=1&_cmbEncuesta=`sv_e'&_cmbAnno=`yv_e'&_cmbTrimestre=`pv_e'"

                * Modulos
                quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "`pd'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/cambiaPeriodo.asp"
                sleep `dms'

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

                * Docs
                quietly ! curl -s -k -L -b "`ck'" -c "`ck'" -X POST -d "`pd'" -H "Content-Type: application/x-www-form-urlencoded" -o "`th'" "`base'/CambiaPeriodoDoc.asp"
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
            scalar drop __yl
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
        qui duplicates drop year period module_name stata_code, force
        qui count
        local total_mod = r(N)
        compress
        sort category year period module_name
        char define _dta[crawl_date] "`c(current_date)'"
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
        qui duplicates drop year period doc_name zip_path, force
        compress
        sort category year period doc_name
        char define _dta[crawl_date] "`c(current_date)'"
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

mata:
/*
    Encode string for INEI portal (JS escape() style).
    Handles both Latin-1 and UTF-8 input:
    - UTF-8 2-byte sequences (0xC2-0xDF + continuation) -> decode to Latin-1 codepoint -> %XX
    - Single high bytes (Latin-1 direct, e.g. 0xE1 for á) -> %XX
    - The key insight: check if byte after a high byte is a UTF-8 continuation (0x80-0xBF)
*/
string scalar _inei_crawl_encode(string scalar s)
{
    string scalar result, hex
    real scalar i, n, b1, b2, cp

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
            // Possible UTF-8 2-byte: check if next is continuation byte
            b2 = ascii(substr(s, i + 1, 1))
            if (b2 >= 128 & b2 <= 191) {
                // Valid UTF-8 2-byte -> decode to codepoint
                cp = (b1 - 192) * 64 + (b2 - 128)
                hex = strupper(inbase(16, cp))
                if (strlen(hex) == 1) hex = "0" + hex
                result = result + "%" + hex
                i = i + 2
            }
            else {
                // Not valid UTF-8, treat b1 as Latin-1 byte
                hex = strupper(inbase(16, b1))
                if (strlen(hex) == 1) hex = "0" + hex
                result = result + "%" + hex
                i++
            }
        }
        else {
            // Any other high byte: treat as Latin-1 directly
            // This handles: Latin-1 bytes like 0xE1 (á), 0xF3 (ó), etc.
            // Also handles UTF-8 3/4-byte starts when input is actually Latin-1
            hex = strupper(inbase(16, b1))
            if (strlen(hex) == 1) hex = "0" + hex
            result = result + "%" + hex
            i++
        }
    }
    return(result)
}
end
