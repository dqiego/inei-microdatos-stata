*! _inei_find_dta.ado — Buscar archivos .dta dentro de un directorio extraido
*! Devuelve la ruta del .dta encontrado. Si hay multiples, lista y pide elegir.
*! version 1.0.0  2026-04-03

program define _inei_find_dta, sclass
    syntax , DIR(string) [FILE(string)]

    * Buscar .dta recursivamente usando Mata
    mata: _inei_search_dta("`dir'")

    local n_dta ${__inei_n_dta}
    macro drop __inei_n_dta

    if `n_dta' == 0 {
        di as error "No se encontraron archivos .dta en: `dir'"
        exit 601
    }

    * Si el usuario especifico un archivo
    if "`file'" != "" {
        * Buscar match parcial
        local file_lower = strlower("`file'")
        forvalues i = 1/`n_dta' {
            local dta_path "${__inei_dta_`i'}"
            local dta_name = strlower("`dta_path'")
            if strpos("`dta_name'", "`file_lower'") > 0 {
                sreturn local dtafile "`dta_path'"
                _inei_find_dta_cleanup `n_dta'
                exit
            }
        }
        di as error "No se encontro .dta con nombre: `file'"
        di as text "Archivos disponibles:"
        forvalues i = 1/`n_dta' {
            di as text "  `i'. ${__inei_dta_`i'}"
        }
        _inei_find_dta_cleanup `n_dta'
        exit 111
    }

    * Si hay exactamente 1 .dta
    if `n_dta' == 1 {
        sreturn local dtafile "${__inei_dta_1}"
        _inei_find_dta_cleanup `n_dta'
        exit
    }

    * Multiples .dta — preferir el de nombre mas corto (archivo principal)
    local best_i = 1
    local best_len = strlen("${__inei_dta_1}")
    forvalues i = 2/`n_dta' {
        local this_len = strlen("${__inei_dta_`i'}")
        if `this_len' < `best_len' {
            local best_i = `i'
            local best_len = `this_len'
        }
    }

    di as text ""
    di as text "Se encontraron `n_dta' archivos .dta:"
    forvalues i = 1/`n_dta' {
        if `i' == `best_i' {
            di as result "  `i'. ${__inei_dta_`i'} (seleccionado)"
        }
        else {
            di as text "  `i'. ${__inei_dta_`i'}"
        }
    }
    di as text ""
    di as text "Use la opcion {bf:file(nombre)} para elegir otro."

    * Devolver el de nombre mas corto
    sreturn local dtafile "${__inei_dta_`best_i'}"
    sreturn local n_dta "`n_dta'"
    _inei_find_dta_cleanup `n_dta'
end

program define _inei_find_dta_cleanup
    args n
    forvalues i = 1/`n' {
        macro drop __inei_dta_`i'
    }
end

mata:
void _inei_search_dta(string scalar basedir)
{
    string colvector files
    string scalar dir, normalized
    real scalar i, count

    // Normalizar separadores
    normalized = subinstr(basedir, "\", "/")

    // Buscar .dta recursivamente
    files = _inei_find_files_recursive(normalized, ".dta")

    count = length(files)
    st_global("__inei_n_dta", strofreal(count))

    for (i = 1; i <= count; i++) {
        st_global("__inei_dta_" + strofreal(i), files[i])
    }
}

string colvector _inei_find_files_recursive(string scalar basedir, string scalar ext)
{
    string colvector result, subfiles
    string scalar entry, fullpath
    real scalar i

    result = J(0, 1, "")

    // Listar archivos en directorio
    entry = ""
    i = 0
    while (1) {
        if (i == 0) {
            entry = dir(basedir, "files", "*" + ext)
        }
        else {
            entry = dir(basedir, "files", "*" + ext, i)
        }

        // dir() returns all matches at once as a column vector
        break
    }

    // Usar dir() correctamente: devuelve un colvector de strings
    string colvector allfiles, alldirs

    allfiles = dir(basedir, "files", "*")
    alldirs = dir(basedir, "dirs", "*")

    // Buscar .dta en archivos del directorio actual
    for (i = 1; i <= length(allfiles); i++) {
        if (strlen(allfiles[i]) >= strlen(ext)) {
            if (strlower(substr(allfiles[i], strlen(allfiles[i]) - strlen(ext) + 1, .)) == strlower(ext)) {
                result = result \ (basedir + "/" + allfiles[i])
            }
        }
    }

    // Recursion en subdirectorios
    for (i = 1; i <= length(alldirs); i++) {
        if (alldirs[i] != "." & alldirs[i] != "..") {
            subfiles = _inei_find_files_recursive(basedir + "/" + alldirs[i], ext)
            if (length(subfiles) > 0) {
                result = result \ subfiles
            }
        }
    }

    return(result)
}
end
