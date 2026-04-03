*! _inei_find_data_dir.ado — Encontrar directorio de datos del paquete
*! version 1.0.2  2026-04-02

program define _inei_find_data_dir, sclass

    * Estrategia 1: buscar junto al .ado instalado
    capture findfile inei.ado
    if _rc == 0 {
        local ado_path "`r(fn)'"
        * Extraer directorio: quitar "inei.ado" del final
        mata: st_local("ado_dir", pathbasename(pathjoin(pathsubsysdir(st_local("ado_path")), "")))

        * Metodo robusto: usar Mata para obtener el directorio
        mata: _inei_get_parent_dir(st_local("ado_path"))
        local ado_dir "`s(parent_dir)'"

        local datadir "`ado_dir'/data"

        capture confirm file "`datadir'/inei_catalog.dta"
        if _rc == 0 {
            sreturn local datadir "`datadir'"
            exit
        }
        capture confirm file "`datadir'/inei_catalog.csv"
        if _rc == 0 {
            sreturn local datadir "`datadir'"
            exit
        }
    }

    * Estrategia 2: buscar en PLUS/i/data/ (donde net install pone archivos)
    local plus_dir "`c(sysdir_plus)'"
    local try_dirs "`plus_dir'i/data" "`plus_dir'data" "`plus_dir'_i/data"

    foreach dir of local try_dirs {
        capture confirm file "`dir'/inei_catalog.dta"
        if _rc == 0 {
            sreturn local datadir "`dir'"
            exit
        }
        capture confirm file "`dir'/inei_catalog.csv"
        if _rc == 0 {
            sreturn local datadir "`dir'"
            exit
        }
    }

    * Estrategia 3: buscar con findfile directamente
    capture findfile inei_catalog.dta
    if _rc == 0 {
        mata: _inei_get_parent_dir(st_local("r(fn)"))
        sreturn local datadir "`s(parent_dir)'"
        exit
    }
    capture findfile inei_catalog.csv
    if _rc == 0 {
        mata: _inei_get_parent_dir("`r(fn)'")
        sreturn local datadir "`s(parent_dir)'"
        exit
    }

    * Estrategia 4: directorio actual
    capture confirm file "data/inei_catalog.dta"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }
    capture confirm file "data/inei_catalog.csv"
    if _rc == 0 {
        sreturn local datadir "data"
        exit
    }

    * No encontrado
    sreturn local datadir "data"
end

mata:
void _inei_get_parent_dir(string scalar filepath)
{
    string scalar dir
    real scalar last_sep

    dir = filepath
    // Normalizar separadores
    dir = subinstr(dir, "\", "/")

    // Encontrar ultimo /
    last_sep = 0
    real scalar i
    for (i = strlen(dir); i >= 1; i--) {
        if (substr(dir, i, 1) == "/") {
            last_sep = i
            break
        }
    }

    if (last_sep > 0) {
        dir = substr(dir, 1, last_sep - 1)
    }

    st_sreturn("parent_dir", dir)
}
end
