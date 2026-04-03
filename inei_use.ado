*! inei_use.ado — Descargar, descomprimir y cargar modulo INEI en memoria
*! Equivalente a: download ZIP + unzip + use archivo.dta
*! version 1.0.0  2026-04-03

program define inei_use
    version 14.0
    syntax , SURVEY(string) YEAR(integer) MODULE(string) ///
        [CLEAR FORMAT(string) DEST(string) FILE(string) NODOWNLOAD]

    if "`clear'" == "" {
        if c(changed) == 1 {
            di as error "datos en memoria no guardados; use la opcion {bf:clear}"
            exit 4
        }
    }

    if "`format'" == "" local format "STATA"
    local format = strupper("`format'")

    * --- 1. Directorio cache ---
    if "`dest'" == "" {
        local dest "`c(sysdir_personal)'inei_cache"
    }
    capture mkdir "`dest'"

    * --- 2. Buscar modulo en catalogo ---
    preserve

    _inei_cat_load
    _inei_cat_filter, survey(`survey') yearmin(`year') yearmax(`year')

    * Filtrar por modulo
    * Estrategia: exacto en module_code (con/sin ceros) > match en stata_code > parcial en nombre
    local mod_lower = strlower("`module'")

    * Intentar match exacto en module_code (ej: "34" == "34")
    qui gen __modmatch = strlower(module_code) == "`mod_lower'"

    * Match sin ceros iniciales (ej: "01" matches "1")
    local mod_nozero = "`mod_lower'"
    while substr("`mod_nozero'", 1, 1) == "0" & strlen("`mod_nozero'") > 1 {
        local mod_nozero = substr("`mod_nozero'", 2, .)
    }
    qui replace __modmatch = 1 if strlower(module_code) == "`mod_nozero'"

    * Match en stata_code (ej: "01" matches "966-Modulo01")
    qui replace __modmatch = 1 if regexm(strlower(stata_code), ///
        "modulo0*`mod_nozero'$")

    * Solo usar match parcial en nombre si el query NO es numerico
    capture confirm integer number `module'
    if _rc != 0 {
        qui replace __modmatch = 1 if ///
            strpos(strlower(module_name), "`mod_lower'") > 0
    }

    qui keep if __modmatch == 1
    qui drop __modmatch

    qui count
    local n_match = r(N)

    if `n_match' == 0 {
        di as error "No se encontro modulo '`module'' en `survey' `year'"
        di as text ""
        di as text "Use {bf:inei list, survey(`survey') yearmin(`year') modules}"
        di as text "para ver modulos disponibles."
        restore
        exit 111
    }

    * Si hay multiples matches, intentar reducir
    if `n_match' > 1 {
        * Preferir periodo "Anual" si existe
        qui gen __anual = strpos(strlower(period), "anual") > 0
        qui summarize __anual
        if r(max) == 1 {
            qui keep if __anual == 1
        }
        qui drop __anual
        qui count
        local n_match = r(N)
    }

    * Si sigue habiendo multiples, preferir ENAHO Actualizada sobre Anterior
    if `n_match' > 1 {
        qui gen __actual = strpos(strlower(category), "actualizada") > 0
        qui summarize __actual
        if r(max) == 1 & r(min) == 0 {
            qui keep if __actual == 1
        }
        qui drop __actual
        qui count
        local n_match = r(N)
    }

    * Si TODAVIA hay multiples, tomar el primero
    if `n_match' > 1 {
        qui keep in 1
        local n_match = 1
    }

    * Tenemos exactamente 1 match
    local mod_name  = module_name[1]
    local mod_code  = module_code[1]
    local dl_code   = stata_code[1]
    local csv_code  = csv_code[1]
    local spss_code = spss_code[1]
    local category  = category[1]
    local period    = period[1]
    local sv_label  = survey_label[1]

    * Seleccionar codigo de descarga segun formato
    if "`format'" == "STATA" {
        local code "`dl_code'"
        if "`code'" == "" local code "`csv_code'"
        if "`code'" == "" local code "`spss_code'"
    }
    else if "`format'" == "CSV" {
        local code "`csv_code'"
        if "`code'" == "" local code "`dl_code'"
    }
    else if "`format'" == "SPSS" {
        local code "`spss_code'"
        if "`code'" == "" local code "`dl_code'"
    }

    if "`code'" == "" {
        di as error "No hay codigo de descarga disponible para este modulo"
        restore
        exit 601
    }

    restore

    * --- 3. Descargar ZIP (si no esta en cache) ---
    local zipfile "`dest'/`code'.zip"
    local extractdir "`dest'/`code'"

    local base_url "https://proyectos.inei.gob.pe/iinei/srienaho/descarga"
    local url "`base_url'/`format'/`code'.zip"

    if "`nodownload'" == "" {
        capture confirm file "`zipfile'"
        if _rc != 0 {
            di as text "Descargando `code'.zip..."
            capture copy "`url'" "`zipfile'", replace
            if _rc != 0 {
                di as text "Intentando con curl..."
                quietly ! curl -s -k -L --max-time 120 -o "`zipfile'" "`url'"
            }

            capture confirm file "`zipfile'"
            if _rc != 0 {
                di as error "Error descargando: `url'"
                exit 601
            }

            qui checksum "`zipfile'"
            if r(filelen) < 100 {
                di as error "Archivo descargado parece corrupto"
                capture erase "`zipfile'"
                exit 601
            }

            di as text "  Descargado: `zipfile'"
        }
        else {
            di as text "(usando cache: `zipfile')"
        }
    }

    * --- 4. Descomprimir ---
    capture confirm file "`zipfile'"
    if _rc != 0 {
        di as error "ZIP no encontrado: `zipfile'"
        exit 601
    }

    _inei_unzip, zipfile("`zipfile'") destdir("`extractdir'")

    * --- 5. Buscar .dta ---
    _inei_find_dta, dir("`extractdir'") file(`file')
    local dtafile "`s(dtafile)'"

    if "`dtafile'" == "" {
        di as error "No se encontro archivo .dta"
        exit 601
    }

    * --- 6. Cargar en memoria ---
    di as text "Cargando: `dtafile'"
    use "`dtafile'", `clear'

    * --- 7. Estampar metadata ---
    char define _dta[inei_survey]        "`sv_label'"
    char define _dta[inei_category]      "`category'"
    char define _dta[inei_year]          "`year'"
    char define _dta[inei_module_code]   "`mod_code'"
    char define _dta[inei_module_name]   "`mod_name'"
    char define _dta[inei_period]        "`period'"
    char define _dta[inei_download_code] "`code'"
    char define _dta[inei_source_url]    "`url'"
    char define _dta[inei_download_date] "`c(current_date)'"
    char define _dta[inei_format]        "`format'"

    * Resumen
    di as text ""
    di as text "{bf:INEI Microdatos cargados}"
    di as text "  Encuesta:  `sv_label'"
    di as text "  Modulo:    `mod_name' [`mod_code']"
    di as text "  Anio:      `year'"
    di as text "  Periodo:   `period'"
    di as text "  Obs:       " as result c(N) as text "  Variables: " as result c(k)
    di as text ""
end

mata:
void _inei_show_module_matches(real scalar n)
{
    real scalar i
    string scalar mc, mn, cat

    for (i = 1; i <= n; i++) {
        mc  = st_sdata(i, "module_code")
        mn  = st_sdata(i, "module_name")
        cat = st_sdata(i, "category")
        printf("  %s  %s (%s)\n", mc, mn, cat)
    }
}
end
